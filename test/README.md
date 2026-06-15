# test — 本地开发测试环境

通过 `NVIM_APPNAME` 机制启动完全隔离的 Neovim 实例，**不影响系统 Neovim 配置**。

## 用法

```bash
# 纯净启动（仅加载本地 finder 插件）
./test/run.sh

# 启动前清除所有测试数据
./test/run.sh --clean

# 打开特定文件
./test/run.sh -- ~/some/file.txt
```

## 配置插件

编辑 `test/init.lua`，在 `plugins` 列表中添加或移除插件即可：

```lua
-- test/init.lua
local plugins = {
  { "saghen/blink.cmp", version = "*" },  -- 取消注释即加载
  -- { "nvim-tree/nvim-tree.lua" },
}
```

`lazy.nvim` 在 `plugins` 非空时自动安装。无需修改 `run.sh`。

## 清除所有测试数据

```bash
./test/clean.sh
```

删除 `nvim-finder-test` 的 config / data / cache，系统 Neovim 不受影响。

## 测试环境提供的快捷键

| 快捷键 | 作用 |
|---|---|
| `<leader>f` | 打开 finder（both 模式） |
| `<leader>F` | 输入初始路径后打开 finder |
| `:FinderOpen ~/Downloads` | 命令形式打开 finder |

## 目录结构

```
test/
├── init.lua      # ← 编辑此文件配置插件
├── run.sh        # 启动脚本
├── clean.sh      # 清除脚本
└── README.md     # 本文件
```

启动时 `run.sh` 自动将 `test/init.lua` 写入 `~/.config/nvim-finder-test/init.lua`，无需手动创建任何配置文件。
