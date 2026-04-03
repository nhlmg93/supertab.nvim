--- Ollama integration for supertab.nvim
-- Handles async completion requests to Ollama's /api/generate endpoint
-- @module supertab.ollama

local api = vim.api
local u = require("supertab.util")
local loop = u.uv
local config = require("supertab.config")
local preview = require("supertab.completion_preview")
local client = require("supertab.ollama.client")
local log = require("supertab.logger")

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

--- Check if Ollama is properly configured and available
-- @return boolean
function OllamaLifecycle:is_available()
  local ollama_config = config.ollama
  if not ollama_config or not ollama_config.enable then
    return false
  end
  return true
end

--- Start the Ollama service
function OllamaLifecycle:start()
  if not self:is_available() then
    log:warn("Ollama is not enabled or not configured")
    return
  end

  -- Apply config settings
  local ollama_config = config.ollama or {}
  if ollama_config.debounce_ms then
    self.debounce_ms = ollama_config.debounce_ms
  end
  if ollama_config.context_lines then
    self.context_lines = ollama_config.context_lines
  end

  self:check_ollama()
end

--- Check Ollama availability
function OllamaLifecycle:check_ollama()
  log:info("Checking Ollama availability at " .. (config.ollama and config.ollama.host or "default"))
  client.check_availability(function(available, version)
    vim.schedule(function()
      if available then
        self.is_active = true
        log:debug("Ollama is available" .. (version and " (version: " .. version .. ")" or ""))
      else
        self.is_active = false
        log:error("Ollama check failed - server may be down or unreachable at " .. (config.ollama and config.ollama.host or "default host"))
      end
    end)
  end)
end

--- Stop the Ollama service
function OllamaLifecycle:stop()
  self:cancel_request()
  self.is_active = false
end

--- Cancel any pending request
function OllamaLifecycle:cancel_request()
  if self.cancel_fn then
    self.cancel_fn()
    self.cancel_fn = nil
  end
  if self.debounce_timer then
    self.debounce_timer:stop()
  end
end

--- Check if the context has changed
-- @param context table Current context
-- @return boolean
function OllamaLifecycle:same_context(context)
  if self.last_context == nil then
    return false
  end
  return context.cursor[1] == self.last_context.cursor[1]
    and context.cursor[2] == self.last_context.cursor[2]
    and context.file_name == self.last_context.file_name
    and context.document_text == self.last_context.document_text
end

