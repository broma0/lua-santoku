-- TODO: Leverage "inherit" to set __index
-- TODO: Avoid pack(...)
-- TODO: Consider overloading operators for generators
-- TODO: We should not assign all of M to the
-- generators, instead, only assign gen-related
-- functions
-- TODO: genco and gennil arent great
-- user-facing APIs for creating iterators
-- TODO: Need an gen:abort() function to early
-- exit iterators that allows for cleanup
-- TODO: Add asserts to all 'er' functions and
-- the non-'er' functions that don't immediately
-- call the 'er' functions
-- TODO: Do we really want the GEN_TAG thing for
-- asserts? It's a bit ugly

local utils = require("santoku.utils")
local co = require("santoku.co")

local GEN_TAG = {}

local M = {}

-- TODO: Allow the user to provide an error
-- function, default it to error and ensure only
-- one value is passed
M.genco = function (fn, ...)
  assert(type(fn) == "function")
  local co = co.make()
  local cor = co.create(fn)
  local val, n = utils.tuple(co.resume(cor, co, ...))
  if not (select(1, val())) then
    error((select(2, val())))
  end
  local gen = {
    tag = GEN_TAG,
    done = function ()
      return co.status(cor) == "dead"
    end
  }
  return setmetatable(gen, {
    __index = M,
    __call = function (...)
      if gen:done() then
        return nil
      end
      local nval = utils.tuple(co.resume(cor, ...))
      if not (select(1, nval())) then
        error((select(2, nval())))
      else
        local ret = val
        val = nval
        return select(2, ret())
      end
    end
  })
end

M.gennil = function (fn, ...)
  assert(type(fn) == "function")
  local val = utils.tuple(fn(...))
  local gen = {
    tag = GEN_TAG,
    done = function ()
      return val() == nil
    end
  }
  return setmetatable(gen, {
    __index = M,
    __call = function (...)
      if gen:done() then
        return nil
      end
      local nval = utils.tuple(fn(...))
      local ret = val
      val = nval
      return ret()
    end
  })
end

M.ipairs = function(t)
  assert(type(t) == "table")
  return M.genco(function (co)
    for k, v in ipairs(t) do
      co.yield(k, v)
    end
  end)
end

M.pairs = function(t)
  assert(type(t) == "table")
  return M.genco(function (co)
    for k, v in pairs(t) do
      co.yield(k, v)
    end
  end)
end

M.args = function (...)
  local args, n = utils.tuple(...)
  return M.genco(function (co)
    for i = 1, n do
      co.yield((select(i, args())))
    end
  end)
end

M.vals = function (t)
  assert(type(t) == "table")
  return M.pairs(t):map(utils.nret(2))
end

M.keys = function (t)
  assert(type(t) == "table")
  return M.pairs(t):map(utils.nret(1))
end

M.ivals = function (t)
  assert(type(t) == "table")
  return M.ipairs(t):map(utils.nret(2))
end

M.ikeys = function (t)
  assert(type(t) == "table")
  return M.ipairs(t):map(utils.nret(1))
end

M.caller = function (...)
  local args = utils.pack(...)
  return function (f)
    assert(type(f) == "function")
    return f(utils.unpack(args))
  end
end

M.call = function (f, ...)
  assert(type(f) == "function")
  return M.caller(...)(f)
end

M.matcher = function (pat)
  assert(type(pat) == "string")
  return function (str)
    assert(type(str) == "string")
    return M.gennil(str:gmatch(pat))
  end
end

M.match = function (str, pat)
  assert(type(str) == "string")
  assert(type(pat) == "string")
  return M.matcher(pat)(str)
end

M.reducer = function (acc, ...)
  assert(type(acc) == "function")
  local val, n = utils.tuple(...)
  return function (gen)
    assert(type(gen) == "table")
    assert(gen.tag == GEN_TAG)
    if gen:done() then
      return val()
    elseif n == 0 then
      val = utils.tuple(gen())
    end
    while not gen:done() do
      val = utils.tuples(val, utils.tuple(gen()))
      val = utils.tuple(acc(val()))
    end
    return val()
  end
end

M.reduce = function (gen, acc, ...)
  return M.reducer(acc, ...)(gen)
end

M.taker = function (n)
  assert(n == nil or type(n) == "number")
  return function (gen)
    assert(type(gen) == "table")
    assert(gen.tag == GEN_TAG)
    if n == nil then
      return gen
    else
      return M.genco(function (co)
        while n > 0 and not gen:done() do
          co.yield(gen())
          n = n - 1
        end
      end)
    end
  end
end

M.take = function (gen, n)
  return M.taker(n)(gen)
end

M.max = function (gen, def)
  return M.reduce(gen, function(a, b)
    if a > b then
      return a
    else
      return b
    end
  end, def)
end

M.flatten = function (gengen)
  assert(type(gengen) == "table")
  assert(gengen.tag == GEN_TAG)
  return M.genco(function (co)
    while not gengen:done() do
      local gen = gengen()
      while not gen:done() do
        co.yield(gen())
      end
    end
  end)
end

-- TODO: Need some tests to define nil handing
-- behavior
M.collect = function (gen)
  return M.reduce(gen, function (a, ...)
    if select("#", ...) <= 1 then
      return utils.append(a, ...)
    else
      -- NOTE: Design decision here: it might
      -- technically make more sense to provide
      -- vals here (a utils.pack() of the
      -- arguments, however in most uses users
      -- will expect zip to return a list of
      -- lists)
      return utils.append(a, { ... })
    end
  end, {})
end

M.filterer = function (fn, ...)
  fn = fn or utils.id
  assert(type(fn) == "function")
  local args = utils.tuple(...)
  return function (gen)
    return M.genco(function (co)
      while not gen:done() do
        local val = utils.tuple(gen())
        local allargs = utils.tuples(val, args)
        if fn(allargs()) then
          co.yield(val())
        end
      end
    end)
  end
