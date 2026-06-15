# finder.nvim

[English](./README.md) | [中文](./README.zh-CN.md)

---

macOS Finder-style "Go to Folder" path browser for Neovim. Provides an interactive
floating-window UI for selecting file or directory paths via fuzzy matching.

## Features

- **Three modes** — `dir` / `file` / `both` (filter by type)
- **Interactive input** — as you type, the result list updates in real-time
- **Smart mode switching** — trailing `/` lists directory contents; otherwise
  fuzzy-matches items under the parent directory
- **Auto-listing** — paths without any `/` (e.g. `~`, `foo`) that resolve to a
  directory auto-list its contents
- **Fuzzy matching** — first character prefix filter (case-insensitive) +
  `matchfuzzypos` with lowercased query for subsequent characters
- **Match highlighting** — matched characters highlighted only in the item name,
  not in the parent path prefix
- **Tab completion** — completes the selected item's name into the input;
  virtual text shows what Tab will complete
- **Parent navigation** — `<C-w>` / `Cmd+↑` strips the last path segment
- **Isolated test environment** — `test/run.sh` launches via `NVIM_APPNAME`
  without touching your system Neovim

## Installation

```lua
-- lazy.nvim
{
  "beyondlex/finder",
  config = function()
    -- :Finder commands auto-registered
  end,
}
```

## Commands

| Command | Mode | Description |
|---------|------|-------------|
| `:Finder ~/Downloads` | dir | Browse directories |
| `:FinderDir ~/Downloads` | dir | Alias for `:Finder` |
| `:FinderFile ~/Downloads` | file | Browse files |
| `:FinderBoth ~/Downloads` | both | Browse files + directories |

Arguments are optional. `<Tab>` completion for paths (`complete=dir/file`).

## Lua API

```lua
local finder = require("finder")

finder.open({
  mode = "dir",          -- "dir" | "file" | "both"
  initial_path = "~",    -- starting path
  on_confirm = function(path)
    print("Selected: " .. path)
  end,
  on_cancel = function()
    print("Cancelled")
  end,
})
```

## Keymaps

| Key | Mode | Action |
|-----|------|--------|
| `<Tab>` | Insert / Normal | Complete selected item into path |
| `<CR>` | Insert / Normal | Confirm selection |
| `<Esc>` / `<C-c>` | Insert / Normal | Cancel |
| `<Up>` / `<Down>` | Insert | Select previous / next item |
| `k` / `j` | Normal | Select previous / next item |
| `<C-w>` / `Cmd+↑` | Insert | Go to parent directory |

## How It Works

### Path Mode Switching

The UI operates in two modes, determined by the current input:

- **Listing mode** — activated when the input ends with `/` (e.g. `~/ai/`) or
  has no `/` at all and resolves to a directory (e.g. `~`, `foo`). Lists all
  items in the expanded directory. The first result is always a **self-item**
  representing the directory itself.

- **Matching mode** — activated when the input contains `/` but does not end
  with it (e.g. `~/ai`, `~/do`). Extracts the parent directory (everything
  before the last `/`) and fuzzy-matches items under it with the trailing text.

> `~/ai` keeps matching mode even when `~/ai` is a directory — it only lists
> if you add the trailing `/` to get `~/ai/`.

### Fuzzy Matching

1. **First-character filter** — items must start with the same character as the
   query (case-insensitive). `Ai` only matches names starting with `a` or `A`.
2. **Subsequent fuzzy** — uses `vim.fn.matchfuzzypos` with the query lowered
   to avoid case-sensitivity issues.
3. **Single char** — skips `matchfuzzypos` entirely, just returns the
   first-char filtered results.

Each result carries `match_positions` (0-indexed byte offsets from
`matchfuzzypos`) for highlighting.

### Display & Match Highlighting

Results are displayed as `parent_display + item_name`. The `parent_display`
varies by mode:

| Mode | parent_display | Example |
|------|---------------|---------|
| Listing | effective path (trailing `/`) | `~/ai/` |
| Matching | everything before last `/` | `~/` |
| Auto-listing (no slash) | path with `/` appended | `~/` |

A `display_offset` (equal to `#parent_display`) is stored per item so that
match highlights are applied only to the item name portion, not the prefix.

### Tab Completion

Uses `self._parent_display` (computed and cached during `refresh()`) as the
prefix. Builds the new path as `prefix .. item.name`, appending `/` for
directories.

| Input | Result | Mode |
|-------|--------|------|
| `~/ai` + Tab | `~/ai/` | matching |
| `~` + Tab | `~/ai/` | auto-listing |
| `~/ai/` + Tab | `~/ai/projects/` | listing |
| `ai` + Tab | `some_dir/` | no-slash matching |

### Go to Parent (`<C-w>` / `Cmd+↑`)

Strips the last path segment and ensures a trailing `/`:

| Input | Result |
|-------|--------|
| `~/ai/projects/` | `~/ai/` |
| `~/` | `/` |
| `~` | `/` |
| `/` | no-op |

### Confirm & Cancel

- **Enter** — passes the selected item's display path (without trailing `/`)
  to `on_confirm(path)` and closes the UI. Does nothing when the result list
  is empty.
- **Esc** / **Ctrl-C** — calls `on_cancel()` and closes the UI.

### UI Layout

```
┌─ Go to Path ────────────────┐
│ ~/ai/projects/cu            │  ← Input (width × 1)
├─────────────────────────────┤
│ ~/ai/projects               │  ← Self-item (selected)
│ ~/ai/projects/cursor/       │
│ ~/ai/projects/curl/         │  ← Results (width × ≤12)
│ ~/ai/projects/custom/       │
└─────────────────────────────┘
```

Centered in the editor, `minimal` style with rounded borders.

## File Structure

```
lua/finder/
├── init.lua      # Entry point + Finder class
├── ui.lua        # Floating window UI (input, results, virtual text)
├── fs.lua        # Filesystem operations (expand, parent, list, ...)
└── matcher.lua   # Fuzzy matching (first-char filter + matchfuzzypos)
plugin/
└── finder.lua    # :Finder/:FinderDir/:FinderFile/:FinderBoth commands
test/
├── run.sh        # Isolated test environment launcher
├── clean.sh      # Delete all test data
├── init.lua      # Test config (edit to add/remove plugins)
├── spec.md       # Detailed mechanics documentation
├── spec.lua      # Automated test suite (85+ tests)
└── README.md     # Test environment instructions
```

## Example

See [example/](./example/) for a runnable Neovim config with demo keymaps:

```bash
nvim -u example/init.lua
```

## Development

```bash
# Launch isolated test environment
./test/run.sh

# With plugins (edit test/init.lua first)
./test/run.sh

# Clean and launch
./test/run.sh --clean

# Run automated tests
./test/run.sh --clean -- --headless -l test/spec.lua -c 'qa!'

# Clean all test data
./test/clean.sh
```

## License

MIT
