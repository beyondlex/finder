if vim.g.loaded_finder then return end
vim.g.loaded_finder = 1

local finder = require("finder")

local function parse_args(raw)
  if not raw or raw == "" then return {}, "" end
  local extensions
  local path = raw
  local ext_prefix = "%-%-ext%s+"
  local ext_str = path:match(ext_prefix .. "([^%s]+)")
  if ext_str then
    extensions = vim.split(ext_str, ",")
    path = path:gsub(ext_prefix .. vim.pesc(ext_str), ""):gsub("^%s+", ""):gsub("%s+$", "")
  end
  return extensions, path
end

local function make_cmd(mode)
  return function(opts)
    local config = { mode = mode }
    local extensions, path = parse_args(opts.args)
    if #extensions > 0 then config.extensions = extensions end
    if path and path ~= "" then config.initial_path = path end
    finder.open(config)
  end
end

vim.api.nvim_create_user_command("Finder", make_cmd("dir"), {
  desc = "Open finder (dir mode). :Finder ~/Downloads",
  nargs = "?",
  complete = "dir",
})

vim.api.nvim_create_user_command("FinderDir", make_cmd("dir"), {
  desc = "Open finder (dir mode). :FinderDir ~/Downloads",
  nargs = "?",
  complete = "dir",
})

vim.api.nvim_create_user_command("FinderFile", make_cmd("file"), {
  desc = "Open finder (file mode). :FinderFile ~/Downloads",
  nargs = "?",
  complete = "file",
})

vim.api.nvim_create_user_command("FinderBoth", make_cmd("both"), {
  desc = "Open finder (both mode). :FinderBoth ~/Downloads",
  nargs = "?",
  complete = "file",
})
