local Finder = {}
Finder.__index = Finder

function Finder.new(opts)
  opts = opts or {}
  local mode = opts.mode or "dir"
  assert(mode == "dir" or mode == "file" or mode == "both",
    "mode must be 'dir', 'file', or 'both'")

  return setmetatable({
    mode = mode,
    initial_path = opts.initial_path or "~/",
    on_confirm = opts.on_confirm or function(_) end,
    on_cancel = opts.on_cancel or function() end,
  }, Finder)
end

function Finder:open()
  local UI = require("finder.ui")
  self.ui = UI.new(self)
  self.ui:show()
end

local M = {}

function M.open(opts)
  local f = Finder.new(opts)
  f:open()
end

return M
