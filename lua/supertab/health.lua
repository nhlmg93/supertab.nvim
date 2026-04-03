local M = {}

---@return string
local function get_lua_version()
  return _VERSION
end

---@param msg string
---@param level? number
local function report(msg, level)
  level = level or vim.health.info
  level(msg)
end

M.check = function()
  vim.health.start("supertab.nvim")

  -- Check Neovim version
  local nvim_version = vim.version()
  local nvim_version_str = string.format("%d.%d.%d", nvim_version.major, nvim_version.minor, nvim_version.patch)
  if nvim_version.major >= 0 and nvim_version.minor >= 9 then
    report("Neovim version: " .. nvim_version_str .. " (supported)")
  else
    report("Neovim version: " .. nvim_version_str .. " (needs 0.9+)")
  end

  -- Check Lua version
  report("Lua version: " .. get_lua_version())

  -- Check for required Lua features
  local has_uv, _ = pcall(function()
    return vim.uv or vim.loop
  end)
  if has_uv then
    report("vim.uv available: yes")
  else
    report("vim.uv available: no (using vim.loop fallback)")
  end

  -- Check configuration
  local config_ok, config = pcall(require, "supertab.config")
  if config_ok then
    report("Configuration module: loaded")
    if config.ollama and config.ollama.enable then
      report("Ollama backend: enabled")
      report("Ollama host: " .. (config.ollama.host or "default"))
      report("Ollama model: " .. (config.ollama.model or "default"))
    else
      report("Ollama backend: disabled")
    end
  else
    report("Configuration module: failed to load")
  end

  -- Check for optional dependencies
  local has_cmp, _ = pcall(require, "cmp")
  if has_cmp then
    report("nvim-cmp: installed (optional)")
  else
    report("nvim-cmp: not installed (optional)")
  end

  -- Check Ollama connection
  local client_ok, client = pcall(require, "supertab.ollama.client")
  if client_ok then
    report("Testing Ollama connection...")
    -- Async check with timeout
    local checked = false
    client.check_availability(function(available, version)
      checked = true
      vim.schedule(function()
        if available then
          report("Ollama connection: OK" .. (version and " (version: " .. version .. ")" or ""))
        else
          report("Ollama connection: failed - server may be down")
        end
      end)
    end)

    -- Give it a moment to respond
    vim.wait(3000, function()
      return checked
    end, 100)

    if not checked then
      report("Ollama connection: timeout (server may be slow or down)")
    end
  else
    report("Ollama client: failed to load")
  end
end

return M
