if vim.g.loaded_finder then return end
vim.g.loaded_finder = 1

vim.api.nvim_create_user_command("Finder", function(opts)
  local config = {}
  if opts.bang then
    config.mode = "file"
  end
  if opts.args and opts.args ~= "" then
    local ok, result = pcall(vim.json.decode, opts.args)
    if ok then
      config = vim.tbl_extend("force", config, result)
    end
  end
  require("finder").open(config)
end, {
  desc = "Open finder path browser (dir mode), bang=file mode",
  nargs = "?",
  bang = true,
})
