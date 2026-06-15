# finder.nvim

[English](./README.md) | [中文](./README.zh-CN.md)

---

macOS Finder「Go to Folder」体验的 Neovim 路径浏览器插件。提供交互式浮窗 UI，
通过模糊匹配选择文件或目录路径。

## 特性

- **三种模式** — `dir` / `file` / `both`（按类型过滤）
- **扩展名过滤** — `file` 模式下可限定只展示特定扩展名的文件（如仅 `csv`、`tsv`、`json`）
- **实时输入** — 随输入动态更新结果列表
- **智能模式切换** — 末尾 `/` 列目录内容；否则对上级目录做模糊匹配
- **自动列目录** — 不含 `/` 的路径（如 `~`、`foo`）若解析为目录则自动列出其内容
- **模糊匹配** — 首字符前缀过滤（大小写不敏感）+ 后续 `matchfuzzypos` 小写化匹配
- **`*` 前缀子串匹配** — 以 `*` 开头则匹配名称任意位置的子串（如 `*abc` 匹配名称中含 `abc` 的项）。结果仍经模糊排序和高亮。
- **匹配高亮** — 仅高亮名称部分的匹配字符，路径前缀不高亮
- **Tab 补全** — 将选中项补全到输入框；虚拟文本提示补全内容
- **上级目录** — `<C-w>` / `Cmd+↑` 退回上一级
- **隔离测试环境** — `test/run.sh` 通过 `NVIM_APPNAME` 启动纯净实例

## 安装

```lua
-- lazy.nvim
{
  dir = "beyondlex/finder",
  config = function()
    -- :Finder 命令会自动注册
  end,
}
```

## 命令

| 命令 | 模式 | 说明 |
|---------|------|------|
| `:Finder ~/Downloads` | dir | 浏览目录 |
| `:FinderDir ~/Downloads` | dir | `:Finder` 别名 |
| `:FinderFile ~/Downloads` | file | 浏览文件 |
| `:FinderBoth ~/Downloads` | both | 浏览文件 + 目录 |

`--ext <列表>` 限定只展示指定扩展名的文件（逗号分隔，不带点）：

| 示例 | 说明 |
|------|------|
| `:FinderFile --ext csv,tsv,json ~/data` | 仅显示 `.csv`、`.tsv`、`.json` 文件 |
| `:FinderFile --ext lua` | 仅显示 `.lua` 文件 |

参数可选。支持 `<Tab>` 路径补全（`complete=dir/file`）。

## Lua API

```lua
local finder = require("finder")

finder.open({
  mode = "dir",          -- "dir" | "file" | "both"
  initial_path = "~",    -- 初始路径
  extensions = {"csv", "tsv", "json"},  -- 可选：仅显示这些扩展名的文件（file 模式）
  on_confirm = function(path)
    print("选中: " .. path)
  end,
  on_cancel = function()
    print("已取消")
  end,
})
```

## 键绑定

| 键 | 模式 | 作用 |
|-----|------|--------|
| `<Tab>` | Insert / Normal | 补全选中项到路径 |
| `<CR>` | Insert / Normal | 确认选择 |
| `<Esc>` / `<C-c>` | Insert / Normal | 取消 |
| `<Up>` / `<Down>` | Insert | 上/下选择 |
| `k` / `j` | Normal | 上/下选择 |
| `<C-w>` / `Cmd+↑` | Insert | 进入上级目录 |

## 工作原理

### 路径模式切换

UI 根据输入内容运行在两种模式：

- **列目录模式** — 输入以 `/` 结尾（如 `~/ai/`）或完全不包含 `/` 且解析为目录
  （如 `~`、`foo`）时激活。列出展开目录下的全部内容。首个结果总是 **self-item**，
  代表当前目录自身。

- **匹配模式** — 输入包含 `/` 但不以 `/` 结尾（如 `~/ai`、`~/do`）时激活。
  提取父目录（最后一个 `/` 之前的部分）并对下级项做模糊匹配。

> `~/ai` 即使 `~/ai` 是真实目录也保持匹配模式——只有输入 `~/ai/` 才进入列目录模式。

