local default_config = {
  keymaps = {
    accept_suggestion = "<Tab>",
    clear_suggestion = "<C-]>",
    accept_word = "<C-j>",
  },
  ignore_filetypes = {},
  disable_inline_completion = false,
  disable_keymaps = false,
  condition = function()
    return false
  end,
  log_level = "info",
  -- Ollama configuration
  ollama = {
    enable = true,
    host = "http://localhost:11434",
    model = "codellama",
    -- FIM (Fill-in-the-Middle) prompt support
    fim_enabled = true,
    -- Generation parameters
    temperature = 0.2,
    top_p = 0.9,
    top_k = 40,
    max_tokens = 64,
    stop_tokens = {},
    -- Debounce settings (milliseconds)
    debounce_ms = 50,
    -- Context lines for completion
    context_lines = 10,
  },
}

local M = {
  config = vim.deepcopy(default_config),
}

M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), args)
end

return setmetatable(M, {
  __index = function(_, key)
    if key == "setup" then
      return M.setup
    end
    return rawget(M.config, key)
  end,
  __newindex = function(_, key, value)
    M.config[key] = value
  end,
})