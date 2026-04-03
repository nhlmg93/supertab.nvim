local ollama = require("supertab.ollama")
local listener = require("supertab.document_listener")
local log = require("supertab.logger")
local config = require("supertab.config")

local M = {}

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
  else
    log:trace("Starting Supertab (Ollama)...")
  end

  vim.g.SUPERTAB_DISABLED = 0

  ollama:start()

  listener.setup()
end

M.stop = function()
  vim.g.SUPERTAB_DISABLED = 1

  if not M.is_running() then
    log:warn("Supertab is not running.")
    return
  else
    log:trace("Stopping Supertab...")
  end

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

M.show_log = function()
  local log_path = log:get_log_path()
  if log_path ~= nil then
    vim.cmd.tabnew()
    vim.cmd(string.format(":e %s", log_path))
  else
    log:warn("No log file found to show!")
  end
end

M.clear_log = function()
  local log_path = log:get_log_path()
  if log_path ~= nil then
    vim.uv.fs_unlink(log_path)
  else
    log:warn("No log file found to remove!")
  end
end

M.get_backend = function()
  if config.ollama and config.ollama.enable then
    return "ollama"
  end
  return "none"
end

return M