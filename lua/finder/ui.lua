local fs = require("finder.fs")
local matcher = require("finder.matcher")

local M = {}
M.__index = M

local ns_finder = vim.api.nvim_create_namespace("finder")

function M.new(finder)
  local self = setmetatable({
    finder = finder,
    input_buf = nil,
    input_win = nil,
    result_buf = nil,
    result_win = nil,
    selected = 1,
    results = {},
  }, M)
  return self
end

function M:augroup()
  return "FinderUI_" .. tostring(self)
end

function M:show()
  self:create_windows()
  self:setup_highlights()
  self:setup_keymaps()
  self:setup_autocmds()

  local initial = self.finder.initial_path
  vim.api.nvim_buf_set_lines(self.input_buf, 0, -1, false, { initial })

  local cursor_col = vim.fn.strcharpart(initial, 0, #initial)
  vim.api.nvim_win_set_cursor(self.input_win, { 1, #initial })

  vim.api.nvim_set_current_win(self.input_win)
  vim.cmd("startinsert!")

  self:refresh()
end

function M:create_windows()
  local width = math.min(80, math.floor(vim.o.columns * 0.65))
  local win_height = math.floor(vim.o.lines * 0.35)
  local result_height = math.min(12, win_height - 1)
  local row = math.floor((vim.o.lines - win_height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  self.input_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(self.input_buf, "bufhidden", "wipe")

  self.input_win = vim.api.nvim_open_win(self.input_buf, true, {
    relative = "editor",
    width = width,
    height = 1,
    row = row,
    col = col,
    style = "minimal",
    border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
    title = " Go to Path ",
    title_pos = "center",
  })
  vim.api.nvim_win_set_option(self.input_win, "winhl", "Normal:NormalFloat")

  self.result_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(self.result_buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(self.result_buf, "modifiable", false)

  self.result_win = vim.api.nvim_open_win(self.result_buf, false, {
    relative = "editor",
    width = width,
    height = result_height,
    row = row + 2,
    col = col,
    style = "minimal",
    border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
  })
  vim.api.nvim_win_set_option(self.result_win, "winhl", "Normal:NormalFloat")
end

function M:setup_highlights()
  pcall(vim.api.nvim_set_hl, 0, "FinderMatch", { fg = "#ff9f64", bold = true })
  pcall(vim.api.nvim_set_hl, 0, "FinderSelected", { link = "Visual" })
  pcall(vim.api.nvim_set_hl, 0, "FinderHint", { fg = "#565f89", italic = true })
end

function M:setup_keymaps()
  local buf = self.input_buf
  local map = function(mode, key, cb)
    vim.api.nvim_buf_set_keymap(buf, mode, key, "", {
      callback = cb,
      noremap = true,
      silent = true,
    })
  end

  map("i", "<CR>", function() self:on_confirm() end)
  map("i", "<Esc>", function() self:on_cancel() end)
  map("i", "<C-c>", function() self:on_cancel() end)
  map("i", "<Tab>", function() self:on_tab() end)
  map("i", "<Up>", function() self:on_up() end)
  map("i", "<Down>", function() self:on_down() end)
  map("i", "<C-w>", function() self:on_go_parent() end)
  map("i", "<D-Up>", function() self:on_go_parent() end)

  map("n", "<CR>", function() self:on_confirm() end)
  map("n", "<Esc>", function() self:on_cancel() end)
  map("n", "k", function() self:on_up() end)
  map("n", "j", function() self:on_down() end)
  map("n", "<Tab>", function() self:on_tab() end)
end

function M:setup_autocmds()
  vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = self.input_buf,
    callback = function() self:refresh() end,
  })
end

function M:get_input()
  local lines = vim.api.nvim_buf_get_lines(self.input_buf, 0, 1, false)
  return (lines[1] or "")
end

function M:set_input(text)
  vim.api.nvim_buf_set_lines(self.input_buf, 0, -1, false, { text })
  pcall(vim.api.nvim_win_set_cursor, self.input_win, { 1, #text })
end

function M:refresh()
  local path = self:get_input()
  if path == "" then
    self.results = {}
    self.selected = 1
    self:render_results()
    self:render_virtual_text()
    return
  end

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
      parent_dir = expanded .. "/"
      partial = ""
      listing = true
    else
      parent_dir = "./"
      partial = expanded
    end
  else
    local last_slash = expanded:match("^(.*/).*$")
    if last_slash then
      parent_dir = last_slash
      partial = expanded:sub(#last_slash + 1)
    else
      parent_dir = expanded:match("^(.*/)") or (expanded ~= "" and "./" or "")
      partial = expanded:match("^.*/(.+)$") or expanded
    end
  end

  local all_items = fs.list(parent_dir, self.finder.mode)
  local matched
  if partial == "" then
    matched = all_items
  else
    matched = matcher.match(all_items, partial)
  end

  local parent_display
  local effective_path = path
  if listing and path:sub(-1) ~= "/" then
    effective_path = path .. "/"
  end
  if listing then
    parent_display = effective_path
  else
    local last_slash = effective_path:match("^(.*/).*$")
    parent_display = last_slash or ""
  end

  self.results = {}

  if listing then
    table.insert(self.results, 1, {
      name = "",
      display = effective_path:gsub("/$", ""),
      is_dir = true,
      is_self = true,
    })
  end

  local display_offset = #parent_display

  for _, item in ipairs(matched) do
    local display_name = parent_display .. item.name
    if item.is_dir and display_name:sub(-1) ~= "/" then
      display_name = display_name .. "/"
    end
    table.insert(self.results, {
      name = item.name,
      display = display_name,
      is_dir = item.is_dir,
      display_offset = display_offset,
      match_positions = item.match_positions,
    })
  end

  if self.selected > #self.results then self.selected = #self.results end
  if self.selected < 1 and #self.results > 0 then self.selected = 1 end

  self:render_results()
  self:render_virtual_text()
end

function M:render_results()
  vim.api.nvim_buf_set_option(self.result_buf, "modifiable", true)
  vim.api.nvim_buf_clear_namespace(self.result_buf, ns_finder, 0, -1)

  local lines = {}
  for _, item in ipairs(self.results) do
    table.insert(lines, item.display)
  end
  vim.api.nvim_buf_set_lines(self.result_buf, 0, -1, false, lines)

  if self.selected > 0 and self.selected <= #self.results then
    local sel_line = self.results[self.selected].display
    local sel_len = vim.fn.strdisplaywidth(sel_line)
    vim.api.nvim_buf_add_highlight(
      self.result_buf, ns_finder, "FinderSelected",
      self.selected - 1, 0, -1
    )
    pcall(vim.api.nvim_win_set_cursor, self.result_win, { self.selected, 0 })
  end

  self:highlight_matches()
  vim.api.nvim_buf_set_option(self.result_buf, "modifiable", false)
end

function M:highlight_matches()
  for idx, item in ipairs(self.results) do
    if item.match_positions and #item.match_positions > 0 then
      local offset = item.display_offset or 0
      for _, col in ipairs(item.match_positions) do
        vim.api.nvim_buf_add_highlight(
          self.result_buf, ns_finder, "FinderMatch",
          idx - 1, offset + col, offset + col + 1
        )
      end
    end
  end
end

function M:render_virtual_text()
  vim.api.nvim_buf_clear_namespace(self.input_buf, ns_finder, 0, -1)

  if #self.results == 0 or self.selected == 0 then return end

  local item = self.results[self.selected]
  if item.is_self or item.name == "" then return end
  local hint = item.name:gsub("/$", "")
  if hint == "" then return end

  vim.api.nvim_buf_set_extmark(self.input_buf, ns_finder, 0, 0, {
    virt_text = { { " → " .. hint, "FinderHint" } },
    virt_text_pos = "eol",
  })
end

function M:on_confirm()
  if #self.results == 0 then return end
  local item = self.results[self.selected]
  local path = item.display:gsub("/$", "")
  self:close()
  self.finder.on_confirm(path)
end

function M:on_cancel()
  self:close()
  self.finder.on_cancel()
end

function M:on_tab()
  if #self.results == 0 then return end
  local item = self.results[self.selected]
  if item.is_self or item.name == "" then return end

  local path = self:get_input()
  local path_for_prefix = path
  if path:sub(-1) ~= "/" then
    local uv = vim.uv or vim.loop
    local expanded = fs.expand(path)
    local stat_ok, stat = pcall(uv.fs_stat, expanded)
    if stat_ok and stat and stat.type == "directory" then
      path_for_prefix = path .. "/"
    end
  end
  local last_slash = path_for_prefix:match("^(.*/).*$")
  local prefix = last_slash or ""
  local new_path = prefix .. item.name
  if item.is_dir then new_path = new_path .. "/" end

  self:set_input(new_path)
  self:refresh()
end

function M:on_up()
  if self.selected > 1 then
    self.selected = self.selected - 1
    self:render_results()
    self:render_virtual_text()
  end
end

function M:on_down()
  if self.selected < #self.results then
    self.selected = self.selected + 1
    self:render_results()
    self:render_virtual_text()
  end
end

function M:on_go_parent()
  local path = self:get_input()
  if path == "" or path == "/" then return end
  local parent = fs.parent(path)
  if parent == "" then
    if path:sub(1,1) == "~" then
      parent = "/"
    else
      return
    end
  end
  if parent:sub(-1) ~= "/" then
    parent = parent .. "/"
  end
  self:set_input(parent)
  self:refresh()
end

function M:close()
  vim.cmd("stopinsert")
  pcall(vim.api.nvim_win_close, self.input_win, true)
  pcall(vim.api.nvim_win_close, self.result_win, true)
  pcall(vim.api.nvim_buf_delete, self.input_buf, { force = true })
  pcall(vim.api.nvim_buf_delete, self.result_buf, { force = true })
end

return M
