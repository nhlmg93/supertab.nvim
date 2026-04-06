---Vim command definitions
local api = require("supertab.api")
local log = require("supertab.logger")
local config = require("supertab.config")
local clients = require("supertab.clients")

local M = {}

---Get status for display
---@return string
local function get_backend_status()
  local backend = api.get_backend()
  local mode = api.get_mode()
  local status = api.is_running() and "running" or "not running"
  return string.format("Supertab is %s (mode: %s, backend: %s)", status, mode, backend)
end

M.setup = function()
  vim.api.nvim_create_user_command("SupertabStart", function()
    api.start()
  end, { desc = "Start supertab completion" })

  vim.api.nvim_create_user_command("SupertabStop", function()
    api.stop()
  end, { desc = "Stop supertab completion" })

  vim.api.nvim_create_user_command("SupertabRestart", function()
    api.restart()
  end, { desc = "Restart supertab completion" })

  vim.api.nvim_create_user_command("SupertabToggle", function()
    api.toggle()
  end, { desc = "Toggle supertab completion" })

  vim.api.nvim_create_user_command("SupertabAccept", function()
    api.accept_suggestion()
  end, { desc = "Accept supertab suggestion" })

  vim.api.nvim_create_user_command("SupertabAcceptWord", function()
    api.accept_word()
  end, { desc = "Accept next word of supertab suggestion" })

  vim.api.nvim_create_user_command("SupertabClear", function()
    api.clear_suggestion()
  end, { desc = "Clear supertab suggestion" })

  vim.api.nvim_create_user_command("SupertabToggleMode", function()
    api.toggle_mode()
  end, { desc = "Toggle supertab between completion and doc mode" })

  vim.api.nvim_create_user_command("SupertabStatus", function()
    local msg = get_backend_status()
    log:info(msg)
    vim.notify(msg, vim.log.levels.INFO, { title = "Supertab" })
  end, { desc = "Show supertab status" })

  vim.api.nvim_create_user_command("SupertabShowLog", function()
    api.show_log()
  end, { desc = "Show supertab log file" })

  vim.api.nvim_create_user_command("SupertabClearLog", function()
    api.clear_log()
  end, { desc = "Clear supertab log file" })

  -- Client-specific check commands
  vim.api.nvim_create_user_command("SupertabOllamaCheck", function()
    local client = require("supertab.clients.ollama")
    client.check_availability(function(available, version)
      vim.schedule(function()
        if available then
          local msg = "Ollama is available" .. (version and " (version: " .. version .. ")" or "")
          vim.notify(msg, vim.log.levels.INFO, { title = "Supertab" })
          log:info(msg)
        else
          local ollama_config = config.get_client_config("ollama")
          local host = ollama_config and ollama_config.host or "http://localhost:11434"
          local msg = "Ollama is not available at " .. host
          vim.notify(msg, vim.log.levels.WARN, { title = "Supertab" })
          log:warn("Ollama is not available")
        end
      end)
    end)
  end, { desc = "Check Ollama availability" })

  -- Generic client check command
  vim.api.nvim_create_user_command("SupertabClientCheck", function()
    local backend = api.get_backend()
    local client = clients.get(backend)
    if not client then
      vim.notify("Client '" .. backend .. "' not found", vim.log.levels.WARN, { title = "Supertab" })
      return
    end

    client.check_availability(function(available, version)
      vim.schedule(function()
        if available then
          local msg = backend .. " is available" .. (version and " (version: " .. version .. ")" or "")
          vim.notify(msg, vim.log.levels.INFO, { title = "Supertab" })
          log:info(msg)
        else
          local msg = backend .. " is not available"
          vim.notify(msg, vim.log.levels.WARN, { title = "Supertab" })
          log:warn(msg)
        end
      end)
    end)
  end, { desc = "Check configured client availability" })
end

return M
