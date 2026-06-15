if vim.g.loaded_finder then return end
vim.g.loaded_finder = 1

local finder = require("finder")

local function make_cmd(mode)
  return function(opts)
    local config = { mode = mode }
    if opts.args and opts.args ~= "" then
      config.initial_path = opts.args
    end
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
