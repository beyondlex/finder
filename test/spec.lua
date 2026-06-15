-- test/spec.lua — Automated test suite for finder.nvim
--
-- Run: test/run.sh --clean -- --headless -l test/spec.lua -c "qa!"
--      Returns exit code 0 on pass, 1 on fail.

local PASS, FAIL, TOTAL = 0, 0, 0

local function assert_eq(got, expected, label)
  TOTAL = TOTAL + 1
  if got == expected then
    PASS = PASS + 1
    return
  end
  FAIL = FAIL + 1
  local got_str = type(got) == "string" and ("%q"):format(got) or tostring(got)
  local exp_str = type(expected) == "string" and ("%q"):format(expected) or tostring(expected)
  print(("FAIL  %s\n      got:      %s\n      expected: %s"):format(label, got_str, exp_str))
end

local function assert_true(val, label)
  assert_eq(val, true, label)
end

local function assert_false(val, label)
  assert_eq(val, false, label)
end

local function assert_contains(list, val, label)
  TOTAL = TOTAL + 1
  for _, v in ipairs(list) do
    if v == val then
      PASS = PASS + 1
      return
    end
  end
  FAIL = FAIL + 1
  print(("FAIL  %s\n      %s not found in list"):format(label, tostring(val)))
end

local function assert_match(str, pattern, label)
  TOTAL = TOTAL + 1
  if str:match(pattern) then
    PASS = PASS + 1
    return
  end
  FAIL = FAIL + 1
  print(("FAIL  %s\n      %q does not match pattern %s"):format(label, str, pattern))
end

-- ── Setup: project root and modules ──────────────────────────
local ROOT = vim.g.finder_root
if not ROOT then
  ROOT = vim.fn.fnamemodify(vim.fn.expand("$PWD"), ":p"):gsub("/+$", "")
end
-- Try to resolve relative to the test file location
if ROOT:match("test$") then
  ROOT = vim.fn.fnamemodify(ROOT, ":h")
end
vim.opt.rtp:append(ROOT)
package.path = package.path .. ";" .. ROOT .. "/lua/?.lua;" .. ROOT .. "/lua/?/init.lua"

local fs = require("finder.fs")
local matcher = require("finder.matcher")

-- ── Test fixture setup ──────────────────────────────────────
local TMP = vim.fn.tempname():gsub("tmp[^/]*$", "finder_spec")
vim.fn.mkdir(TMP, "p")

local function mkdir(p) vim.fn.mkdir(p, "p") end
local function write(p, content) vim.fn.writefile(vim.split(content or "", "\n"), p) end

mkdir(TMP .. "/dir_a")
mkdir(TMP .. "/dir_b")
mkdir(TMP .. "/dir_empty")
write(TMP .. "/dir_a/sub_file.txt", "hello")
write(TMP .. "/file_a.txt", "aaa")
write(TMP .. "/file_b.txt", "bbb")
write(TMP .. "/file_c.lua", "ccc")
write(TMP .. "/alpha.txt", "lowercase first")
write(TMP .. "/Beta.txt", "uppercase first")

local HOME = vim.fn.expand("~")
local HOME_TILDE = "~"

-- ═══════════════════════════════════════════════════════════════
-- 1. fs.expand
-- ═══════════════════════════════════════════════════════════════

print("── fs.expand ──")
assert_eq(fs.expand("~"), HOME, "expand tilde alone")
assert_eq(fs.expand("~/ai"), HOME .. "/ai", "expand tilde with path")
assert_eq(fs.expand("/tmp"), "/tmp", "expand absolute path unchanged")
assert_eq(fs.expand(""), "", "expand empty returns empty string")
assert_eq(fs.expand(nil), nil, "expand nil returns nil")

-- ═══════════════════════════════════════════════════════════════
-- 2. fs.contract
-- ═══════════════════════════════════════════════════════════════

print("── fs.contract ──")
assert_eq(fs.contract(HOME), "~", "contract home to tilde")
assert_eq(fs.contract(HOME .. "/ai"), "~/ai", "contract home path to tilde")
assert_eq(fs.contract("/tmp"), "/tmp", "contract non-home path unchanged")

-- ═══════════════════════════════════════════════════════════════
-- 3. fs.parent
-- ═══════════════════════════════════════════════════════════════

