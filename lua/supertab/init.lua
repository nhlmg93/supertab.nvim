local completion_preview = require("supertab.completion_preview")
local log = require("supertab.logger")
local config = require("supertab.config")
local commands = require("supertab.commands")
local api = require("supertab.api")

local M = {}

---@type integer|nil
local keymap_bufnr = nil

---@param min_version string
---@return boolean
local function check_version(min_version)
  local nvim_version = vim.version()
  local min = vim.version.parse(min_version)
  if not min then
    return false
  end
  return nvim_version.major > min.major
    or (nvim_version.major == min.major and nvim_version.minor >= min.minor)
end

---@param bufnr integer
---@param key string
---@param func function
---@param desc string
local function set_buffer_keymap(bufnr, key, func, desc)
  vim.keymap.set("i", key, func, {
    noremap = true,
    silent = true,
    buffer = bufnr,
    desc = desc,
  })
end

---@param opts? SupertabConfig
M.setup = function(opts)
  -- Check minimum Neovim version
  if not check_version("0.9.0") then
    local version = vim.version()
    local version_str = string.format("%d.%d.%d", version.major, version.minor, version.patch)
    log:error("supertab.nvim requires Neovim 0.9.0+. You have " .. version_str)
    vim.notify("supertab.nvim requires Neovim 0.9.0+", vim.log.levels.ERROR, { title = "Supertab" })
    return
  end

  config.setup(opts)

  -- Apply Ollama settings
  if config.ollama and config.ollama.enable then
    log:info("Ollama integration enabled")
    log:debug("Ollama config: " .. vim.inspect(config.ollama))

    local ollama = require("supertab.ollama")
    if config.ollama.debounce_ms then
      ollama.debounce_ms = config.ollama.debounce_ms
    end
  end

  -- Setup keymaps
  if not config.disable_inline_completion and not config.disable_keymaps then
    -- Use buffer-local keymaps for the current buffer
    -- In practice, these should be set up per-buffer via autocmd
    -- but for now we use global keymaps
    if config.keymaps.accept_suggestion then
      vim.keymap.set("i", config.keymaps.accept_suggestion, completion_preview.on_accept_suggestion, {
        noremap = true,
        silent = true,
        desc = "Accept supertab suggestion",
      })
    end

    if config.keymaps.accept_word then
      vim.keymap.set("i", config.keymaps.accept_word, completion_preview.on_accept_suggestion_word, {
        noremap = true,
        silent = true,
        desc = "Accept next word of supertab suggestion",
      })
    end

    if config.keymaps.clear_suggestion then
      vim.keymap.set("i", config.keymaps.clear_suggestion, completion_preview.on_dispose_inlay, {
        noremap = true,
        silent = true,
        desc = "Clear supertab suggestion",
      })
    end
  end

  -- Setup commands
  commands.setup()

  -- Register nvim-cmp source if available
  local has_cmp, cmp = pcall(require, "cmp")
  if has_cmp then
    local cmp_source = require("supertab.cmp")
    cmp.register_source("supertab", cmp_source.new())
  elseif config.disable_inline_completion then
    log:warn("nvim-cmp not available but inline completion is disabled. Source not registered.")
  end

  -- Auto-start if enabled
  api.start()
end

return M
