---Document listener with Neovim 0.12+ augroup patterns
local preview = require("supertab.completion_preview")
local config = require("supertab.config")
local doc_snippet = require("supertab.doc_snippet")
local lifecycle = require("supertab.lifecycle")

local M = {}

---@type integer|nil
local augroup = nil

---Handle text change events
---@param event table
local function on_text_changed(event)
  if doc_snippet.is_doc_mode() then
    return
  end

  local file_name = event.file
  local buffer = event.buf
  if not file_name or not buffer then
    return
  end

  lifecycle:on_update(buffer, file_name, "text_changed")
end

---Handle cursor movement events
---@param event table
local function on_cursor_moved(event)
  if doc_snippet.is_doc_mode() then
    return
  end

  local file_name = event.file
  local buffer = event.buf
  if not file_name or not buffer then
    return
  end

  lifecycle:on_update(buffer, file_name, "cursor")
end

---Clear completion on insert leave
---@param _event table
local function on_insert_leave(_event)
  if doc_snippet.is_doc_mode() then
    return
  end
  preview:dispose_inlay()
end

---Setup highlight colors
---@param _event table
local function setup_highlight(_event)
  if config.color and config.color.suggestion_color and config.color.cterm then
    vim.api.nvim_set_hl(0, "SupertabSuggestion", {
      fg = config.color.suggestion_color,
      ctermfg = config.color.cterm,
    })
    preview.suggestion_group = "SupertabSuggestion"
  end
end

M.setup = function()
  augroup = vim.api.nvim_create_augroup("supertab", { clear = true })

  -- Trigger completion on text change
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
    group = augroup,
    callback = on_text_changed,
    desc = "Trigger completion on text change",
  })

  -- Auto-start/stop supertab on buffer enter
  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    group = augroup,
    callback = function()
      -- Lazy require to avoid a load-time api <-> document_listener cycle.
      local api = require("supertab.api")

      if config.condition() or vim.g.SUPERTAB_DISABLED == 1 then
        if api.is_running() then
          api.stop()
        end
        return
      end

      if not api.is_running() and not lifecycle.is_starting then
        api.start()
      end
    end,
    desc = "Auto-start/stop supertab on buffer enter",
  })

  -- Update completion on cursor move
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = augroup,
    callback = on_cursor_moved,
    desc = "Update completion on cursor move",
  })

  -- Clear completion on insert leave
  vim.api.nvim_create_autocmd({ "InsertLeave" }, {
    group = augroup,
    callback = on_insert_leave,
    desc = "Clear completion on insert leave",
  })

  -- Setup highlight colors
  vim.api.nvim_create_autocmd({ "VimEnter", "ColorScheme" }, {
    group = augroup,
    pattern = "*",
    callback = setup_highlight,
    desc = "Setup supertab highlight colors",
  })
end

M.teardown = function()
  if augroup ~= nil then
    pcall(vim.api.nvim_del_augroup_by_id, augroup)
    augroup = nil
  end
end

return M