### 模糊匹配

1. **首字符过滤** — 匹配项的首字符必须与查询首字符相同（大小写不敏感）。
   `Ai` 只匹配以 `a` 或 `A` 开头的项。
2. **后续模糊** — 使用 `vim.fn.matchfuzzypos`，查询字符串全小写以避免大小写问题。
3. **单字符** — 跳过 `matchfuzzypos`，直接返回首字符过滤结果。

每个结果携带 `match_positions`（来自 `matchfuzzypos` 的 0-indexed 字节偏移）用于高亮。

### 显示与匹配高亮

结果以 `parent_display + item_name` 形式显示。`parent_display` 因模式而异：

| 模式 | parent_display | 示例 |
|------|---------------|------|
| 列目录 | 有效路径（末尾带 `/`） | `~/ai/` |
| 匹配 | 最后一个 `/` 之前的所有内容 | `~/` |
| 自动列目录（无斜杠） | 路径补上 `/` | `~/` |

每项存储 `display_offset`（等于 `#parent_display`），确保高亮只应用于名称部分，
不作用于前缀。

### Tab 补全

使用 `self._parent_display`（`refresh()` 时计算并缓存）作为前缀。
新路径为 `prefix .. item.name`，目录追加 `/`。

| 输入 | 结果 | 模式 |
|-------|--------|------|
| `~/ai` + Tab | `~/ai/` | 匹配 |
| `~` + Tab | `~/ai/` | 自动列目录 |
| `~/ai/` + Tab | `~/ai/projects/` | 列目录 |
| `ai` + Tab | `some_dir/` | 无斜杠匹配 |

### 上级目录（`<C-w>` / `Cmd+↑`）

去掉最后一段路径并确保末尾带 `/`：

| 输入 | 结果 |
|-------|--------|
| `~/ai/projects/` | `~/ai/` |
| `~/` | `/` |
| `~` | `/` |
| `/` | 不响应 |

### 确认与取消

- **Enter** — 将选中项的显示路径（去除末尾 `/`）传给 `on_confirm(path)` 并关闭 UI。
  结果列表为空时不响应。
- **Esc** / **Ctrl-C** — 回调 `on_cancel()` 并关闭 UI。

### UI 布局

```
┌─ Go to Path ────────────────┐
│ ~/ai/projects/cu            │  ← 输入框 (width × 1)
├─────────────────────────────┤
│ ~/ai/projects               │  ← Self-item (选中)
│ ~/ai/projects/cursor/       │
│ ~/ai/projects/curl/         │  ← 结果列表 (width × ≤12)
│ ~/ai/projects/custom/       │
└─────────────────────────────┘
```

居中显示，`minimal` 风格圆角边框。

## 文件结构

```
lua/finder/
├── init.lua      # 入口 + Finder 类
├── ui.lua        # 浮窗 UI（输入框、结果列表、虚拟文本）
├── fs.lua        # 文件系统操作（expand, parent, list, ...）
└── matcher.lua   # 模糊匹配（首字符过滤 + matchfuzzypos）
plugin/
└── finder.lua    # :Finder/:FinderDir/:FinderFile/:FinderBoth 命令
test/
├── run.sh        # 隔离测试环境启动脚本
├── clean.sh      # 删除所有测试数据
├── init.lua      # 测试配置（编辑以添加/移除插件）
├── spec.md       # 详细机制说明文档
├── spec.lua      # 自动化测试套件（85+ 项）
└── README.md     # 测试环境说明
```

## 示例

参考 [example/](./example/) 目录，包含一个可直接运行的 Neovim 配置及演示快捷键：

```bash
nvim -u example/init.lua
```

## 开发

```bash
# 启动隔离测试环境
./test/run.sh

# 携带插件启动（先编辑 test/init.lua）
./test/run.sh

# 清理后启动
./test/run.sh --clean

# 运行自动化测试
./test/run.sh --clean -- --headless -l test/spec.lua -c 'qa!'

# 清理所有测试数据
./test/clean.sh
```

## 许可

MIT
