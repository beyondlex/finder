local M = {}

local function fuzzy_order(items, query)
  local names = vim.tbl_map(function(item) return item.name end, items)
  local ok, result = pcall(vim.fn.matchfuzzypos, names, query:lower())
  if not ok or not result or not result[1] or #result[1] == 0 then return items end

  local match_names = result[1]
  local match_positions = result[2]

  local name_to_idx = {}
  for i, item in ipairs(items) do
    name_to_idx[item.name] = i
  end

  local matched = {}
  for i, name in ipairs(match_names) do
    local idx = name_to_idx[name]
    if idx then
      local item = items[idx]
      table.insert(matched, {
        name = item.name,
        is_dir = item.is_dir,
        match_positions = match_positions[i],
      })
    end
  end
  return matched
end

function M.match(items, query)
  if not query or query == "" then return items end

  -- * prefix: match substring anywhere in the name
  if query:sub(1, 1) == "*" then
    local sub = query:sub(2)
    if sub == "" then return items end

    local filtered = {}
    for _, item in ipairs(items) do
      if item.name:lower():find(sub:lower(), 1, true) then
        table.insert(filtered, item)
      end
    end

    if #filtered == 0 then return {} end
    return fuzzy_order(filtered, sub)
  end

  -- Default: first-char prefix filter + fuzzy
  local first = query:sub(1, 1)

  local filtered = {}
  local name_to_idx = {}
  for i, item in ipairs(items) do
    if item.name:sub(1, 1):lower() == first:lower() then
      table.insert(filtered, item)
      name_to_idx[item.name] = #filtered
    end
  end

  if #filtered == 0 then return {} end
  if #query == 1 then return filtered end

  return fuzzy_order(filtered, query)
end

return M
