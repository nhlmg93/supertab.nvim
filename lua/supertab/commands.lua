local api = require("supertab.api")
local log = require("supertab.logger")
local config = require("supertab.config")

local M = {}

---@return string
local function get_backend_status()
  local backend = api.get_backend()
  local status = api.is_running() and "running" or "not running"
  return string.format("Supertab is %s (backend: %s)", status, backend)
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

  vim.api.nvim_create_user_command("SupertabOllamaCheck", function()
    local ollama = require("supertab.ollama.client")
    ollama.check_availability(function(available, version)
      vim.schedule(function()
        if available then
          local msg = "Ollama is available" .. (version and " (version: " .. version .. ")" or "")
          vim.notify(msg, vim.log.levels.INFO, { title = "Supertab" })
          log:info(msg)
        else
          local host = config.ollama and config.ollama.host or "http://localhost:11434"
          local msg = "Ollama is not available at " .. host
          vim.notify(msg, vim.log.levels.WARN, { title = "Supertab" })
          log:warn("Ollama is not available")
        end
      end)
    end)
  end, { desc = "Check Ollama availability" })
end

return M