print("── fs.parent ──")
assert_eq(fs.parent(TMP .. "/dir_a"), TMP .. "/", "parent of subdir")
assert_eq(fs.parent("~/ai/projects"), "~/ai/", "parent with tilde")
assert_eq(fs.parent("~/ai/"), "~/", "parent of dir with trailing slash")
assert_eq(fs.parent("~/ai/projects/"), "~/ai/", "parent of deep path with slash")
assert_eq(fs.parent("~"), "", "parent of bare tilde → empty (no slash in ~)")
assert_eq(fs.parent("/"), "/", "parent of root → root")
assert_eq(fs.parent(""), "", "parent of empty → empty")

-- ═══════════════════════════════════════════════════════════════
-- 4. fs.basename
-- ═══════════════════════════════════════════════════════════════

print("── fs.basename ──")
assert_eq(fs.basename("~/ai/projects"), "projects", "basename tilde path")
assert_eq(fs.basename("~/ai/projects/"), "projects", "basename with trailing slash")
assert_eq(fs.basename("foo"), "foo", "basename single segment")
assert_eq(fs.basename("/"), "", "basename of root is empty")

-- ═══════════════════════════════════════════════════════════════
-- 5. fs.is_dir
-- ═══════════════════════════════════════════════════════════════

print("── fs.is_dir ──")
assert_true(fs.is_dir(TMP), "is_dir on tmp dir")
assert_true(fs.is_dir(TMP .. "/dir_a"), "is_dir on subdir")
assert_false(fs.is_dir(TMP .. "/file_a.txt"), "is_dir on file")
assert_false(fs.is_dir(TMP .. "/nonexistent"), "is_dir on nonexistent")
assert_false(fs.is_dir(""), "is_dir on empty string")

-- ═══════════════════════════════════════════════════════════════
-- 6. fs.list — mode filtering & sorting
-- ═══════════════════════════════════════════════════════════════

