# Supertab Neovim Plugin

This plugin, supertab.nvim, provides AI-powered code completion using [Ollama](https://ollama.com). If you encounter any issues while using supertab.nvim, consider opening an issue or reaching out to us on [Discord](https://discord.com/invite/QQpqBmQH3w).

## Installation

Using a plugin manager, run the .setup({}) function in your Neovim configuration file.

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
require("lazy").setup({
    {
      "supermaven-inc/supertab.nvim",
      config = function()
        require("supertab.nvim").setup({})
      end,
    },
}, {})
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "supermaven-inc/supertab.nvim",
  config = function()
    require("supertab.nvim").setup({})
  end,
}
```

### Optional configuration

By default, supertab.nvim will use the `<Tab>` and `<C-]>` keymaps to accept and clear suggestions. You can change these keymaps by passing a `keymaps` table to the .setup({}) function. Also in this table is `accept_word`, which allows partially accepting a completion, up to the end of the next word. By default this keymap is set to `<C-j>`.

The `ignore_filetypes` table is used to ignore filetypes when using supertab.nvim. If a filetype is present as a key, and its value is `true`, supertab.nvim will not display suggestions for that filetype.

`suggestion_color` and `cterm` options can be used to set the color of the suggestion text.

```lua
require("supertab.nvim").setup({
  keymaps = {
    accept_suggestion = "<Tab>",
    clear_suggestion = "<C-]>",
    accept_word = "<C-j>",
  },
  ignore_filetypes = { cpp = true }, -- or { "cpp", }
  color = {
    suggestion_color = "#ffffff",
    cterm = 244,
  },
  log_level = "info", -- set to "off" to disable logging completely
  disable_inline_completion = false, -- disables inline completion for use with cmp
  disable_keymaps = false, -- disables built in keymaps for more manual control
  condition = function()
    return false
  end, -- condition to check for stopping supertab, `true` means to stop supertab when the condition is true.
  ollama = {
    enable = true, -- enable Ollama backend (default: true)
    host = "http://localhost:11434", -- Ollama server host
    model = "codellama", -- model to use for completion
    temperature = 0.2, -- generation temperature
    top_p = 0.9, -- nucleus sampling parameter
    top_k = 40, -- top-k sampling parameter
    max_tokens = 128, -- maximum tokens to generate
    debounce_ms = 50, -- debounce delay in milliseconds
    context_lines = 10, -- number of context lines to send
    fim_enabled = true, -- enable fill-in-the-middle completion
  }
})
```

### Disabling supertab.nvim conditionally

By default, supertab.nvim will always run unless `condition` function returns true or
current filetype is in `ignore_filetypes`.

You can disable supertab.nvim conditionally by setting `condition` function to return true.

```lua
require("supertab.nvim").setup({
  condition = function()
    return string.match(vim.fn.expand("%:t"), "foo.sh")
  end,
})
```

This will disable supertab.nvim for files with the name `foo.sh` in it, e.g. `myscriptfoo.sh`.

### Using with nvim-cmp

If you are using nvim-cmp, you can use the `supertab` source (which is registered by default) by adding the following to your `cmp.setup()` function:

```lua
-- cmp.lua
cmp.setup {
  ...
  sources = {
    { name = "supertab" },
  }
  ...
}
```

It also has a builtin highlight group CmpItemKindSupertab. To add an icon to Supertab for lspkind, simply add Supertab to your lspkind symbol map.

```lua
-- lspkind.lua
local lspkind = require("lspkind")
lspkind.init({
  symbol_map = {
    Supertab = "",
  },
})

vim.api.nvim_set_hl(0, "CmpItemKindSupertab", {fg ="#6CC644"})
```

Alternatively, you can add Supertab to the lspkind symbol_map within the cmp format function.

```lua
-- cmp.lua
cmp.setup {
  ...
  formatting = {
    format = lspkind.cmp_format({
      mode = "symbol",
      max_width = 50,
      symbol_map = { Supertab = "" }
    })
  }
  ...
}
```


### Programmatically checking and accepting suggestions

Alternatively, you can also check if there is an active suggestion and accept it programmatically.

For example:

```lua
require("supertab.nvim").setup({
  disable_keymaps = true
})

...

M.expand = function(fallback)
  local luasnip = require('luasnip')
  local suggestion = require('supertab.nvim.completion_preview')

  if luasnip.expandable() then
    luasnip.expand()
  elseif suggestion.has_suggestion() then
    suggestion.on_accept_suggestion()
  else
    fallback()
  end
end
```

## Usage

Upon starting supertab.nvim, it will connect to your local Ollama instance and provide AI-powered code completion.

You can also use `:SupertabShowLog` to view the logged messages in `path/to/stdpath-cache/supertab.nvim.log` if you encounter any issues. Or `:SupertabClearLog` to clear the log file.

Use `:SupertabOllamaCheck` to verify that your Ollama instance is available and accessible.

### Commands

supertab.nvim provides the following commands:

```
:SupertabStart          start supertab.nvim
:SupertabStop           stop supertab.nvim
:SupertabRestart        restart supertab.nvim
:SupertabToggle         toggle supertab.nvim
:SupertabStatus         show status of supertab.nvim
:SupertabShowLog        show logs for supertab.nvim
:SupertabClearLog       clear logs for supertab.nvim
:SupertabOllamaCheck    check Ollama availability
```

### Lua API

The `supertab.nvim.api` module provides the following functions for interacting with supertab.nvim from Lua:

```lua
local api = require("supertab.nvim.api")

api.start() -- starts supertab.nvim
api.stop() -- stops supertab.nvim
api.restart() -- restarts supertab.nvim if it is running, otherwise starts it
api.toggle() -- toggles supertab.nvim
api.is_running() -- returns true if supertab.nvim is running
api.show_log() -- show logs for supertab.nvim
api.clear_log() -- clear logs for supertab.nvim
api.get_backend() -- returns the active backend ("ollama" or "none")
```
