-- test/init.lua
-- Edit this file to configure which plugins to load.
-- Run test/run.sh to launch.

vim.opt.termguicolors = true
-- vim.cmd("colorscheme habamax")
vim.opt.mouse = "a"
vim.opt.hlsearch = false

-- Project root (set by run.sh)
local ROOT = vim.g.finder_root or vim.fn.getcwd()

-- ── Plugins ──────────────────────────────────────────────
-- Add plugins here. lazy.nvim will be auto-installed if this list is non-empty.
local plugins = {
  -- { "saghen/blink.cmp", version = "*" },
  -- { "nvim-tree/nvim-tree.lua" },
}

-- lazy.nvim bootstrap (must run before rtp changes)
if #plugins > 0 then
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  if not vim.uv.fs_stat(lazypath) then
    vim.fn.system({
      "git", "clone", "--filter=blob:none",
      "https://github.com/folke/lazy.nvim.git",
      "--branch=stable", lazypath,
    })
  end
  vim.opt.rtp:prepend(lazypath)
  require("lazy").setup(plugins)
end

-- ── Local plugin (after lazy to avoid rtp overwrite) ─────
vim.opt.rtp:append(ROOT)
package.path = package.path .. ";" .. ROOT .. "/lua/?.lua;" .. ROOT .. "/lua/?/init.lua"
vim.cmd("runtime plugin/finder.lua")

-- ── Finder test commands ─────────────────────────────────
local finder = require("finder")

vim.api.nvim_create_user_command("FinderOpen", function(opts)
  finder.open({
    mode = "both",
    initial_path = opts.args ~= "" and opts.args or "~",
    on_confirm = function(path) print("Selected: " .. path) end,
    on_cancel = function() print("Cancelled") end,
  })
end, { nargs = "?" })

vim.keymap.set("n", "<leader>f", function() vim.cmd("FinderOpen") end, { desc = "Open finder" })
vim.keymap.set("n", "<leader>F", function()
  vim.ui.input({ prompt = "Initial path: ", default = "~" }, function(input)
    if input then vim.cmd("FinderOpen " .. input) end
  end)
end, { desc = "Open finder with custom path" })
