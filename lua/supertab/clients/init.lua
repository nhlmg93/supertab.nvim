---Client registry and abstraction layer
local M = {}

---@class SupertabClient
---@field name string Client identifier
---@field available boolean Whether client is available
---@field config SupertabClientInstanceConfig Configuration for this client

---@class SupertabClientInstanceConfig
---@field enable boolean Whether client is enabled
---@field host? string (for HTTP clients)
---@field model? string Model name
---@field temperature? number
---@field top_p? number
---@field top_k? number
---@field max_tokens? number
---@field debounce_ms? number
---@field context_lines? number

---@class SupertabClientInterface
---@field name string
---@field check_availability fun(callback: fun(available: boolean, version: string|nil))
---@field complete fun(prefix: string, suffix: string, ctx: table, on_token: fun(token: string, accumulated: string), on_done: fun(completion: string)): function|nil
---@field make_doc_request? fun(prompt: string, on_done: fun(completion: string)): function|nil

---@type table<string, SupertabClientInterface>
local clients = {}

---@type string|nil
local active_client_name = nil

---@type SupertabClientInterface|nil
local active_client = nil

---Get a client by name
---@param name string Client name
---@return SupertabClientInterface|nil
function M.get(name)
  return clients[name]
end

---Get the currently active client
---@return SupertabClientInterface|nil
function M.get_active()
  return active_client
end

---Get the name of the active client
---@return string|nil
function M.get_active_name()
  return active_client_name
end

---Set the active client by name
---@param name string Client name
---@return boolean Success
function M.set_active(name)
  local client = clients[name]
  if not client then
    return false
  end
  active_client_name = name
  active_client = client
  return true
end

---Clear active client
function M.clear_active()
  active_client_name = nil
  active_client = nil
end

---List all registered clients
---@return string[] List of client names
function M.list_registered()
  return vim.tbl_keys(clients)
end

---List available clients (async check)
---@param callback fun(results: table<string, {available: boolean, version: string|nil}>)
function M.list_available(callback)
  local results = {}
  local pending = 0
  local names = vim.tbl_keys(clients)

  if #names == 0 then
    vim.schedule(function()
      callback(results)
    end)
    return
  end

  for _, name in ipairs(names) do
    pending = pending + 1
    local client = clients[name]
    client.check_availability(function(available, version)
      results[name] = { available = available, version = version }
      pending = pending - 1
      if pending == 0 then
        vim.schedule(function()
          callback(results)
        end)
      end
    end)
  end
end

---Check if a client is registered and available
---@param name string Client name
---@param callback fun(available: boolean, version: string|nil)
function M.is_available(name, callback)
  local client = clients[name]
  if not client then
    callback(false, nil)
    return
  end
  client.check_availability(callback)
end

---Register a new client implementation.
---@param client SupertabClientInterface Client implementation
---@return boolean
function M.register(client)
  if not client or not client.name then
    return false
  end

  clients[client.name] = client
  return true
end

return M