print("── fs.list ──")
local all_items = fs.list(TMP, "both")
assert_eq(#all_items, 8, "list both returns 8 items: 3 dirs + 5 files (" .. #all_items .. ")")

-- dirs first, then files; alphabetical case-insensitive
assert_eq(all_items[1].name, "dir_a", "list[1] = dir_a (dir, alpha)")
assert_true(all_items[1].is_dir, "list[1] is dir")
assert_eq(all_items[2].name, "dir_b", "list[2] = dir_b")
assert_true(all_items[2].is_dir, "list[2] is dir")
assert_eq(all_items[3].name, "dir_empty", "list[3] = dir_empty")
assert_true(all_items[3].is_dir, "list[3] is dir")
-- Files sorted by name:lower(); alpha.txt < Beta.txt (a < b lower) after dirs
local file_start_idx = 4
assert_false(all_items[file_start_idx].is_dir, "list[4] is file (first file after dirs)")
assert_eq(all_items[#all_items].name, "file_c.lua", "last file = file_c.lua (highest lower)")
-- Verify file_a comes before file_b (lower sort)
local idx_a, idx_b, idx_c = 0, 0, 0
for i, item in ipairs(all_items) do
  if item.name == "file_a.txt" then idx_a = i end
  if item.name == "file_b.txt" then idx_b = i end
  if item.name == "file_c.lua" then idx_c = i end
end
assert_true(idx_a < idx_b, "file_a.txt before file_b.txt (lower sort)")
assert_true(idx_b < idx_c, "file_b.txt before file_c.lua (lower sort)")

-- mode=dir
local dir_items = fs.list(TMP, "dir")
assert_eq(#dir_items, 3, "list dir returns 3 dirs (" .. #dir_items .. ")")
for _, item in ipairs(dir_items) do
  assert_true(item.is_dir, "list dir only returns dirs")
end

-- mode=file
local file_items = fs.list(TMP, "file")
assert_eq(#file_items, 5, "list file returns 5 files (" .. #file_items .. ")")
for _, item in ipairs(file_items) do
  assert_false(item.is_dir, "list file only returns files")
end

-- nonexistent dir
local empty_items = fs.list(TMP .. "/nonexistent", "both")
assert_eq(#empty_items, 0, "list nonexistent dir returns empty")

-- ═══════════════════════════════════════════════════════════════
-- 7. matcher.match — fuzzy matching
-- ═══════════════════════════════════════════════════════════════

print("── matcher.match ──")
local items = {
  { name = "ai", is_dir = true },
  { name = "Applications", is_dir = true },
  { name = "train", is_dir = true },
}

-- empty query → all items
local m_all = matcher.match(items, "")
assert_eq(#m_all, 3, "match empty query returns all")

-- single char → first-char prefix filter (case-insensitive)
local m_a = matcher.match(items, "a")
assert_eq(#m_a, 2, "match 'a' returns 2 items (ai, Applications)")
assert_eq(m_a[1].name, "ai", "match 'a' first = ai")
assert_eq(m_a[2].name, "Applications", "match 'a' second = Applications")

local m_A = matcher.match(items, "A")
assert_eq(#m_A, 2, "match 'A' also returns 2 items (case-insensitive)")
assert_eq(m_A[1].name, "ai", "match 'A' first = ai")
assert_eq(m_A[2].name, "Applications", "match 'A' second = Applications")

-- first char mismatch → empty
local m_z = matcher.match(items, "z")
assert_eq(#m_z, 0, "match 'z' returns empty")

-- multi-char: first char filter + fuzzy on remainder
local m_ai = matcher.match(items, "ai")
assert_eq(#m_ai, 2, "match 'ai' returns 2")

-- match_positions are NOT present for single-char queries
local m_a_check = matcher.match(items, "a")
if #m_a_check > 0 then
  assert_eq(m_a_check[1].match_positions, nil, "no match positions for 1-char query")
end
-- match_positions ARE present for multi-char queries
local m_ai_check = matcher.match(items, "ai")
if #m_ai_check > 0 then
  assert_true(m_ai_check[1].match_positions ~= nil, "match positions present for multi-char query")
end

-- ═══════════════════════════════════════════════════════════════
-- 8. UI: _parent_display computation (core refresh logic)
-- ═══════════════════════════════════════════════════════════════

print("── UI refresh logic ──")
local UI = require("finder.ui")

-- Helper: simulate refresh's parent_display computation
local function compute_parent_display(path)
  local expanded = fs.expand(path)
  local listing = path:sub(-1) == "/"
  local has_slash = path:find("/") ~= nil
  local parent_dir, partial
  local uv = vim.uv or vim.loop

  if listing then
    parent_dir = expanded
    partial = ""
  elseif not has_slash then
    local stat_ok, stat = pcall(uv.fs_stat, expanded)
    if stat_ok and stat and stat.type == "directory" then
      listing = true
    end
  end

  if listing then
    local effective_path = path:sub(-1) ~= "/" and (path .. "/") or path
    return effective_path
  else
    local effective_path = path
    local last_slash = effective_path:match("^(.*/).*$")
    return last_slash or ""
  end
end

assert_eq(compute_parent_display("~/ai"), "~/", "parent_display for matching mode")
assert_eq(compute_parent_display("~"), "~/", "parent_display for auto-listing tilde")
assert_eq(compute_parent_display("~/"), "~/", "parent_display for listing root")
assert_eq(compute_parent_display("~/ai/"), "~/ai/", "parent_display for listing subdir")
assert_eq(compute_parent_display("ai"), "", "parent_display for no-slash nonexisent")

-- ═══════════════════════════════════════════════════════════════
-- 9. fs.list with tilde expansion
-- ═══════════════════════════════════════════════════════════════

print("── fs.list tilde ──")
-- We expect HOME to have at least some entries
local home_items = fs.list("~", "both")
assert_true(#home_items > 0, "list ~ returns items")
-- Verify items under ~ are not full paths — they're names
assert_true(home_items[1].name ~= nil, "list ~ returns items with names")

-- ═══════════════════════════════════════════════════════════════
-- 10. Verify mode=both includes all types in subdirectory
-- ═══════════════════════════════════════════════════════════════

print("── mixed content listing ──")
local sub_items = fs.list(TMP, "both")
assert_true(sub_items[1].is_dir, "first item in mixed list is dir")
-- Check we have both files and dirs in the list
local has_dir, has_file = false, false
for _, item in ipairs(sub_items) do
  if item.is_dir then has_dir = true end
  if not item.is_dir then has_file = true end
end
assert_true(has_dir, "both mode includes dirs")
assert_true(has_file, "both mode includes files")

-- ═══════════════════════════════════════════════════════════════
-- 11. parent with trailing-slash paths
-- ═══════════════════════════════════════════════════════════════

print("── fs.parent edge cases ──")
assert_eq(fs.parent("foo"), "", "parent of single segment returns empty")
assert_eq(fs.parent("foo/bar"), "foo/", "parent of relative path")

-- ═══════════════════════════════════════════════════════════════
-- 12. cross-platform: separator, normalize, is_root
-- ═══════════════════════════════════════════════════════════════

print("── cross-platform ──")
local sep = fs.separator()
assert_true(sep == "/" or sep == "\\", "separator is / or \\")

-- normalize
assert_eq(fs.normalize(nil), nil, "normalize nil")
assert_eq(fs.normalize(""), "", "normalize empty")
assert_eq(fs.normalize("~/ai/projects"), "~/ai/projects", "normalize unix path unchanged")

-- is_root
assert_true(fs.is_root("/"), "is_root /")
assert_true(fs.is_root("C:/"), "is_root C:/")
assert_true(fs.is_root("D:/"), "is_root D:/")
assert_false(fs.is_root(""), "is_root empty")
assert_false(fs.is_root("~/"), "is_root ~/")

-- parent at Windows drive root
assert_eq(fs.parent("C:/"), "", "parent of C:/ is empty")
assert_eq(fs.parent("D:/foo"), "D:/", "parent of D:/foo is D:/")

-- parent at root
assert_eq(fs.parent("/"), "/", "parent of / is /")
assert_eq(fs.parent(""), "", "parent of empty")

-- basename edge: Windows paths
assert_eq(fs.basename("C:/foo/bar.txt"), "bar.txt", "basename C:/foo/bar.txt")
assert_eq(fs.basename("C:"), "C:", "basename bare drive letter")
assert_eq(fs.basename("C:/"), "C:", "basename C:/ returns drive letter")

-- normalize with backslashes: only meaningful on Windows (platform separator)
-- On Unix backslashes are left as-is since they're not path separators
local normalized = fs.normalize("C:\\Users\\lex")
if fs.separator() == "\\" then
  assert_eq(normalized, "C:/Users/lex", "normalize backslashes to forward slashes")
else
  -- On Unix, normalize is a no-op for non-separator chars
  assert_eq(normalized, "C:\\Users\\lex", "normalize leaves non-separator backslashes on unix")
end

-- ═══════════════════════════════════════════════════════════════
-- 13. matcher.match — non-empty result has correct properties
-- ═══════════════════════════════════════════════════════════════

print("── matcher result props ──")
local t_items = {
  { name = "dotfiles", is_dir = true },
  { name = "docs", is_dir = true },
  { name = "Downloads", is_dir = true },
}
local m_d = matcher.match(t_items, "do")
for _, item in ipairs(m_d) do
  assert_true(item.match_positions ~= nil and #item.match_positions > 0, "match item has positions")
  for _, pos in ipairs(item.match_positions) do
    assert_eq(type(pos), "number", "match position is a number")
  end
end

-- ═══════════════════════════════════════════════════════════════
-- 14. basename edge cases
-- ═══════════════════════════════════════════════════════════════

print("── fs.basename edge ──")
assert_eq(fs.basename("a/b/c/d.txt"), "d.txt", "basename deep path")

-- ═══════════════════════════════════════════════════════════════
-- 15. list sorting: dirs before files, case-insensitive alpha
-- ═══════════════════════════════════════════════════════════════

print("── list sorting ──")
local sorted = fs.list(TMP, "both")
-- dirs come first
assert_true(sorted[1].is_dir, "sorted[1] is dir")
assert_true(sorted[2].is_dir, "sorted[2] is dir")
assert_true(sorted[3].is_dir, "sorted[3] is dir")
-- files after dirs
assert_false(sorted[4].is_dir, "sorted[4] is file")
-- file_a.txt < file_b.txt < file_c.lua by lower
local sidx_a, sidx_b, sidx_c = 0, 0, 0
for i, item in ipairs(sorted) do
  if item.name == "file_a.txt" then sidx_a = i end
  if item.name == "file_b.txt" then sidx_b = i end
  if item.name == "file_c.lua" then sidx_c = i end
end
assert_true(sidx_a < sidx_b, "sorted file_a before file_b")
assert_true(sidx_b < sidx_c, "sorted file_b before file_c")

-- ═══════════════════════════════════════════════════════════════
-- Cleanup
-- ═══════════════════════════════════════════════════════════════

vim.fn.delete(TMP, "rf")

-- ═══════════════════════════════════════════════════════════════
-- Summary
-- ═══════════════════════════════════════════════════════════════

print(string.rep("─", 50))
print(("Results: %d/%d passed, %d failed"):format(PASS, TOTAL, FAIL))
if FAIL > 0 then
  vim.cmd("cq") -- exit 1
end
-- On success, let -c "qa!" exit cleanly (exit 0)
