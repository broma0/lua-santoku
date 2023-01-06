-- TODO: Some of these should be split into
-- a "common" module for brodly required
-- functions
-- TODO: I'm thinking we should switch the
-- library to use select instead of pack
-- directly: no pack, just use gen.args(...)
-- TODO: mergeWith, deep merge, etc, walk a
-- table

local M = {}

M.unpack = unpack or table.unpack

M.tuple = function (...)
  local n = select('#', ...)
  if n == 0 then
    return function() end, 0
  else
    return M.tupleh(nil, 0, n, ...), n
  end
end

-- TODO: Generalize to accept N tuples
M.tuples = function (a, b)
  local nxt, nnxt = M.tupleh(nil, 0, select("#", b()), b())
  local ret, nret = M.tupleh(nxt, nnxt, select("#", a()), a())
  return ret, nret
end

M.tupleh = function (nxt, m, n, first, ...)
  if n == 0 then
    nxt = nxt or function () end
    return function ()
      return nxt()
    end, m
  elseif n == 1 then
    nxt = nxt or function () end
    return function()
      return first, nxt()
    end, m + 1
  else
    local rest, m = M.tupleh(nxt, m, n - 1, ...)
    return function()
      return first, rest()
    end, m + 1
  end
end

M.id = function (...)
  return ...
end

M.const = function (...)
  local val = M.tuple(...)
  return function ()
    return val()
  end
end

M.narg = function (...)
  local idx, n = M.tuple(...)
  return function (fn)
    return function (...)
      local args0 = M.tuple(...)
      local args1 = {}
      local ridx = 0
      for i = 1, n do
        ridx = ridx + 1
        args1[ridx] = select(select(i, idx()), args0())
      end
      return fn(M.unpack(args1))
    end
  end
end

M.nret = function (...)
  local idx, n = M.tuple(...)
  return function (...)
    local args = M.tuple(...)
    local rets = {}
    local ridx = 0
    for i = 1, n do
      ridx = ridx + 1
      rets[ridx] = select(select(i, idx()), args())
    end
    return M.unpack(rets, 1, ridx)
  end
end

M.interpreter = function (args)
  arg = arg or {}
  local i_min = 0
  while arg[i_min] do
    i_min = i_min - 1
  end
  i_min = i_min + 1
  local ret = {}
  for i = i_min, 0 do
    table.insert(ret, arg[i])
  end
  if args then
    for i = 1, #arg do
      table.insert(ret, arg[i])
    end
  end
  return ret
end

-- TODO: simplify with recursion
-- TODO: Should we silently drop nil args?
M.compose = function (...)
  local fns, n = M.tuple(...)
  return function(...)
    local vs = M.tuple(...)
    for i = n, 1, -1 do
      local fn = select(i, fns())
      assert(type(fn) == "function")
      vs = M.tuple(fn(vs()))
    end
    return vs()
  end
end

-- TODO: allow composition
-- TODO: allow setting a nested value that
-- doesnt exist
M.lens = function (...)
  local keys, n = M.tuple(...)
  return function (fn)
    fn = fn or M.id
    return function(t)
      if n == 0 then
        return t, fn(t)
      else
        local t0 = t
        for i = 1, n - 1 do
          if t0 == nil then
            return t, nil
          end
          t0 = t0[select(i, keys())]
        end
        local val = fn(t0[select(n, keys())])
        t0[select(n, keys())] = val
        return t, val
      end
    end
  end
end

M.getter = function (...)
  return M.compose(M.nret(2), M.lens(...)())
end

M.get = function (t, ...)
  return M.getter(...)(t)
end

M.setter = function (...)
  local keys = M.tuple(...)
  return function (v)
    return M.lens(keys())(M.const(v))
  end
end

M.set = function (t, val, ...)
  return M.setter(...)(val)(t)
end

M.maybe = function (a, f, g)
  f = f or M.id
  g = g or M.const(a)
  if a then
    return f(a)
  else
    return g()
  end
end

M.choose = function (a, b, c)
  if a then
    return b
  else
    return c
  end
end

M.assign = function (t0, ...)
  for i = 1, select("#", ...) do
    local t1 = select(i, ...)
    for k, v in pairs(t1) do
      t0[k] = v
    end
  end
  return t0
end

-- TODO: There MUST be a better way to do this,
-- but neither ipairs nor 'i = 0, #t' can manage
-- to handle both leading nils and intermixed
-- nils as expected.
M.extend = function (t0, ...)
  local n = 0
  for k, v in pairs(t0) do
    assert(type(k) == "number")
    if k > n then
      n = k
    end
  end
  for i = 1, select("#", ...) do
    local t1 = select(i, ...)
    local m = 0
    for k, v in pairs(t1) do
      if type(k) == "number" then
        if k > m then
          m = k
        end
        t0[k + n] = v
      end
    end
    n = n + m
    m = 0
  end
  return t0
end

M.appender = function (...)
  local args = M.tuple(...)
  return function (a)
    return M.extend(a, { args() })
  end
end

M.append = function (a, ...)
  return M.appender(...)(a)
end

return M
