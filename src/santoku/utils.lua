-- TODO: Some of these should be split into
-- a "common" module for brodly required
-- functions
-- TODO: mergeWith, deep merge, etc, walk a
-- table

-- TODO: Leverage this library more fully in the
-- other modules (compose, narg, etc.)

local tup = require("santoku.tuple")

local M = {}

-- This is effectively a curry/bind function
-- that also allows for argument re-ordering
--
-- TODO: Figure out the arglist before returning
-- the new function instead of re-computing the
-- arglist for every function call. Do the same
-- with nret below.
M.narg = function (...)
  local idx = tup(...)
  return function (fn, ...)
    local bound = tup(...)
    return function (...)
      local args0 = bound:append(...)
      local pick
      args0, pick = args0:pick(idx())
      return fn(pick:append(args0())())
    end
  end
end

-- TODO: Could an index of 0 mean something
-- useful?
M.nret = function (...)
  local idx = tup(...)
  return function (...)
    local args = tup(...)
    local rets = tup()
    for i = 1, idx:len() do
      local nret = select(select(i, idx()), args())
      rets = rets:append(nret)
    end
    return rets()
  end
end

M.compose = function (...)
  local fns = tup(...)
  return function(...)
    local vs = tup(...)
    for i = fns:len(), 1, -1 do
      local fn = select(i, fns())
      assert(type(fn) == "function")
      vs = tup(fn(vs()))
    end
    return vs()
  end
end

M.id = function (...)
  return ...
end

M.const = function (...)
  local args = tup(...)
  return function ()
    return args()
  end
end

M.interpreter = function (args)
  local arg = arg or {}
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

-- TODO: allow composition
-- TODO: allow setting a nested value that
-- doesnt exist
M.lens = function (...)
  local keys = tup(...)
  return function (fn)
    fn = fn or M.id
    return function(t)
      if keys:len() == 0 then
        return t, fn(t)
      else
        local t0 = t
        for i = 1, keys:len() - 1 do
          if t0 == nil then
            return t
          end
          t0 = t0[select(i, keys())]
        end
        local val = fn(t0[select(keys:len(), keys())])
        t0[select(keys:len(), keys())] = val
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
  local keys = tup(...)
  return function (v)
    return M.lens(keys())(M.const(v))
  end
end

M.set = function (t, k, v)
  return (M.setter(k)(v)(t))
end

M.dset = function (t, v, ...)
  return M.setter(...)(v)(t)
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
  for k in pairs(t0) do
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
  end
  return t0
end

M.appender = function (...)
  local args = tup(...)
  return function (a)
    return M.extend(a, { args() })
  end
end

M.append = function (a, ...)
  return M.appender(...)(a)
end

return M
