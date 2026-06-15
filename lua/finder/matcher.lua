local M = {}

function M.match(items, query)
  if not query or query == "" then return items end

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

  local names = vim.tbl_map(function(item) return item.name end, filtered)
  local ok, result = pcall(vim.fn.matchfuzzypos, names, query)
  if not ok or not result or not result[1] or #result[1] == 0 then return {} end

  local match_names = result[1]
  local match_positions = result[2]

  local matched = {}
  for i, name in ipairs(match_names) do
    local idx = name_to_idx[name]
    if idx then
      local item = filtered[idx]
      table.insert(matched, {
        name = item.name,
        is_dir = item.is_dir,
        match_positions = match_positions[i],
      })
    end
  end
  return matched
end

return M
