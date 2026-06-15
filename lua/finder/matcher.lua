local M = {}

function M.match(items, query)
  if not query or query == "" then return items end

  local names = {}
  local name_to_idx = {}
  for i, item in ipairs(items) do
    table.insert(names, item.name)
    name_to_idx[item.name] = i
  end

  local ok, result = pcall(vim.fn.matchfuzzypos, names, query)
  if not ok or not result or not result[1] or #result[1] == 0 then return {} end

  local match_names = result[1]
  local match_positions = result[2]

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

return M
