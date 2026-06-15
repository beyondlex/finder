# test — Isolated Local Dev Environment

Launches a fully isolated Neovim instance via `NVIM_APPNAME`, **leaving your
system Neovim untouched**.

## Usage

```bash
# Clean launch (only the local finder plugin)
./test/run.sh

# Clear all test data before launching
./test/run.sh --clean

# Open a specific file
./test/run.sh -- ~/some/file.txt
```

## Configuring Plugins

Edit `test/init.lua` — add or remove entries from the `plugins` list:

```lua
-- test/init.lua
local plugins = {
  { "saghen/blink.cmp", version = "*" },  -- uncomment to load
  -- { "nvim-tree/nvim-tree.lua" },
}
```

`lazy.nvim` is auto-installed when `plugins` is non-empty. No need to modify `run.sh`.

## Cleaning All Test Data

```bash
./test/clean.sh
```

Deletes `nvim-finder-test` config / data / cache. System Neovim is unaffected.

## Keymaps Provided by the Test Environment

| Key | Action |
|-----|--------|
| `<leader>f` | Open finder (both mode) |
| `<leader>F` | Open finder with custom initial path |
| `:FinderOpen ~/Downloads` | Open finder via command |

## Directory Structure

```
test/
├── init.lua      # ← Edit this to configure plugins
├── run.sh        # Launch script
├── clean.sh      # Cleanup script
├── spec.md       # Detailed mechanics documentation
├── spec.lua      # Automated test suite
└── README.md     # This file
```

On launch, `run.sh` automatically writes `test/init.lua` to
`~/.config/nvim-finder-test/init.lua` — no manual config setup is needed.
