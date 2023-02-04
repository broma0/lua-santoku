local arglist = function (n)
  local args = {}
  for i = 1, n do
    args[i] = "arg" .. i
  end
  return table.concat(args, ", ")
end

local tuple = {}

return function (...)
  local m = select("#", ...)
  if m == 0 then
    return function (...) return ... end, 0
  elseif not tuple[m] then
    local args = arglist(m)
    tuple[m] = loadstring(table.concat({[[
      return function (]], args, [[)
        return function (...)
          return select(n or 1, ]], args, [[, ...)
        end, ]], m, [[
      end
    ]]}))()
  end
  return tuple[m](...)
end
