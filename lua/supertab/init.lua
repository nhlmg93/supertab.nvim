---Main entry point for supertab.nvim
local log = require("supertab.logger")
local config = require("supertab.config")
local commands = require("supertab.commands")
local api = require("supertab.api")
local doc_snippet = require("supertab.doc_snippet")

local M = {}

---@param opts? SupertabConfig
M.setup = function(opts)
  -- Check minimum Neovim version
  if vim.fn.has("nvim-0.12.0") == 0 then
    local version = vim.version()
    local version_str = string.format("%d.%d.%d", version.major, version.minor, version.patch)
    log:error("supertab.nvim requires Neovim 0.12.0+. You have " .. version_str)
    vim.notify("supertab.nvim requires Neovim 0.12.0+", vim.log.levels.ERROR, { title = "Supertab" })
    return
  end

  config.setup(opts)

  -- Load built-in clients.
  require("supertab.clients.ollama")

  -- Apply client settings if enabled
  if config.is_client_enabled("ollama") then
    local client_config = config.get_client_config("ollama")
    log:info("Ollama integration enabled")
    log:debug("Ollama config: " .. vim.inspect(client_config))
  end

  -- Setup commands
  commands.setup()

  -- Setup doc snippet (always active, even when stopped)
  doc_snippet.setup()

  -- Register nvim-cmp source if available
  local has_cmp, cmp = pcall(require, "cmp")
  if has_cmp then
    local cmp_source = require("supertab.cmp")
    cmp.register_source("supertab", cmp_source.new())
  elseif config.disable_inline_completion then
    log:warn("nvim-cmp not available but inline completion is disabled. Source not registered.")
  end

  -- Start supertab
  api.start()
end

return M
