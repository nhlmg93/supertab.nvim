-- plugin/supertab.lua
-- This file is automatically sourced by Neovim on startup
-- Used for detecting duplicate loads and setting up global state

if vim.g.loaded_supertab then
  return
end
vim.g.loaded_supertab = 1

-- Optional: Define commands that will trigger lazy loading
-- Most functionality remains in lua/supertab/ and requires setup() call