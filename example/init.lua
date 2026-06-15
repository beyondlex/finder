-- example/init.lua — Minimal Neovim config demonstrating finder.nvim usage
--
-- Run: nvim -u example/init.lua --headless -c "lua require('finder-demo')"

vim.opt.termguicolors = true
vim.opt.mouse = "a"
vim.opt.hlsearch = false

-- 1. Add finder.nvim to runtimepath
local ROOT = vim.fn.fnamemodify(vim.fn.expand("$PWD"), ":p"):gsub("/+$", "")
vim.opt.rtp:append(ROOT)
package.path = package.path .. ";" .. ROOT .. "/lua/?.lua;" .. ROOT .. "/lua/?/init.lua"

-- 2. Register commands
vim.cmd("runtime plugin/finder.lua")

-- Helper: show persistent message after finder closes
local function notify(msg)
  vim.defer_fn(function()
    vim.api.nvim_echo({ { msg } }, false, {})
  end, 50)
end

local finder = require("finder")

-- Save file to a chosen directory
vim.keymap.set("n", "<leader>fs", function()
  finder.open({
    mode = "dir",
    initial_path = "~",
    on_confirm = function(path)
      local bufname = vim.api.nvim_buf_get_name(0)
      local filename = vim.fn.fnamemodify(bufname, ":t")
      if filename == "" then filename = "unnamed" end
      local dest = path .. "/" .. filename
      vim.cmd("write " .. dest)
      notify("Saved to: " .. dest)
    end,
    on_cancel = function()
      notify("Save cancelled")
    end,
  })
end, { desc = "Save file to selected directory" })

-- Open a file from a chosen directory (both mode to allow navigation)
vim.keymap.set("n", "<leader>fo", function()
  finder.open({
    mode = "both",
    initial_path = "~",
    on_confirm = function(path)
      vim.cmd("edit " .. path)
    end,
    on_cancel = function()
      notify("Open cancelled")
    end,
  })
end, { desc = "Open file from selected directory" })

-- Browse both files and directories, copy selection to clipboard
vim.keymap.set("n", "<leader>ff", function()
  finder.open({
    mode = "both",
    initial_path = "~",
    on_confirm = function(path)
      vim.fn.setreg('"', path)
      notify('Copied "' .. path .. '" to clipboard')
    end,
    on_cancel = function()
      notify("Cancelled")
    end,
  })
end, { desc = "Browse path (both)" })

-- Print available commands
vim.notify(
  [[finder.nvim demo loaded — press:
  <leader>ff  copy path to clipboard
  <leader>fo  open file from directory
  <leader>fs  save current buffer to directory]]
)
