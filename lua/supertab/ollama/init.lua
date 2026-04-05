local api = vim.api
local util = require("supertab.util")
local loop = util.uv
local config = require("supertab.config")
local preview = require("supertab.completion_preview")
local client = require("supertab.ollama.client")
local log = require("supertab.logger")

---@class OllamaLifecycle
---@field buffer integer|nil
---@field cursor integer[]|nil
---@field last_provide_time number
---@field last_text string|nil
---@field last_path string|nil
---@field last_context table|nil
---@field is_active boolean
---@field cancel_fn function|nil
---@field request_id integer
---@field max_request_id integer
---@field context_lines integer
---@field debounce_ms integer
---@field debounce_timer userdata|nil
local OllamaLifecycle = {
  buffer = nil,
  cursor = nil,
  last_provide_time = 0,
  last_text = nil,
  last_path = nil,
  last_context = nil,
  is_active = false,
  cancel_fn = nil,
  request_id = 0,
  max_request_id = 50,
  context_lines = 10,
  debounce_ms = 50,
  debounce_timer = nil,
}

---@return boolean
function OllamaLifecycle:is_available()
  local ollama_config = config.ollama
  if not ollama_config or not ollama_config.enable then
    return false
  end
  return true
end

function OllamaLifecycle:start()
  if not self:is_available() then
    log:warn("Ollama is not enabled or not configured")
    return
  end

  local ollama_config = config.ollama
  if ollama_config.debounce_ms then
    self.debounce_ms = ollama_config.debounce_ms
  end
  if ollama_config.context_lines then
    self.context_lines = ollama_config.context_lines
  end

  self:check_ollama()
end

function OllamaLifecycle:check_ollama()
  log:info("Checking Ollama availability at " .. (config.ollama.host or "default"))
  client.check_availability(function(available, version)
    vim.schedule(function()
      if available then
        self.is_active = true
        log:debug("Ollama is available" .. (version and " (version: " .. version .. ")" or ""))
      else
        self.is_active = false
        log:error(
          "Ollama check failed - server may be down or unreachable at " .. (config.ollama.host or "default host")
        )
      end
    end)
  end)
end

function OllamaLifecycle:stop()
  self:cancel_request()
  self.is_active = false
end

function OllamaLifecycle:cancel_request()
  if self.cancel_fn then
    self.cancel_fn()
    self.cancel_fn = nil
  end
  if self.debounce_timer then
    self.debounce_timer:stop()
  end
end

---@param context table
---@return boolean
function OllamaLifecycle:same_context(context)
  if self.last_context == nil then
    return false
  end
  return context.cursor[1] == self.last_context.cursor[1]
    and context.cursor[2] == self.last_context.cursor[2]
    and context.file_name == self.last_context.file_name
    and context.document_text == self.last_context.document_text
end

---@param buffer integer
---@param file_name string
---@param event_type string
function OllamaLifecycle:on_update(buffer, file_name, event_type)
  if vim.tbl_contains(config.ignore_filetypes, vim.bo.filetype) then
    return
  end

  if not self:is_available() then
    return
  end

  local buffer_text = util.get_text(buffer)

  if #buffer_text > 10e6 then
    log:warn("File is too large to send to Ollama. Skipping...")
    return
  end

  local cursor = api.nvim_win_get_cursor(0)
  local text_changed = buffer_text ~= self.last_text

  ---@type table
  local context = {
    document_text = buffer_text,
    cursor = cursor,
    file_name = file_name,
  }

  if text_changed then
    preview:dispose_inlay()
    self:cancel_request()
    self:debounced_completion(buffer, cursor, context)
  elseif not self:same_context(context) then
    preview:dispose_inlay()
  end

  self.last_path = file_name
  self.last_text = buffer_text
  self.last_context = context
end

---@param buffer integer
---@param cursor integer[]
---@param context table
function OllamaLifecycle:debounced_completion(buffer, cursor, context)
  if self.debounce_timer then
    self.debounce_timer:stop()
  end

  if not self.debounce_timer then
    self.debounce_timer = loop.new_timer()
  end

  self.debounce_timer:start(self.debounce_ms, 0, function()
    vim.schedule(function()
      local current_cursor = api.nvim_win_get_cursor(0)
      self:provide_completion(buffer, current_cursor, context)
    end)
  end)
