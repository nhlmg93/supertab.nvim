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
---@field ollama? SupertabOllamaConfig
---@field doc_snippet? SupertabDocSnippetConfig

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
---@field doc_max_tokens? number
---@field debounce_ms? number
---@field context_lines? number

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
  ollama = {
    enable = true,
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
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), opts)
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
