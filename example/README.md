# example — Usage examples for finder.nvim

## Quick start

```bash
# Launch Neovim with finder.nvim loaded and demo keymaps
nvim -u example/init.lua
```

## Keymaps (defined in example/init.lua)

| Key | Action | Mode |
|-----|--------|------|
| `<leader>ff` | Browse files + dirs, copy path to clipboard | both |
| `<leader>fo` | Pick a file and open it | file |
| `<leader>fs` | Pick a directory and save current buffer there | dir |

## Lua API usage patterns

```lua
local finder = require("finder")

-- Pick a directory (save target)
finder.open({
  mode = "dir",
  initial_path = "~/Downloads",
  on_confirm = function(path)
    vim.cmd("cd " .. path)
  end,
  on_cancel = function()
    print("Cancelled")
  end,
})

-- Pick a file (open target)
finder.open({
  mode = "both",
  initial_path = "~",
  on_confirm = function(path)
    vim.cmd("edit " .. path)
  end,
  on_cancel = function() end,
})

-- Pick either
finder.open({
  mode = "both",
  initial_path = vim.fn.getcwd(),
  on_confirm = function(path)
    vim.fn.setreg('"', path)
    print("Copied to clipboard: " .. path)
  end,
  on_cancel = function() end,
})
```

## Commands (auto-registered)

```
:FinderDir ~/Projects   — browse directories
:FinderFile ~/Downloads — browse files
:FinderBoth ~/          — browse files + directories
:Finder                 — alias for FinderDir
```