end

---@param buffer integer
---@param cursor integer[]
---@param context table
function OllamaLifecycle:provide_completion(buffer, cursor, context)
  self.buffer = buffer
  self.cursor = cursor
  self.last_provide_time = loop.now()

  if not buffer or not api.nvim_buf_is_valid(buffer) then
    return
  end

  local current_cursor = api.nvim_win_get_cursor(0)
  if current_cursor[1] ~= cursor[1] or current_cursor[2] ~= cursor[2] then
    self:debounced_completion(buffer, current_cursor, context)
    return
  end

  local text_split = util.get_text_before_after_cursor(cursor)
  local line_before_cursor = text_split.text_before_cursor
  local line_after_cursor = text_split.text_after_cursor

  if line_before_cursor == nil or line_after_cursor == nil then
    return
  end

  local status, prefix = pcall(util.get_cursor_prefix, buffer, cursor)
  if not status then
    return
  end

  self.request_id = self.request_id + 1
  if self.request_id > self.max_request_id then
    self.request_id = 1
  end
  local current_request_id = self.request_id

  local suffix = util.get_cursor_suffix(buffer, cursor) or ""
  self:cancel_request()

  self.cancel_fn = client.queue_request(prefix, suffix, function(_token, accumulated)
    if current_request_id ~= self.request_id then
      return
    end
    if not accumulated or #accumulated == 0 then
      return
    end
    local clean = accumulated:gsub("^%s*```[a-zA-Z]*%s*\n", ""):gsub("\n%s*```%s*$", "")
    self:handle_completion(clean, prefix, line_before_cursor, line_after_cursor)
  end, function(completion)
    if current_request_id ~= self.request_id then
      return
    end
    if not completion or #completion == 0 then
      preview:dispose_inlay()
      return
    end
    self:handle_completion(completion, prefix, line_before_cursor, line_after_cursor)
  end)
end

---@param completion string
---@param prefix string
---@param line_before_cursor string
---@param line_after_cursor string
function OllamaLifecycle:handle_completion(completion, prefix, line_before_cursor, line_after_cursor)
  local processed_completion = completion

  if #prefix > 0 and string.sub(processed_completion, 1, #prefix) == prefix then
    processed_completion = processed_completion:sub(#prefix + 1)
  end

  if #line_before_cursor > 0 and string.sub(processed_completion, 1, #line_before_cursor) == line_before_cursor then
    processed_completion = processed_completion:sub(#line_before_cursor + 1)
  end

  processed_completion = util.trim_start(processed_completion)
  processed_completion = util.trim_end(processed_completion)

  if not processed_completion or #processed_completion == 0 then
    preview:dispose_inlay()
    return
  end

  -- Check if text after cursor appears in completion, limit to that point
  local completion_end = #processed_completion
  if #line_after_cursor > 0 then
    local match_pos = string.find(processed_completion, line_after_cursor, 1, true)
    if match_pos then
      completion_end = math.min(completion_end, match_pos - 1)
    end
  end

  local final_completion = string.sub(processed_completion, 1, completion_end)

  if not final_completion or #final_completion == 0 then
    preview:dispose_inlay()
    return
  end

  local prior_delete = 0
  self:render_completion(final_completion, prior_delete, line_before_cursor, line_after_cursor)
end

---@param completion_text string
---@param prior_delete number
---@param line_before_cursor string
---@param line_after_cursor string
function OllamaLifecycle:render_completion(completion_text, prior_delete, line_before_cursor, line_after_cursor)
  if not self.buffer or not vim.api.nvim_buf_is_valid(self.buffer) then
    return
  end

  local is_floating = util.is_floating_completion(completion_text, line_after_cursor)

  if is_floating then
    local first_newline = string.find(completion_text, "\n")
    local inline_text = first_newline and string.sub(completion_text, 1, first_newline - 1) or completion_text
    preview:render_with_inlay(self.buffer, prior_delete, inline_text, line_after_cursor, line_before_cursor)
  else
    preview:render_with_inlay(self.buffer, prior_delete, completion_text, line_after_cursor, line_before_cursor)
  end
end

OllamaLifecycle.debounce_timer = loop.new_timer()

return OllamaLifecycle
