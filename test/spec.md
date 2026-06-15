# finder.nvim — 机制说明

## 1. 三种模式 (Modes)

| 模式 | 过滤 |
|------|------|
| `dir` | 仅显示目录 |
| `file` | 仅显示常规文件 |
| `both` | 显示目录 + 文件 |

由 `fs.list(dir, mode)` 在扫描目录时过滤。排序规则：目录优先，同名按 `name:lower()` 字母序。

---

## 2. 路径模式切换 (refresh 核心逻辑)

根据当前输入路径的内容，决定两种模式之一：

### 2a. Listing Mode (列目录模式)

**进入条件**: 路径以 `/` 结尾（如 `~/ai/`、`~/`）。

行为:
- 列出 `expanded` 路径下的所有内容
结果列表第一项始终为 **self-item**（`name=""`, `is_self=true`），代表当前目录自身
- 后续项为目录内容（按 mode 过滤）

**特殊条件**: 路径不含任何 `/`（如 `~`、`ai`）且 `fs.expand(path)` 结果为目录 → **自动进入 Listing Mode**。

注意: `~/ai`（含`/` 但不以`/`结尾）即使目录存在也不会自动进入 Listing Mode，始终保持 Matching Mode。

### 2b. Matching Mode (模糊匹配模式)

**进入条件**: 路径含 `/` 且不以 `/` 结尾（如 `~/ai`、`~/do`）。

行为:
- `parent_dir` = expanded 路径去尾（最后一个 `/` 之前的部分）
- `partial` = 最后一个 `/` 之后的部分，作为模糊匹配查询
- 结果 = `fs.list(parent_dir)` 经 `matcher.match()` 过滤

**特殊**: 路径不含 `/` 且不是目录 → parent_dir=`./`, partial=expanded。

---

## 3. 路径展开与压缩 (`fs.lua`)

| 函数 | 作用 | 例 |
|------|------|----|
| `expand("~")` | `~` → home 目录 | `/Users/lex` |
| `expand("~/ai")` | `~/` → home+`/ai` | `/Users/lex/ai` |
| `contract(/Users/lex)` | home → `~` | `~` |
| `contract(/Users/lex/ai)` | home prefix → `~` | `~/ai` |
| `parent("~/a/b")` | 取上级目录 | `~/a/` |
| `parent("~")` | 特殊: 返回 `/` | `/` |
| `parent("/")` | 特殊情况 | `""` |
| `basename("~/a/b")` | 取最后一段 | `b` |
| `is_dir(path)` | 判断是否目录 | — |

---

## 4. 模糊匹配 (`matcher.lua`)

### 4a. 首字符过滤

匹配项 **首字符必须与查询首字符大小写不敏感一致**。如查询 `Ai` → 首字符 `A` → 只匹配 `a`/`A` 开头的项（`ai/`、`Applications/`）。`~train` 不匹配。

### 4b. 第二字符起 Fuzzy

首字符过滤后剩余字符使用 `vim.fn.matchfuzzypos()` 做 fuzzy 匹配，且 **query 全小写**。原因：`matchfuzzypos` 默认对大小写敏感，全小写后避免 `Ai` 只匹配大写 `A` 的 bug。

### 4c. 单字符快捷

查询只有 1 个字符时跳过 `matchfuzzypos`，直接用首字符过滤结果。

### 4d. 返回结构

每项包含:
- `name`: 原始名称
- `is_dir`: 是否目录
- `match_positions`: 匹配位置列表（0-indexed 字节偏移，来自 `matchfuzzypos`）

注意: `matchfuzzypos` 的位置是基于匹配后的子集重新排序的，不是原始 items 的索引。

---

## 5. 显示与高亮

### 5a. `parent_display`

`refresh()` 计算 `parent_display` 用于结果显示的路径前缀:

| 场景 | parent_display | 例 |
|------|----------------|-----|
| Listing Mode | `effective_path`（总是以`/`结尾） | `~/ai/` |
| Matching Mode | 最后一个 `/` 之前（含`/`） | `~/` |
| Auto-listing（`~`） | `~/` | `~/` |
| 无路径匹配 | `""` | — |

### 5b. 匹配高亮偏移

`display_offset = #parent_display` 存储在每项中。高亮时 `col = display_offset + match_position`，确保高亮只在 **名称部分** 显示，不在路径前缀显示。

例：`~/[a]i/` 正确，~/`[a]i/` 的错误不会出现。

