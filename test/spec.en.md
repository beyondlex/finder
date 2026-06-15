# finder.nvim — Mechanics Specification

## 1. Modes

| Mode | Filter |
|------|--------|
| `dir` | Directories only |
| `file` | Regular files only |
| `both` | Both directories and files |

Filtering is done by `fs.list(dir, mode)` when scanning a directory. Sort order:
directories first, then by `name:lower()` alphabetically.

---

## 2. Path Mode Switching (refresh core logic)

Based on the current input path, the UI operates in one of two modes:

### 2a. Listing Mode

**Entry condition**: path ends with `/` (e.g. `~/ai/`, `~/`).

Behavior:
- Lists all items under the expanded path.
- The first result is always the **self-item** (`name=""`, `is_self=true`),
  representing the current directory itself.
- Subsequent items are the directory contents (filtered by mode).

**Special case**: path contains **no** `/` at all (e.g. `~`, `ai`) AND
`fs.expand(path)` resolves to a directory → **auto-enters Listing Mode**.

Note: `~/ai` (contains `/` but doesn't end with it) never auto-enters
Listing Mode even if `~/ai` is a real directory. It stays in Matching Mode.

### 2b. Matching Mode

**Entry condition**: path contains `/` but does not end with it
(e.g. `~/ai`, `~/do`).

Behavior:
- `parent_dir` = expanded path with the last segment stripped
- `partial` = everything after the last `/`, used as the fuzzy match query
- Results = `fs.list(parent_dir)` filtered through `matcher.match()`

**Special case**: path has no `/` and is not a directory → `parent_dir="./"`,
`partial=expanded`.

---

## 3. Path Expansion & Contraction (`fs.lua`)

| Function | Purpose | Example |
|----------|---------|---------|
| `expand("~")` | `~` → home directory | `/Users/lex` |
| `expand("~/ai")` | `~/` → home + `/ai` | `/Users/lex/ai` |
| `contract(/Users/lex)` | home → `~` | `~` |
| `contract(/Users/lex/ai)` | home prefix → `~` | `~/ai` |
| `parent("~/a/b")` | Get parent directory | `~/a/` |
| `parent("~")` | Special: returns `/` | `/` |
| `parent("/")` | Root edge case | `""` |
| `basename("~/a/b")` | Get last segment | `b` |
| `is_dir(path)` | Check if path is a directory | — |

---

## 4. Fuzzy Matching (`matcher.lua`)

### 4a. First-Character Filter

Matched items **must start with the same character as the query**,
case-insensitively. Query `Ai` → first char `A` → only items starting with
`a` or `A` match (`ai/`, `Applications/`). `train` does not match.

### 4b. Subsequent Fuzzy Matching

After the first-character filter, remaining characters are matched using
`vim.fn.matchfuzzypos()` with the **query lowered to lowercase**. This avoids
`matchfuzzypos`'s default case-sensitivity, which would cause `Ai` to only
match uppercase `A`.

### 4c. Single-Character Shortcut

When the query has only 1 character, `matchfuzzypos` is skipped entirely;
the first-character filter results are returned directly.

### 4d. Return Structure

Each result item contains:
- `name` — original item name
- `is_dir` — whether it's a directory
- `match_positions` — list of match positions (0-indexed byte offsets from
  `matchfuzzypos`)

Note: `matchfuzzypos` positions are re-ordered based on the matched subset,
not indices into the original items array.

---

## 5. Display & Highlighting

### 5a. `parent_display`

`refresh()` computes `parent_display` as the path prefix for results:

| Scenario | parent_display | Example |
|----------|---------------|---------|
| Listing Mode | `effective_path` (always ends with `/`) | `~/ai/` |
| Matching Mode | Everything before last `/` (inclusive) | `~/` |
| Auto-listing (`~`) | `~/` | `~/` |
| No-slash match | `""` | — |

### 5b. Match Highlight Offset

`display_offset = #parent_display` is stored on each item. When highlighting,
`col = display_offset + match_position`, ensuring highlights appear **only on
the name portion**, never on the path prefix.

Example: `~/[a]i/` correct — `~/[a]i/` wrong.

### 5c. Selected Item Highlight

The `FinderSelected` highlight group (linked to `Visual`) is applied to the
selected result line.

### 5d. Cursor Tracking

The result window's cursor always follows the selected item.

---

## 6. Tab Completion (`on_tab`)

### 6a. Prefix

Uses `self._parent_display` (computed and cached during `refresh()`).

### 6b. Completion Behavior

```
new_path = prefix .. item.name
if item.is_dir then new_path = new_path .. "/" end
```

| Scenario | prefix | name | result | Notes |
|----------|--------|------|--------|-------|
| `~/ai` → Tab | `~/` | `ai` | `~/ai/` | Matching mode |
| `~` → Tab | `~/` | `ai` | `~/ai/` | Auto-listing |
| `~/` → Tab | `~/` | `ai` | `~/ai/` | Listing mode |
| `~/ai/` → Tab | `~/ai/` | `projects` | `~/ai/projects/` | Subdir listing |
| `ai` → Tab | `""` | `some_dir` | `some_dir/` | No-slash match |

### 6c. Virtual Text

When a non-self item is selected, the input line shows `→ <item.name>` at the
end (using the `FinderHint` highlight group, gray italic).

### 6d. Self-Item Skipping

Tab does nothing for self-items (`is_self=true` or `name=""`).

---

## 7. Go to Parent (`on_go_parent`, `<C-w>` / `Cmd+↑`)

### Algorithm

```
path = get_input()
if path == "" or is_root(path) → return
parent = fs.parent(path)
if parent == "" and path starts with "~" → parent = "/"
if parent does not end with "/" → parent = parent .. "/"
set_input(parent)
refresh()
```

| Input | Result | Notes |
|-------|--------|-------|
| `~/ai/projects/` | `~/ai/` | Go up two levels |
| `~/ai/` | `~/` | Back to home |
| `~` | `/` | Special case |
| `/` | no-op | Root, can't go higher |
| `C:/` | no-op | Windows drive root |

---

## 8. Confirm & Cancel

### 8a. Enter (`on_confirm`)

- If the result list is empty → no-op.
- The selected item's `display` path (with trailing `/` stripped) is passed
  to `on_confirm(path)`.
- UI is closed.

### 8b. Esc / Ctrl-C (`on_cancel`)

- Calls `on_cancel()`.
- UI is closed.

---

## 9. UI Layout

```
┌─ Go to Path ───────────────┐
│ ~/ai/projects/cu            │  ← Input window (80×1)
├─────────────────────────────┤
│ ~/ai/projects               │  ← Self-item (selected)
│ ~/ai/projects/cursor/       │
│ ~/ai/projects/curl/         │  ← Result window (80×12)
│ ~/ai/projects/custom/       │
└─────────────────────────────┘
```

- Width: `min(80, columns × 0.65)`
- Height: `lines × 0.35` (result area max 12 rows)
- Centered in the editor
- `minimal` style with rounded borders

---

## 10. Keymaps

| Key | Mode | Action |
|-----|------|--------|
| `<Tab>` | Insert / Normal | Complete selected item |
| `<CR>` | Insert / Normal | Confirm |
| `<Esc>` | Insert / Normal | Cancel |
| `<C-c>` | Insert | Cancel |
| `<Up>` / `<Down>` | Insert | Select previous / next |
| `k` / `j` | Normal | Select previous / next |
| `<C-w>` | Insert | Go to parent directory |
| `<D-Up>` (Cmd+↑) | Insert | Go to parent directory |

`TextChangedI` autocmd triggers `refresh()`.

---

## 11. Test Environment

Isolated via `NVIM_APPNAME=nvim-finder-test`, completely independent from
the system Neovim.

### Configuration

The `plugins` list in `test/init.lua` controls whether external plugins
(e.g. blink.cmp) are loaded. `lazy.nvim` is auto-bootstrapped when the list
is non-empty.

### Load Order

1. `run.sh` writes `test/init.lua` to `~/.config/nvim-finder-test/init.lua`.
2. `lazy.nvim` starts (if plugins is non-empty).
3. `lazy.nvim`'s `setup()` resets the runtimepath, so **the project's rtp is
   appended after lazy**.
4. The project's `plugin/finder.lua` is explicitly loaded via `runtime`.
5. The finder Lua API is ready to use.

### Cleanup

`test/clean.sh` deletes all `nvim-finder-test` config/data/cache.
