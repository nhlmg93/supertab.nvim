---Health check implementation
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
  if vim.fn.has("nvim-0.12.0") == 1 then
    report("Neovim version: " .. nvim_version_str .. " (supported)", vim.health.ok)
  else
    report("Neovim version: " .. nvim_version_str .. " (needs 0.12+)", vim.health.error)
    return
  end

  -- Check Lua version
  report("Lua version: " .. get_lua_version())

  -- Check vim.uv
  report("vim.uv available: yes")

  -- Check configuration
  local config_ok, config = pcall(require, "supertab.config")
  if config_ok then
    report("Configuration module: loaded")

    -- Check configured client
    local active_client = config.get_active_client()
    local client_config = config.get_client_config(active_client)

    if client_config then
      report("Active client: " .. active_client)
      report(active_client .. " host: " .. (client_config.host or "default"))
      report(active_client .. " model: " .. (client_config.model or "default"))
    else
      report("Active client: none (not configured)")
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

  -- Load configured built-in client so registration has occurred before inspection.
  if config_ok and config then
    local client_name = config.get_active_client()
    if client_name then
      pcall(require, "supertab.clients." .. client_name)
    end
  end

  -- Check registered clients
  local clients_ok, clients_registry = pcall(require, "supertab.clients")
  if clients_ok then
    local registered = clients_registry.list_registered()
    report("Registered clients: " .. (#registered > 0 and table.concat(registered, ", ") or "none"))

    -- Track pending checks for async health verification
    local pending_checks = 0
    local function on_check_complete()
      pending_checks = pending_checks - 1
    end

    -- Check each registered client asynchronously
    for _, client_name in ipairs(registered) do
      local client = clients_registry.get(client_name)
      if client and client.check_availability then
        pending_checks = pending_checks + 1
        report("Checking " .. client_name .. "... (async)")

        client.check_availability(function(available, version)
          vim.schedule(function()
            if available then
              report(
                client_name .. " connection: OK" .. (version and " (version: " .. version .. ")" or ""),
                vim.health.ok
              )
            else
              report(client_name .. " connection: failed - server may be down", vim.health.warn)
            end
            on_check_complete()
          end)
        end)
      end
    end

    -- Run deferred check timeout notification
    if pending_checks > 0 then
      vim.defer_fn(function()
        vim.schedule(function()
          if pending_checks > 0 then
            report("Note: Some client checks may still be in progress (check server status manually)", vim.health.warn)
          end
        end)
      end, 3500)
    end
  end
end

return M
