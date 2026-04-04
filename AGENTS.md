# Project Guidelines for AI Agents

## Overview
**supertab.nvim** is an AI-powered code completion plugin for Neovim using Ollama (local LLM). It provides inline ghost text suggestions and integrates with nvim-cmp as a completion source.

## Tech Stack
- **Language:** Lua (Neovim plugin)
- **AI Backend:** Ollama HTTP API (local, default: codellama)
- **Dependencies:** Built-in Neovim APIs only (no external Lua deps)
- **Formatting:** Stylua (2-space indent, Unix line endings, AutoPreferDouble quotes)

## Project Structure
```
lua/supertab/
├── init.lua              # Main entry point, setup(), keymaps
├── config.lua            # Configuration schema + defaults (typed with EmmyLua)
├── api.lua               # Public API: start(), stop(), toggle(), etc.
├── commands.lua          # Vim command definitions (:SupertabStart, etc.)
├── cmp.lua               # nvim-cmp source integration
├── completion_preview.lua # Inline ghost text rendering (extmarks)
├── document_listener.lua # Buffer change detection, trigger logic
├── health.lua            # :checkhealth supertab implementation
├── logger.lua            # Leveled logging utility
├── util.lua              # Shared utilities
└── ollama/
    ├── init.lua          # Ollama module entry
    └── client.lua        # HTTP client for Ollama API

doc/supertab.txt          # Vim help documentation (:help supertab)
```

## Development Commands
- **Format:** `stylua .` (uses `.stylua.toml`)
- **Test:** Manual in Neovim - no automated test suite
- **Health check:** `:checkhealth supertab`
- **View logs:** `:SupertabShowLog`

## Code Conventions

### Lua Style (Stylua-enforced)
- 2-space indentation
- Unix line endings
- Prefer double quotes (AutoPreferDouble)
- Run `stylua .` before committing

### EmmyLua Type Annotations
All config and functions are typed:
```lua
---@class SupertabConfig
---@field keymaps? SupertabKeymaps
---@field ollama? SupertabOllamaConfig

---@param opts? SupertabConfig
M.setup = function(opts)
```

### Module Pattern
```lua
local M = {}
-- implementation
return M
```

### Keymap Conventions
- Buffer-local when possible, global as fallback
- Always use `{ noremap = true, silent = true, desc = "..." }`
- Check `config.disable_keymaps` before setting defaults

### Configuration Pattern
1. Define `default_config` table in `config.lua`
2. Merge with user opts via `vim.tbl_deep_extend("force", ...)`
3. Use metatable for `__index`/`__newindex` access
4. Access config via `require("supertab.config").key`

### Error Handling
- Use `pcall()` for optional dependencies (e.g., `require("cmp")`)
- Log errors via `require("supertab.logger")` (not raw `print()`)
- User-facing errors use `vim.notify(..., vim.log.levels.ERROR)`

### Logging
```lua
local log = require("supertab.logger")
log:trace("detail for debugging")
log:debug("internal state")
log:info("normal operation")
log:warn("recoverable issue")
log:error("critical failure")
```

## Key Patterns

### Inline Completion (Ghost Text)
Uses Neovim extmarks with `virt_text` and `virt_text_pos = "inline"`:
```lua
local ns_id = vim.api.nvim_create_namespace("supertab")
vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, col, {
  virt_text = { { suggestion_text, "SupertabSuggestion" } },
  virt_text_pos = "inline",
  hl_mode = "combine",
})
```

### Debounced Completion Trigger
```lua
local debounce_timer = vim.uv.new_timer()
local function debounced_complete()
  debounce_timer:stop()
  debounce_timer:start(debounce_ms, 0, vim.schedule_wrap(function()
    trigger_completion()
  end))
end
```

### HTTP Client (Ollama)
Uses `vim.uv` for async HTTP to Ollama:
```lua
local client = vim.uv.new_tcp()
client:connect("127.0.0.1", 11434, function(err)
  vim.schedule(function()
    -- handle response
  end)
end)
```

### Autocmd Setup Pattern
```lua
local group = vim.api.nvim_create_augroup("Supertab", { clear = true })
vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
  group = group,
  callback = function(args)
    -- completion logic
  end,
})
```

## Common Tasks

### Adding a Config Option
1. Add to `default_config` in `lua/supertab/config.lua` with EmmyLua type
2. Use in module via `require("supertab.config").option_name`
3. Document in `README.md` Configuration section
4. Document in `doc/supertab.txt` for `:help`

### Adding a Command
1. Add to `lua/supertab/commands.lua`:
```lua
vim.api.nvim_create_user_command("SupertabNewCommand", function(opts)
  require("supertab.api").new_action()
end, { desc = "Description" })
```
2. Expose via `lua/supertab/api.lua` if needed

### Adding to nvim-cmp Source
Edit `lua/supertab/cmp.lua`:
- `new()` - create source instance
- `complete(params, callback)` - return items via `callback({ items = ... })`
- `is_available()` - check if source should activate

### Debugging Tips
1. Set `log_level = "trace"` in config
2. View logs: `:SupertabShowLog` or `~/.local/share/nvim/supertab.log`
3. Check Ollama directly: `curl http://localhost:11434/api/tags`
4. Verify extmarks: `:lua print(vim.inspect(vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, {})))`

## References
- **Help:** `:help supertab` (source: `doc/supertab.txt`)
- **Ollama API:** https://github.com/ollama/ollama/blob/main/docs/api.md
- **nvim-cmp source:** https://github.com/hrsh7th/nvim-cmp/blob/main/lua/cmp/source.lua
- **Neovim Lua:** `:help lua-guide`, `:help api-extended-marks`
