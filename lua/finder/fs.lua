local uv = uv or vim.loop
local M = {}

function M.expand(path)
  if not path or path == "" then return path end
  if path:sub(1, 1) == "~" then
    local home = vim.fn.expand("~")
    if home then
      if path == "~" then return home end
      return home .. path:sub(2)
    end
  end
  return path
end

function M.contract(path)
  local home = vim.fn.expand("~")
  if home and path:sub(1, #home) == home then
    if path == home then return "~" end
    return "~" .. path:sub(#home + 1)
  end
  return path
end

function M.parent(path)
  if path == "" or path == "/" then return path end
  local p = path:gsub("/+$", "")
  if p == "" then return "/" end
  local parent = p:match("^(.*/).*$")
  return parent or ""
end

function M.basename(path)
  local p = path:gsub("/+$", "")
  return p:match("^.*/(.+)$") or p
end

function M.is_dir(path)
  if not path or path == "" then return false end
  local stat = uv.fs_stat(path)
  return stat and stat.type == "directory" or false
end

function M.list(dir, mode)
  local expanded = M.expand(dir)
  if not expanded or expanded == "" then return {} end
  if expanded:sub(-1) ~= "/" then expanded = expanded .. "/" end

  local items = {}
  local ok, handle = pcall(uv.fs_scandir, expanded)
  if not ok or not handle then return items end

  while true do
    local name, type = uv.fs_scandir_next(handle)
    if not name then break end

    local is_dir = type == "directory"
    local is_file = type == "file"

    if mode == "dir" and not is_dir then goto continue end
    if mode == "file" and not is_file then goto continue end

    table.insert(items, {
      name = name,
      is_dir = is_dir,
    })

    ::continue::
  end

  table.sort(items, function(a, b)
    if a.is_dir ~= b.is_dir then return a.is_dir end
    return a.name:lower() < b.name:lower()
  end)

  return items
end

return M
