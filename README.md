# supertab.nvim

AI-powered code completion for Neovim with built-in [Ollama](https://ollama.com) support and a client architecture ready for additional backends.

[![Neovim](https://img.shields.io/badge/Neovim-0.12+-green.svg)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-blue.svg)](https://www.lua.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Features

- 🤖 **AI completion** - Built-in Ollama client today, extensible client architecture for more backends
- ⚡ **Streaming suggestions** - See completions appear character-by-character
- 🎯 **Context-aware** - Understands your code context for relevant suggestions
- 📝 **Doc snippet** - Type `~doc` on empty line for AI-generated documentation
- 🔌 **nvim-cmp integration** - Works as a completion source for nvim-cmp
- ⚙️ **Highly configurable** - Customizable keymaps, debounce, models, and more

## Requirements

- Neovim 0.12+
- [Ollama](https://ollama.com) installed and running locally
- Optional: [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) for completion menu support

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "nhlmg93/supertab.nvim",
  opts = {
    -- your configuration
  },
}
```

Or with explicit setup:

```lua
{
  "nhlmg93/supertab.nvim",
  config = function()
    require("supertab").setup({
      client = "ollama",
      clients = {
        ollama = {
          model = "codellama",
        },
      },
    })
  end,
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "nhlmg93/supertab.nvim",
  config = function()
    require("supertab").setup()
  end,
}
```

## Configuration

```lua
require("supertab").setup({
  -- Mode: "completion" (default) or "doc"
  mode = "completion",

  -- Active client
  client = "ollama",

  -- Disable for specific filetypes
  ignore_filetypes = { "TelescopePrompt", "NvimTree" },

  -- Disable inline ghost text
  disable_inline_completion = false,

  -- Return true to disable supertab for the current context
  condition = function()
    return false
  end,

  -- Logging: "off", "trace", "debug", "info", "warn", "error"
  log_level = "info",

  -- Suggestion color (optional)
  color = {
    suggestion_color = "#808080",
    cterm = 244,
  },

  -- Per-client configuration
  clients = {
    ollama = {
      enable = true,
      host = "http://localhost:11434",
      model = "codellama", -- or "codestral", "deepseek-coder", etc.
      temperature = 0.2,
      top_p = 0.9,
      top_k = 40,
      max_tokens = 16,
      doc_max_tokens = 512,
      debounce_ms = 50,
      context_lines = 10,
    },
  },

  -- Doc snippet configuration
  doc_snippet = {
    enabled = true,
    trigger = "~doc",
  },
})
```

## Usage

### Commands

| Command | Description |
|-----|--------|
| `:SupertabAccept` | Accept full suggestion |
| `:SupertabAcceptWord` | Accept next word |
| `:SupertabClear` | Clear suggestion |
| `:SupertabToggleMode` | Toggle completion/doc mode |
| `:SupertabStart` | Start completion |
| `:SupertabStop` | Stop completion |
| `:SupertabToggle` | Toggle on/off |
| `:SupertabRestart` | Restart service |
| `:SupertabStatus` | Show status |
| `:SupertabShowLog` | Open log file |
| `:SupertabClearLog` | Clear log file |
| `:SupertabOllamaCheck` | Check Ollama connection |
| `:SupertabClientCheck` | Check configured client availability |

### Doc Snippet

Type `~doc` on any empty line to insert a documentation template:

```
~doc  →  /*
          Document: $1

          ```lua

          $2

          ```
          */
```

1. Type your topic after `Document:` at `$1`
2. Press `<Tab>` — AI generates a code example at `$2`
3. Press `<Tab>` again to exit the snippet

### Modes

Supertab has two modes, toggled via `:SupertabToggleMode`:

- **completion** (default): Inline FIM suggestions as you type
- **doc**: Completions off. Type `~doc` to get an AI-generated example inserted into your code

### Lua API

```lua
local api = require("supertab.api")

api.accept_suggestion()  -- Accept suggestion (or jump snippet)
api.accept_word()        -- Accept next word
api.clear_suggestion()   -- Clear suggestion
api.toggle_mode()        -- Toggle completion/doc mode
api.get_mode()           -- Returns "completion" or "doc"
api.start()              -- Start service
api.stop()               -- Stop service
api.restart()            -- Restart service
api.toggle()             -- Toggle service
api.is_running()         -- Check if running
api.get_backend()        -- Get backend name
```

## nvim-cmp Integration

supertab registers itself as a cmp source automatically. To add it to your cmp sources:

```lua
cmp.setup({
  sources = {
    { name = "supertab" },
    -- your other sources
  },
})
```

To add a kind icon with lspkind:

```lua
lspkind.init({
  symbol_map = {
    Supertab = "擄",
  },
})

vim.api.nvim_set_hl(0, "CmpItemKindSupertab", { fg = "#6CC644" })
```

## Health Check

Run `:checkhealth supertab` to verify:
- Neovim version compatibility
- Configured client status
- Registered client availability
- Optional dependencies

## Keymaps

Supertab ships no default keymaps. Bind commands to your preferred keys:

```lua
vim.keymap.set('i', '<Tab>', '<cmd>SupertabAccept<CR>')
vim.keymap.set('i', '<C-]>', '<cmd>SupertabClear<CR>')
vim.keymap.set('i', '<C-j>', '<cmd>SupertabAcceptWord<CR>')
vim.keymap.set({ 'n', 'i' }, '<C-t>', '<cmd>SupertabToggleMode<CR>')
```

## Troubleshooting

**No suggestions appearing:**
1. Check the configured client: `:SupertabClientCheck`
2. If you use Ollama specifically: `:SupertabOllamaCheck`
3. Check logs: `:SupertabShowLog`
4. Run health check: `:checkhealth supertab`

**Slow suggestions:**
- Increase `debounce_ms` (default 50ms)
- Decrease `max_tokens` for faster generation
- Check your Ollama model isn't too large for your hardware

**Wrong completions:**
- Increase `context_lines` for more context
- Try a different model (e.g., `deepseek-coder` for code)
- Adjust `temperature` (lower = more deterministic)

## License

MIT
