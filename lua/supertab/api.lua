---Public API for supertab.nvim
local listener = require("supertab.document_listener")
local completion_preview = require("supertab.completion_preview")
local doc_snippet = require("supertab.doc_snippet")
local log = require("supertab.logger")
local config = require("supertab.config")
local lifecycle = require("supertab.lifecycle")
local clients = require("supertab.clients")

local M = {}

---Check if supertab is enabled (not explicitly disabled)
---@return boolean
M.is_enabled = function()
  return vim.g.SUPERTAB_DISABLED ~= 1
end

---Check if supertab is currently running
---@return boolean
M.is_running = function()
  return lifecycle.is_active
end

---Start supertab completion
M.start = function()
  local active_client_name = config.get_active_client()
  local client_config = config.get_client_config(active_client_name)

  if not client_config or not client_config.enable then
    log:warn(
      active_client_name .. " backend is not enabled. Set clients." .. active_client_name .. ".enable=true in config."
    )
    return
  end

  if lifecycle.is_starting or M.is_running() then
    log:warn("Supertab is already running (" .. active_client_name .. " backend).")
    return
  end

  log:trace("Starting Supertab (" .. active_client_name .. ")...")
  vim.g.SUPERTAB_DISABLED = 0

  -- Set the active client
  local success = clients.set_active(active_client_name)
  if not success then
    log:error("Failed to set active client: " .. active_client_name)
    return
  end

  -- Initialize lifecycle with client config
  lifecycle:init(client_config)
  lifecycle:start()

  -- Setup document listener
  listener.setup()
end

---Stop supertab completion
M.stop = function()
  vim.g.SUPERTAB_DISABLED = 1
  M.clear_suggestion()
  listener.teardown()

  if not lifecycle.is_starting and not M.is_running() then
    log:warn("Supertab is not running.")
    return
  end

  log:trace("Stopping Supertab...")
  lifecycle:stop()
  clients.clear_active()
end

---Restart supertab completion
M.restart = function()
  if M.is_running() then
    M.stop()
  end
  M.start()
end

---Toggle supertab on/off
M.toggle = function()
  if M.is_running() then
    M.stop()
  else
    M.start()
  end
end

---Accept current suggestion
---@return boolean true if a suggestion was accepted
M.accept_suggestion = function()
  -- If in a doc snippet, handle the jump
  if doc_snippet.is_active() then
    log:debug("accept_suggestion: doc snippet active, forwarding to on_snippet_jump()")
    doc_snippet.on_snippet_jump()
    return true
  end
  -- If in any other snippet, let vim.snippet handle Tab
  if vim.snippet.active() then
    log:debug("accept_suggestion: generic snippet active, performing vim.snippet.jump(1)")
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

---Accept word only
M.accept_word = function()
  completion_preview.on_accept_suggestion_word()
end

---Clear current suggestion
M.clear_suggestion = function()
  completion_preview.on_dispose_inlay()
end

---Show log file
M.show_log = function()
  local log_path = log:get_log_path()
  if log_path ~= nil then
    vim.cmd.tabnew()
    vim.cmd.edit(vim.fn.fnameescape(log_path))
  else
    log:warn("No log file found to show!")
  end
end

---Clear log file
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

---Get current mode
---@return "completion" | "doc"
M.get_mode = function()
  return config.mode or "completion"
end

---Toggle between completion and doc modes
M.toggle_mode = function()
  M.clear_suggestion()
  config.mode = config.mode == "completion" and "doc" or "completion"
  vim.notify("Supertab: " .. config.mode .. " mode", vim.log.levels.INFO)
end

---Get active backend name
---@return string Backend name
M.get_backend = function()
  return config.get_active_client()
end

return M
