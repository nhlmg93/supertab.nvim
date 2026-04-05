local ollama = require("supertab.ollama")
local listener = require("supertab.document_listener")
local completion_preview = require("supertab.completion_preview")
local doc_snippet = require("supertab.doc_snippet")
local log = require("supertab.logger")
local config = require("supertab.config")

local M = {}

---@return boolean
M.is_running = function()
  if config.ollama and config.ollama.enable then
    return ollama.is_active
  end
  return false
end

M.start = function()
  if not config.ollama or not config.ollama.enable then
    log:warn("Ollama backend is not enabled. Set ollama.enable=true in config.")
    return
  end

  if M.is_running() then
    log:warn("Supertab is already running (Ollama backend).")
    return
  end

  log:trace("Starting Supertab (Ollama)...")
  vim.g.SUPERTAB_DISABLED = 0
  ollama:start()
  listener.setup()
end

M.stop = function()
  vim.g.SUPERTAB_DISABLED = 1

  if not M.is_running() then
    log:warn("Supertab is not running.")
    return
  end

  log:trace("Stopping Supertab...")
  listener.teardown()
  ollama:stop()
end

M.restart = function()
  if M.is_running() then
    M.stop()
  end
  M.start()
end

M.toggle = function()
  if M.is_running() then
    M.stop()
  else
    M.start()
  end
end

---@return boolean true if a suggestion was accepted
M.accept_suggestion = function()
  -- If in a doc snippet, handle the jump
  if doc_snippet.is_active() then
    doc_snippet.on_snippet_jump()
    return true
  end
  -- If in any other snippet, let vim.snippet handle Tab
  if vim.snippet.active() then
    vim.snippet.jump(1)
    return true
  end
  -- Only accept if there's an active suggestion
  if completion_preview.inlay_instance then
    completion_preview.on_accept_suggestion()
    return true
  end
  return false
end

M.accept_word = function()
  completion_preview.on_accept_suggestion_word()
end

M.clear_suggestion = function()
  completion_preview.on_dispose_inlay()
end

M.show_log = function()
  local log_path = log:get_log_path()
  if log_path ~= nil then
    vim.cmd.tabnew()
    vim.cmd.edit(vim.fn.fnameescape(log_path))
  else
    log:warn("No log file found to show!")
  end
end

M.clear_log = function()
  local log_path = log:get_log_path()
  if log_path ~= nil then
    local ok, err = pcall(function()
      vim.uv.fs_unlink(log_path)
    end)
    if not ok then
      log:error("Failed to clear log: " .. tostring(err))
    end
  else
    log:warn("No log file found to remove!")
  end
end

---@return "completion" | "doc"
M.get_mode = function()
  return config.mode or "completion"
end

M.toggle_mode = function()
  M.clear_suggestion()
  config.mode = config.mode == "completion" and "doc" or "completion"
  vim.notify("Supertab: " .. config.mode .. " mode", vim.log.levels.INFO)
end

---@return "ollama" | "none"
M.get_backend = function()
  if config.ollama and config.ollama.enable then
    return "ollama"
  end
  return "none"
end

return M