### 5c. 选中项高亮

`FinderSelected` 高亮组（link to `Visual`）应用于选中行。

### 5d. 选中框

结果窗口的 cursor 始终跟随选中项。

---

## 6. Tab 补全 (`on_tab`)

### 6a. 前缀

使用 `self._parent_display`（refresh 时计算并保存）作为前缀。

### 6b. 补全行为

```
new_path = prefix .. item.name
if item.is_dir then new_path = new_path .. "/" end
```

| 场景 | prefix | name | result | 说明 |
|------|--------|------|--------|------|
| `~/ai` → Tab | `~/` | `ai` | `~/ai/` | 匹配模式下补全路径 |
| `~` → Tab | `~/` | `ai` | `~/ai/` | auto-listing 下补全 |
| `~/` → Tab | `~/` | `ai` | `~/ai/` | listing 模式补全 |
| `~/ai/` → Tab | `~/ai/` | `projects` | `~/ai/projects/` | 子目录 listing 补全 |
| `ai` → Tab | `""` | `some_dir` | `some_dir/` | 无路径匹配 |

### 6c. 虚拟文本

选中非 self 项时，输入行末尾显示 `→ <item.name>` 提示（`FinderHint` 高亮组，灰色斜体）。

### 6d. Self-item 跳过

Tab 对 self-item（`is_self=true` 或 `name=""`）无反应。

---

## 7. 上级目录 (`on_go_parent`, `<C-w>` / `Cmd+↑`)

### 算法

```
path = get_input()
if path == "" or path == "/" → return
parent = fs.parent(path)
if parent == "" 且 path 以 "~" 开头 → parent = "/"
if parent 不以 "/" 结尾 → parent = parent .. "/"
set_input(parent)
refresh()
```

| 输入 | 结果 | 说明 |
|------|------|------|
| `~/ai/projects/` | `~/ai/` | 退回两级 |
| `~/ai/` | `~/` | 退回 home |
| `~` | `/` | 特例 |
| `/` | 不响应 | 根目录不动 |

---

## 8. 确认与取消

### 8a. Enter (on_confirm)

- 如果结果列表为空 → 不响应
- 选中项的 `display` 去除末尾 `/` 后传给 `on_confirm(path)`
- 关闭 UI

### 8b. Esc/Ctrl-C (on_cancel)

- 调用 `on_cancel()`
- 关闭 UI

---

## 9. UI 布局

```
┌─ Go to Path ───────────────┐
│ ~/ai/projects/cu            │  ← Input window (80x1)
├─────────────────────────────┤
│ ~/ai/projects               │  ← Self-item (selected)
│ ~/ai/projects/cursor/       │
│ ~/ai/projects/curl/         │  ← Result window (80x12)
│ ~/ai/projects/custom/       │
└─────────────────────────────┘
```

- 宽度: `min(80, columns * 0.65)`
- 高度: `lines * 0.35`（结果区最多 12 行）
- 居中显示
- `minimal` 风格 + 圆角边框

---

## 10. 键绑定

| 键 | 模式 | 作用 |
|----|------|------|
| `<Tab>` | Insert / Normal | 补全选中项 |
| `<CR>` | Insert / Normal | 确认 |
| `<Esc>` | Insert / Normal | 取消 |
| `<C-c>` | Insert | 取消 |
| `<Up>` / `<Down>` | Insert | 选择上下项 |
| `k` / `j` | Normal | 选择上下项 |
| `<C-w>` | Insert | 上级目录 |
| `<D-Up>` (Cmd+↑) | Insert | 上级目录 |

`TextChangedI` autocmd 触发 `refresh()`。

---

## 11. 测试环境

通过 `NVIM_APPNAME=nvim-finder-test` 隔离，与系统 Neovim 互不干扰。

### 配置

`test/init.lua` 中的 `plugins` 列表控制是否加载外部插件（如 blink.cmp）。非空时自动 bootstrap lazy.nvim。

### 加载顺序

1. `run.sh` 将 `test/init.lua` 写入 `~/.config/nvim-finder-test/init.lua`
2. lazy.nvim 启动（若 plugins 非空）
3. lazy.nvim 的 `setup()` 会重置 rtp，因此**项目 rtp 追加在 lazy 之后**
4. 项目 `plugin/finder.lua` 通过 `runtime` 显式加载
5. finder Lua API 可用

### 清理

`test/clean.sh` 删除 `nvim-finder-test` 的 config/data/cache。
