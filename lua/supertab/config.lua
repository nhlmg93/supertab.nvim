---Configuration management (single client only)
local M = {}

---@class SupertabDocSnippetConfig
---@field enabled? boolean
---@field trigger? string

---@alias SupertabMode "completion" | "doc"

---@class SupertabConfig
---@field mode? SupertabMode
---@field ignore_filetypes? table<string, boolean>
---@field disable_inline_completion? boolean
---@field condition? fun(): boolean
---@field log_level? "off" | "trace" | "debug" | "info" | "warn" | "error"
---@field color? SupertabColorConfig
---@field ollama? SupertabClientOllamaConfig Ollama client configuration
---@field doc_snippet? SupertabDocSnippetConfig

---@class SupertabClientOllamaConfig
---@field host? string
---@field model? string
---@field temperature? number
---@field top_p? number
---@field top_k? number
---@field max_tokens? number
---@field doc_max_tokens? number
---@field debounce_ms? number
---@field context_lines? number

---@class SupertabColorConfig
---@field suggestion_color? string
---@field cterm? number

---@type SupertabConfig
local default_config = {
  mode = "completion",
  ignore_filetypes = {},
  disable_inline_completion = false,

  ---@type fun(): boolean
  condition = function()
    return false
  end,
  log_level = "warn",
  color = nil,

  -- Ollama client configuration (default client)
  ollama = {
    host = "http://localhost:11434",
    model = "codellama",
    temperature = 0.2,
    top_p = 0.9,
    top_k = 40,
    max_tokens = 16,
    doc_max_tokens = 512,
    debounce_ms = 50,
    context_lines = 10,
  },

  doc_snippet = {
    enabled = true,
    trigger = "~doc",
  },
}

---@type SupertabConfig
M.config = vim.deepcopy(default_config)

---@param opts? SupertabConfig
M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), opts or {})
end

-- Known non-client config keys to exclude when looking for client configs
local NON_CLIENT_KEYS = {
  mode = true,
  ignore_filetypes = true,
  disable_inline_completion = true,
  condition = true,
  log_level = true,
  color = true,
  doc_snippet = true,
  client = true, -- deprecated: old wrapper structure
}

---Get client configuration
---@param client_name string Client name
---@return table|nil Client config
function M.get_client_config(client_name)
  local client_config = M.config[client_name]
  if client_config and type(client_config) == "table" and not NON_CLIENT_KEYS[client_name] then
    return client_config
  end
  return nil
end

---Check if client is configured
---@param client_name string Client name
---@return boolean
function M.is_client_enabled(client_name)
  return M.get_client_config(client_name) ~= nil
end

---Get active client name (first configured client found)
---@return string|nil
function M.get_active_client()
  for name, _ in pairs(M.config) do
    if not NON_CLIENT_KEYS[name] and type(M.config[name]) == "table" then
      return name
    end
  end
  return nil
end

return setmetatable(M, {
  __index = function(_, key)
    if key == "setup" then
      return M.setup
    end
    return M.config[key]
  end,
  __newindex = function(_, key, value)
    M.config[key] = value
  end,
})
