local api = require("supertab.api")
local log = require("supertab.logger")
local config = require("supertab.config")

local M = {}

M.setup = function()
  vim.api.nvim_create_user_command("SupertabStart", function()
    api.start()
  end, {})

  vim.api.nvim_create_user_command("SupertabStop", function()
    api.stop()
  end, {})

  vim.api.nvim_create_user_command("SupertabRestart", function()
    api.restart()
  end, {})

  vim.api.nvim_create_user_command("SupertabToggle", function()
    api.toggle()
  end, {})

  vim.api.nvim_create_user_command("SupertabStatus", function()
    local backend = api.get_backend()
    local status = api.is_running() and "running" or "not running"
    log:info(string.format("Supertab is %s (backend: %s)", status, backend))
    print(string.format("Supertab is %s (backend: %s)", status, backend))
  end, {})

  vim.api.nvim_create_user_command("SupertabShowLog", function()
    api.show_log()
  end, {})

  vim.api.nvim_create_user_command("SupertabClearLog", function()
    api.clear_log()
  end, {})

  -- Ollama-specific commands
  vim.api.nvim_create_user_command("SupertabOllamaCheck", function()
    local ollama = require("supertab.ollama.client")
    ollama.check_availability(function(available, version)
      if available then
        print("Ollama is available" .. (version and " (version: " .. version .. ")" or ""))
        log:info("Ollama is available" .. (version and " (version: " .. version .. ")" or ""))
      else
        print("Ollama is not available at " .. (config.ollama and config.ollama.host or "http://localhost:11434"))
        log:warn("Ollama is not available")
      end
    end)
  end, {})
end

return M