--- Handle text changes - trigger completion
-- @param buffer number Buffer handle
-- @param file_name string File name
-- @param event_type string Event type
function OllamaLifecycle:on_update(buffer, file_name, event_type)
  if vim.tbl_contains(config.ignore_filetypes, vim.bo.filetype) then
    return
  end

  if not self:is_available() then
    return
  end

  local buffer_text = u.get_text(buffer)

  -- Check file size
  if #buffer_text > 10e6 then
    log:warn("File is too large to send to Ollama. Skipping...")
    return
  end

  local cursor = api.nvim_win_get_cursor(0)
  -- Allow completion if text changed (don't require last_path match for first keystroke)
  local text_changed = buffer_text ~= self.last_text
  local context = {
    document_text = buffer_text,
    cursor = cursor,
    file_name = file_name,
  }

  if text_changed then
    -- Immediately clear old suggestion and cancel in-flight request
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

--- Debounced completion request
-- @param buffer number Buffer handle
-- @param cursor number[] Cursor position
-- @param context table Current context
function OllamaLifecycle:debounced_completion(buffer, cursor, context)
  -- Cancel existing debounce timer
  if self.debounce_timer then
    self.debounce_timer:stop()
  end

  -- Ensure timer exists
  if not self.debounce_timer then
    self.debounce_timer = loop.new_timer()
  end

  -- Start timer with fresh cursor (re-read to avoid stale closure)
  self.debounce_timer:start(
    self.debounce_ms,
    0,
    vim.schedule_wrap(function()
      -- Re-read cursor position to handle case where user moved during debounce
      local current_cursor = api.nvim_win_get_cursor(0)
      self:provide_completion(buffer, current_cursor, context)
    end)
  )
end

--- Provide inline completion from Ollama
-- @param buffer number Buffer handle
-- @param cursor number[] Cursor position
-- @param context table Current context
function OllamaLifecycle:provide_completion(buffer, cursor, context)
  self.buffer = buffer
  self.cursor = cursor
  self.last_provide_time = loop.now()

  -- Re-check buffer validity
  if not buffer or not api.nvim_buf_is_valid(buffer) then
    return
  end

  -- Re-check cursor position hasn't changed since debounce started
  local current_cursor = api.nvim_win_get_cursor(0)
  if current_cursor[1] ~= cursor[1] or current_cursor[2] ~= cursor[2] then
    -- Cursor moved, trigger new debounce
    self:debounced_completion(buffer, current_cursor, context)
    return
  end

  -- Get text around cursor
  local text_split = u.get_text_before_after_cursor(cursor)
  local line_before_cursor = text_split.text_before_cursor
  local line_after_cursor = text_split.text_after_cursor

  if line_before_cursor == nil or line_after_cursor == nil then
    return
  end

  -- Get cursor prefix (text before cursor in buffer)
  local status, prefix = pcall(u.get_cursor_prefix, buffer, cursor)
  if not status then
    return
  end

  -- Increment request ID
  self.request_id = self.request_id + 1
  if self.request_id > self.max_request_id then
    self.request_id = 1
  end
  local current_request_id = self.request_id

  -- Build completion context
  local suffix = u.get_cursor_suffix(buffer, cursor) or ""

  -- Cancel previous request
  self:cancel_request()

  -- Make streaming request — update preview as tokens arrive
  self.cancel_fn = client.queue_request(
    prefix, suffix,
    function(_token, accumulated)
      -- on_token: update preview incrementally
      if current_request_id ~= self.request_id then return end
      if not accumulated or #accumulated == 0 then return end
      -- Strip markdown fences from partial result
      local clean = accumulated:gsub("^%s*```[a-zA-Z]*%s*\n", ""):gsub("\n%s*```%s*$", "")
      self:handle_completion(clean, prefix, line_before_cursor, line_after_cursor)
    end,
    function(completion)
      -- on_done: final render
      if current_request_id ~= self.request_id then return end
      if not completion or #completion == 0 then
        preview:dispose_inlay()
        return
      end
      self:handle_completion(completion, prefix, line_before_cursor, line_after_cursor)
    end
  )
end

--- Handle completion response
-- @param completion string The completion text
-- @param prefix string Original prefix
-- @param line_before_cursor string Text before cursor on current line
-- @param line_after_cursor string Text after cursor on current line
function OllamaLifecycle:handle_completion(completion, prefix, line_before_cursor, line_after_cursor)
  -- Extract completion relative to the cursor position
  local processed_completion = completion

  -- If the completion starts with the same content as the prefix, strip it
  if #prefix > 0 and string.sub(processed_completion, 1, #prefix) == prefix then
    processed_completion = processed_completion:sub(#prefix + 1)
  end

  -- If completion starts with the same content as line_before_cursor, strip it
  if #line_before_cursor > 0 and string.sub(processed_completion, 1, #line_before_cursor) == line_before_cursor then
    processed_completion = processed_completion:sub(#line_before_cursor + 1)
  end

  -- Trim the completion
  processed_completion = u.trim_start(processed_completion)
  processed_completion = u.trim_end(processed_completion)

  if not processed_completion or #processed_completion == 0 then
    preview:dispose_inlay()
    return
  end

  -- Find where the completion should end (at newline or matching text)
  local completion_end = #processed_completion
  local first_newline = string.find(processed_completion, "\n")
  if first_newline then
    completion_end = first_newline - 1
  end

  -- Check if completion matches text after cursor
  if #line_after_cursor > 0 then
    local match_pos = string.find(processed_completion, line_after_cursor, 1, true)
    if match_pos then
      completion_end = math.min(completion_end, match_pos - 1)
    end
  end

  -- Check for floating completion
  local is_floating = false
  if #line_after_cursor > 0 and string.sub(processed_completion, 1, #line_after_cursor) ~= line_after_cursor then
    is_floating = true
  end

  local final_completion = string.sub(processed_completion, 1, completion_end)

  if not final_completion or #final_completion == 0 then
    preview:dispose_inlay()
    return
  end

  -- Calculate prior delete (characters to delete before inserting)
  local prior_delete = 0

  -- Render the completion
  self:render_completion(final_completion, prior_delete, line_before_cursor, line_after_cursor)
end

--- Render the completion with inlay
-- @param completion_text string The completion text
-- @param prior_delete number Characters to delete before cursor
-- @param line_before_cursor string Text before cursor
-- @param line_after_cursor string Text after cursor
function OllamaLifecycle:render_completion(completion_text, prior_delete, line_before_cursor, line_after_cursor)
  if not self.buffer or not vim.api.nvim_buf_is_valid(self.buffer) then
    return
  end

  local buf = vim.api.nvim_get_current_buf()

  -- Determine if this is a floating completion (has trailing content that doesn't match)
  local is_floating = false
  if #line_after_cursor > 0 and string.sub(completion_text, 1, #line_after_cursor) ~= line_after_cursor then
    is_floating = true
  end

  if is_floating then
    -- Show only the first line as inline
    local first_newline = string.find(completion_text, "\n")
    local inline_text = first_newline and string.sub(completion_text, 1, first_newline - 1) or completion_text

    preview:render_with_inlay(self.buffer, prior_delete, inline_text, line_after_cursor, line_before_cursor)
  else
    preview:render_with_inlay(self.buffer, prior_delete, completion_text, line_after_cursor, line_before_cursor)
  end
end

--- Initialize the debounce timer
function OllamaLifecycle:init()
  -- Create single long-lived timer, just stop/start as needed
  if self.debounce_timer then
    self.debounce_timer:close()
  end
  self.debounce_timer = loop.new_timer()
end

--- Cleanup on shutdown
function OllamaLifecycle:cleanup()
  self:cancel_request()
  if self.debounce_timer then
    self.debounce_timer:close()
    self.debounce_timer = nil
  end
end

-- Create the timer on module load, but don't start it
OllamaLifecycle.debounce_timer = loop.new_timer()

return OllamaLifecycle