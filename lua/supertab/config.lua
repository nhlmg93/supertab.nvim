local M = {}

---@class SupertabConfig
---@field keymaps? SupertabKeymaps
---@field ignore_filetypes? table<string, boolean>
---@field disable_inline_completion? boolean
---@field disable_keymaps? boolean
---@field condition? fun(): boolean
---@field log_level? "off" | "trace" | "debug" | "info" | "warn" | "error"
---@field color? SupertabColorConfig
---@field ollama? SupertabOllamaConfig

---@class SupertabKeymaps
---@field accept_suggestion? string
---@field clear_suggestion? string
---@field accept_word? string

---@class SupertabColorConfig
---@field suggestion_color? string
---@field cterm? number

---@class SupertabOllamaConfig
---@field enable? boolean
---@field host? string
---@field model? string
---@field temperature? number
---@field top_p? number
---@field top_k? number
---@field max_tokens? number
---@field debounce_ms? number
---@field context_lines? number

---@type SupertabConfig
local default_config = {
  keymaps = {
    accept_suggestion = "<Tab>",
    clear_suggestion = "<C-]>",
    accept_word = "<C-j>",
  },
  ignore_filetypes = {},
  disable_inline_completion = false,
  disable_keymaps = false,
  ---@type fun(): boolean
  condition = function()
    return false
  end,
  log_level = "warn",
  color = nil,
  ollama = {
    enable = true,
    host = "http://localhost:11434",
    model = "codellama",
    temperature = 0.2,
    top_p = 0.9,
    top_k = 40,
    max_tokens = 16,
    debounce_ms = 50,
    context_lines = 10,
  },
}

---@type SupertabConfig
M.config = vim.deepcopy(default_config)

---@param opts? SupertabConfig
M.setup = function(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), opts)
end

---@param key string
---@return any
local function get_config_value(key)
  return M.config[key]
end

---@param key string
---@param value any
local function set_config_value(key, value)
  M.config[key] = value
end

return setmetatable(M, {
  __index = function(_, key)
    if key == "setup" then
      return M.setup
    end
    return get_config_value(key)
  end,
  __newindex = function(_, key, value)
    set_config_value(key, value)
  end,
})