end

M.filter = function (gen, fn, ...)
  return M.filterer(fn, ...)(gen)
end

M.mapper = function (fn, ...)
  fn = fn or utils.id
  local args, n = utils.tuple(...)
  return function (gen)
    return M.genco(function (co)
      while not gen:done() do
        local vals = utils.tuple(gen())
        local allargs = utils.tuples(args, vals)
        co.yield(fn(allargs()))
      end
    end)
  end
end

M.map = function (gen, fn, ...)
  return M.mapper(fn, ...)(gen)
end

M.each = function (gen, fn)
  while not gen:done() do
    fn(gen())
  end
end

-- opts.mode defaults to "first"
-- opts.mode == "first" for stopping when first
--   generator ends
-- opts.mode == "longest" for stopping when
--   longest generator ends
-- opts.mode == "shortest" for stopping when
--   shortest generator ends
-- opts.mode == N for stopping after N iterations
-- invalid mode treated as "longest"
M.zipper = function (opts)
  local fn = (opts or {}).fn or utils.id
  local mode = (opts or {}).mode or "first"
  return function (...)
    local gens, ngens = utils.tuple(...)
    local nb = 0
    return M.genco(function (co)
      while true do
        local vals = utils.tuple()
        local nils = 0
        for i = 1, ngens do
          local gen = select(i, gens())
          if gen:done() then
            vals = utils.tuples(vals, utils.tuple(nil))
            nils = nils + 1
            if mode == "first" then
              return
            end
          else
            vals = utils.tuples(vals, utils.tuple(gen()))
          end
        end
        nb = nb + 1
        if type(mode) == "number" and nb > mode then
          break
        elseif mode == "shortest" and nils > 0 then
          break
        elseif ngens == nils then
          break
        else
          co.yield(fn(vals()))
        end
      end
    end)
  end
end

M.zip = function (...)
  return M.zipper()(...)
end

-- TODO: This name sucks
M.aller = function (fn, ...)
  fn = fn or utils.id
  local args = utils.tuple(...)
  return function (gen)
    return M.reduce(gen, function (a, ...)
      local args2 = utils.tuple(...)
      local allargs = utils.tuples(args, args2)
      return a and fn(allargs())
    end)
  end
end

M.all = function (gen, ...)
  return M.aller(...)(gen)
end

M.tabulator = function (keys, opts)
  local rest = (opts or {}).rest
  return function (genVals)
    local t = M.ivals(keys)
      :zip(genVals)
      :reduce(function (a, k, v)
        a[k] = v
        return a
      end, {})
    if rest then
      t[rest] = genVals:collect()
    end
    return t
  end
end

M.tabulate = function (gen, keys, opts)
  return M.tabulator(keys, opts)(gen)
end

M.finder = function (...)
  local args = utils.tuple(...)
  return function (gen)
    return gen:filter(args()):head()
  end
end

M.find = function (gen, ...)
  return M.finder(...)(gen)
end

M.chain = function (...)
  local gens = M.args(...)
  return M.genco(function (co)
    gens:each(function (gen)
      gen:each(co.yield)
    end)
  end)
end

M.equals = function (...)
  return M.zipper({
    fn = function (a, ...)
      local rest, n = utils.tuple(...)
      for i = 1, n do
        if a ~= (select(i, rest())) then
          return false
        end
      end
      return true
    end,
    mode = "longest"
  })(...):all()
end

-- Split a string
--   opts.delim == false: throw out delimiters
--   opts.delim == true: keep delimiters as
--     separate tokens
--   opts.delim == "left": keep delimiters
--     concatenated to the left token
--   opts.delim == "right": keep delimiters
--     concatenated to the right token
--
-- TODO: allow splitting specific number of times from left or
-- right
--   opts.times: default == true
--   opts.times == true: as many as possible from left
--   opts.times == false: as many times as possible from right
--   opts.times > 0: number of times, starting from left
--   opts.times < 0: number of times, starting from right
M.splitter = function (pat, opts)
  opts = opts or {}
  local delim = opts.delim or false
  return function (str)
    return M.genco(function (co)
      local n = 0
      local ls = 0
      local stop = false
      while not stop do
        local s, e = str:find(pat, n)
        stop = s == nil
        if stop then
          s = #str + 1
        end
        if delim == true then
          co.yield(str:sub(n, s - 1))
          if not stop then
            co.yield(str:sub(s, e))
          end
        elseif delim == "left" then
          co.yield(str:sub(n, e))
        elseif delim == "right" then
          co.yield(str:sub(ls, s - 1))
        else
          co.yield(str:sub(n, s - 1))
        end
        if stop then
          break
        else
          ls = s
          n = e + 1
        end
      end
    end)
  end
end

M.split = function (str, pat, opts)
  return M.splitter(pat, opts)(str)
end

M.slicer = function (start, num)
  start = start or 1
  return function (gen)
    gen:take(start - 1):collect()
    return gen:take(num)
  end
end

M.slice = function (gen, start, num)
  return M.slicer(start, num)(gen)
end

M.head = function (gen)
  return gen()
end

M.tail = function (gen)
  gen()
  return gen
end

M.picker = function (n)
  return function (gen)
    return gen:slice(n, 1):head()
  end
end

M.pick = function (gen, n)
  return M.picker(n, gen)
end

-- TODO: Where should this be?
-- TODO: Should we silently drop nil args?
-- Should we assert?
M.compose = function (...)
  return M.args(...)
    :reduce(function(f, g)
      return function(...)
        return f(g(...))
      end
    end)
end

return M
