local api = vim.api
local config = require("supertab.config")
local log = require("supertab.logger")

local M = {}

local is_expanding = false
local waiting_for_body = false
local doc_cancel_fn = nil
local throb_timer = nil
local ns_id = api.nvim_create_namespace("supertab_doc")
local insert_bufnr = nil
local insert_mark = nil

--- Start a throbbing indicator at a fixed extmark position.
---@param bufnr number
---@param row number 0-indexed
---@param col number 0-indexed
local function start_throb(bufnr, row, col)
  insert_bufnr = bufnr
  insert_mark = api.nvim_buf_set_extmark(bufnr, ns_id, row, col, {
    virt_text = { { "", "Comment" } },
    virt_text_pos = "inline",
    right_gravity = false,
  })
  local dots = { "", ".", "..", "..." }
  local i = 0
  throb_timer = vim.uv.new_timer()
  throb_timer:start(
    0,
    200,
    vim.schedule_wrap(function()
      if not insert_mark or not api.nvim_buf_is_valid(bufnr) then
        return
      end
      i = (i % #dots) + 1
      api.nvim_buf_set_extmark(bufnr, ns_id, row, col, {
        id = insert_mark,
        virt_text = { { dots[i], "Comment" } },
        virt_text_pos = "inline",
        right_gravity = false,
      })
    end)
  )
end

local function stop_throb()
  if throb_timer then
    throb_timer:stop()
    throb_timer:close()
    throb_timer = nil
  end
  if insert_bufnr and api.nvim_buf_is_valid(insert_bufnr) then
    api.nvim_buf_clear_namespace(insert_bufnr, ns_id, 0, -1)
  end
  insert_mark = nil
end

--- Get the current position of the insert mark.
---@return number|nil row 0-indexed
---@return number|nil col 0-indexed
local function get_insert_pos()
  if not insert_bufnr or not insert_mark then
    return nil, nil
  end
  local ok, mark = pcall(api.nvim_buf_get_extmark_by_id, insert_bufnr, ns_id, insert_mark, {})
  if ok and mark and #mark == 2 then
    return mark[1], mark[2]
  end
  return nil, nil
end

--- Map single-line comment leaders to block comment pairs
local block_comment_map = {
  ["--"] = { "--[[", "]]" },
  ["//"] = { "/*", "*/" },
  ["#"] = { '"""', '"""' },
  ["<!--"] = { "<!--", "-->" },
  ['"'] = { '"', '"' },
}

local filetype_fallbacks = {
  lua = { "--[[", "]]" },
  python = { '"""', '"""' },
  html = { "<!--", "-->" },
  xml = { "<!--", "-->" },
  vim = { '"', '"' },
}

local function get_comment_marks(bufnr)
  local commentstring = vim.bo[bufnr].commentstring
  if commentstring and commentstring ~= "" then
    local left, right = commentstring:match("^(.-)%%s(.*)$")
    if left then
      left = left:gsub("%s*$", "")
      right = (right or ""):gsub("^%s*", "")

      -- If already a block comment, use as-is
      if right ~= "" then
        return left, right
      end

      -- Map single-line leader to block pair
      local pair = block_comment_map[left]
      if pair then
        return pair[1], pair[2]
      end

      return left, right
    end
  end

  -- Fallback based on filetype
  local pair = filetype_fallbacks[vim.bo[bufnr].filetype]
  if pair then
    return pair[1], pair[2]
  end

  return "/*", "*/"
end

---@return boolean
function M.is_doc_mode()
  return config.mode == "doc"
end

function M.is_active()
  return is_expanding and vim.snippet.active()
end

function M.check_and_trigger()
  if not config.doc_snippet or not config.doc_snippet.enabled then
    return false
  end

  if not M.is_doc_mode() then
    return false
  end

  local trigger = config.doc_snippet.trigger or "~doc"
  local line = api.nvim_get_current_line()

  -- Check if line ends with trigger
  if not line:match(vim.pesc(trigger) .. "%s*$") then
    return false
  end

  -- Check if line is empty (or only has trigger)
  local trimmed = line:gsub("%s*" .. vim.pesc(trigger) .. "%s*", "")
  if trimmed ~= "" then
    return false
  end

  -- Delete trigger
  local new_line = line:gsub(vim.pesc(trigger) .. "%s*", "", 1)
  api.nvim_set_current_line(new_line)

  -- Get comment syntax dynamically
  local bufnr = api.nvim_get_current_buf()
  local comment_start, comment_end = get_comment_marks(bufnr)

  -- Build snippet wrapped in block comment
  local filetype = vim.bo.filetype or "text"
  local template = string.format("%s\nDocument: $1\n\n```%s\n\n$2\n\n```\n%s", comment_start, filetype, comment_end)

  is_expanding = true
  waiting_for_body = false

  vim.snippet.expand(template)
  log:debug("Expanded ~doc snippet with comments: " .. comment_start .. " / " .. comment_end)

  return true
end

--- Extract the user's prompt from the "Document: ..." line at $1.
---@return string|nil
local function capture_doc_prompt()
  local cursor = api.nvim_win_get_cursor(0)
  local line = api.nvim_buf_get_lines(0, cursor[1] - 1, cursor[1], false)[1] or ""
  local prompt = line:match("Document:%s*(.+)%s*$")
  if prompt and #prompt > 0 then
    return prompt
  end
  return nil
end

--- Called when Tab jumps within the doc snippet.
--- Returns true if we handled the jump.
function M.on_snippet_jump()
  log:debug(
    "doc_snippet.on_snippet_jump(): is_expanding="
      .. tostring(is_expanding)
      .. ", snippet_active="
      .. tostring(vim.snippet.active())
      .. ", waiting_for_body="
      .. tostring(waiting_for_body)
  )

  if not is_expanding or not vim.snippet.active() then
    return false
  end

  if not waiting_for_body then
    -- Capture prompt from $1 before jumping
    local prompt = capture_doc_prompt()
    vim.snippet.jump(1)
    waiting_for_body = true

    if not prompt then
      log:warn("Doc snippet: no prompt text found at $1")
      return true
    end

    log:debug("Doc snippet prompt captured: " .. prompt)

    local filetype = vim.bo.filetype or "text"
    local bufnr = api.nvim_get_current_buf()
    local cursor = api.nvim_win_get_cursor(0)
    local full_prompt = filetype .. ": " .. prompt

    -- Anchor throb at the $2 cursor position
    local clients_mod = require("supertab.clients")
    local client_name = config.get_active_client()

    if not client_name then
      log:error("Doc snippet: no active client configured")
      stop_throb()
      return true
    end

    local client = clients_mod.get(client_name)

    if not client then
      log:debug("Doc snippet client '" .. client_name .. "' not yet loaded, requiring module")
      pcall(require, "supertab.clients." .. client_name)
      client = clients_mod.get(client_name)
    end

    local row = cursor[1] - 1
    local col = cursor[2]
    start_throb(bufnr, row, col)

    -- Check if client supports doc generation
    if not client or not client.make_doc_request then
      log:error("Doc snippet: configured client '" .. client_name .. "' does not support doc generation")
      stop_throb()
      return true
    end

    log:debug("Doc snippet issuing doc request via client '" .. client_name .. "' with prompt: " .. full_prompt)

    doc_cancel_fn = client.make_doc_request(full_prompt, function(completion)
      doc_cancel_fn = nil
      -- Grab position before clearing the extmark
      local ins_row, ins_col = get_insert_pos()
      stop_throb()
      if not completion or #completion == 0 or not ins_row then
        log:debug(
          "Doc snippet completion callback: no insertion; completion_len="
            .. tostring(completion and #completion or 0)
            .. ", insert_row="
            .. tostring(ins_row)
        )
        return
      end
      log:debug("Doc snippet completion callback: inserting " .. tostring(#completion) .. " chars")
      local lines = vim.split(completion, "\n", { plain = true })
      api.nvim_buf_set_text(insert_bufnr, ins_row, ins_col, ins_row, ins_col, lines)
    end)

    return true
  else
    -- Second jump: $2 -> exit snippet, let request continue
    vim.snippet.jump(1)
    is_expanding = false
    waiting_for_body = false
    return true
  end
end

function M.setup()
  if not config.doc_snippet or not config.doc_snippet.enabled then
    return
  end

  local group = api.nvim_create_augroup("supertab_doc", { clear = true })

  -- Detect ~doc trigger
  api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
    group = group,
    callback = function()
      M.check_and_trigger()
    end,
    desc = "Detect ~doc trigger",
  })

  api.nvim_create_autocmd({ "InsertLeave" }, {
    group = group,
    callback = function()
      -- Don't cancel if a doc request is in flight
      if doc_cancel_fn then
        return
      end
      is_expanding = false
      waiting_for_body = false
    end,
  })
end

return M
