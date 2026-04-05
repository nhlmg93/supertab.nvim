# supertab.nvim

AI-powered code completion for Neovim using [Ollama](https://ollama.com). Get intelligent, context-aware suggestions as you type.

[![Neovim](https://img.shields.io/badge/Neovim-0.12+-green.svg)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-blue.svg)](https://www.lua.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Features

- 🤖 **Local AI completion** - Uses your local Ollama instance, no data leaves your machine
- ⚡ **Streaming suggestions** - See completions appear character-by-character
- 🎯 **Context-aware** - Understands your code context for relevant suggestions
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
      ollama = {
        model = "codellama",
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
  -- Keymaps (set to false to disable)
  keymaps = {
    accept_suggestion = "<Tab>",
    clear_suggestion = "<C-]>",
    accept_word = "<C-j>",
  },

  -- Disable for specific filetypes
  ignore_filetypes = { "TelescopePrompt", "NvimTree" },

  -- Disable inline ghost text
  disable_inline_completion = false,

  -- Disable all default keymaps (for manual configuration)
  disable_keymaps = false,

  -- Condition function to disable supertab
  -- Return true to disable for current context
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

  -- Ollama configuration
  ollama = {
    enable = true,
    host = "http://localhost:11434",
    model = "codellama",     -- or "llama2", "deepseek-coder", etc.
    temperature = 0.2,       -- lower = more deterministic
    max_tokens = 256,        -- max tokens to generate
    debounce_ms = 50,        -- delay before triggering completion
    context_lines = 10,      -- lines of context to send
    max_lines = 10,          -- max ghost text lines to display
  },
})
```

## Usage

### Default Keymaps

| Key | Action |
|-----|--------|
| `<Tab>` | Accept full suggestion |
| `<C-]>` | Clear suggestion |
| `<C-j>` | Accept next word only |

### Commands

```vim
:SupertabStart        " Start completion
:SupertabStop         " Stop completion  
:SupertabToggle       " Toggle on/off
:SupertabRestart      " Restart service
:SupertabStatus       " Show status
:SupertabShowLog      " Open log file
:SupertabClearLog     " Clear log file
:SupertabOllamaCheck  " Check Ollama connection
```

### Lua API

```lua
local api = require("supertab.api")

api.start()           -- Start service
api.stop()            -- Stop service
api.restart()         -- Restart service
api.toggle()          -- Toggle service
api.is_running()      -- Check if running
api.get_backend()     -- Get backend name

-- Completion preview API
local preview = require("supertab.completion_preview")
preview.on_accept_suggestion()      -- Accept full
preview.on_accept_suggestion_word() -- Accept word
preview.on_dispose_inlay()          -- Clear
preview.has_suggestion()            -- Check active
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
- Ollama connection status
- Optional dependencies

## Custom Keymaps

Disable defaults and configure your own:

```lua
require("supertab").setup({
  disable_keymaps = true,
})

local preview = require("supertab.completion_preview")

-- Accept with Alt-Tab
vim.keymap.set("i", "<M-Tab>", preview.on_accept_suggestion)

-- Accept word with Alt-w  
vim.keymap.set("i", "<M-w>", preview.on_accept_suggestion_word)

-- Clear with Esc (you probably want to keep this one)
vim.keymap.set("i", "<Esc>", function()
  if preview.has_suggestion() then
    preview.on_dispose_inlay()
  else
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
  end
end)
```

## Troubleshooting

**No suggestions appearing:**
1. Check Ollama is running: `:SupertabOllamaCheck`
2. Check logs: `:SupertabShowLog`
3. Run health check: `:checkhealth supertab`

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
