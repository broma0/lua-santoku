local fs = require("lfs")
local utils = require("santoku.utils")
local str = require("santoku.string")
local gen = require("santoku.gen")

local M = {}

M.mkdirp = function (dir)
  local p0 = nil
  for p1 in dir:gmatch("([^" .. str.escape(M.pathdelim) .. "]+)/?") do
    if p0 then
      p1 = M.join(p0, p1)
    end
    p0 = p1
    local ok, err, code = fs.mkdir(p1)
    if not ok and code ~= 17 then
      return ok, err, code
    end
  end
  return true
end

M.exists = function (fp)
  local mode, err, code = fs.attributes(fp, "mode")
  if mode == nil and code == 2 then
    return true, false
  elseif mode ~= nil then
    return true, true
  else
    return false, err, code
  end
end

M.dir = function (dir)
  local ok, entries, state = pcall(fs.dir, dir)
  if not ok then
    return false, entries, state
  else
    return true, gen.genco(function (co)
      while true do
        local ent = entries(state)
        if ent == nil then
          break
        else
          co.yield(ent)
        end
      end
    end)
  end
end

-- TODO: Breadth vs depth, default to depth so
-- that directory contents are returned before
-- directories themselves
M.walk = function (dir, opts)
  local prune = (opts or {}).prune or utils.const(false)
  local prunekeep = (opts or {}).prunekeep or false
  return gen.genco(function (co)
    local ok, entries = M.dir(dir)
    if not ok then
      co.yield(false, entries)
    else
      for it in entries do
        if it ~= M.dirparent and it ~= M.dirthis then
          it = M.join(dir, it)
          local attr, err, code = fs.attributes(it)
          if not attr then
            co.yield(false, err, code)
          elseif attr.mode == "directory" then
            if not prune(it, attr) then
              co.yield(true, it, attr)
              for ok0, it0, attr0 in M.walk(it, opts) do
                co.yield(ok0, it0, attr0)
              end
            elseif prunekeep then
              co.yield(true, it, attr)
            end
          else
            co.yield(true, it, attr)
          end
        end
      end
    end
  end)
end

-- TODO: Avoid pcall by using io.open/read
-- directly. Potentially use __gc on the
-- coroutine to ensure the file gets closed.
-- Provide binary t/f, chunk size, max line
-- size, max file size, how to handle overunning
-- max line size, etc.
-- TODO: Need a way to abort this iterator and close the file
M.lines = function (fp)
  local ok, iter, cd = pcall(io.lines, fp)
  if ok then
    return true, gen.gennil(iter)
  else
    return false, iter, cd
  end
end

M.files = function (dir, opts)
  local recurse = (opts or {}).recurse
  local walkopts = {}
  if not recurse then
    walkopts.prune = function (_, attr)
      return attr.mode == "directory"
    end
  end
  return M.walk(dir, walkopts)
end

M.dirs = function (dir, opts)
  local recurse = (opts or {}).recurse
  local walkopts = { prunekeep = true }
  if not recurse then
    walkopts.prune = function (_, attr)
      return attr.mode == "directory"
    end
  end
  return M.walk(dir, walkopts)
    :filter(function (ok, _, attr)
      return not ok or attr.mode == "directory"
    end)
end

-- TODO: Dynamically figure this out for each OS.
-- TODO: Does every OS have a singe-char path delim? If not,
-- some functions below will fail.
-- TODO: Does every OS use the same identifier as both
-- delimiter and root indicator?
M.pathdelim = "/"
M.pathroot = "/"
M.dirparent = ".."
M.dirthis = "."

M.basename = function (fp)
  if not string.match(fp, str.escape(M.pathdelim)) then
    return fp
  else
    local parts = str.split(fp, M.pathdelim):collect()
    return parts[#parts]
  end
end

M.dirname = function (fp)
  local parts = str.split(fp, M.pathdelim, { delim = "left" }):collect()
  local dir = table.concat(parts, "", 1, #parts - 1):gsub("/$", "")
  if dir == "" then
    return "."
  else
    return dir
  end
end

M.join = function (...)
  return M.joinwith(M.pathdelim, ...)
end

M.joinwith = function (d, ...)
  local de = str.escape(d)
  local pat = string.format("(%s)*$", de)
  return gen.args(...)
    :filter()
    :reduce(function (a, n)
      return table.concat({
        -- Need these parens to ensure only the first return
        -- value of gsub used in concat
        (a:gsub(pat, "")),
        (n:gsub(pat, ""))
      }, d)
    end)
end

M.splitexts = function (fp)
  local parts = str.split(fp, M.pathdelim, { delim = "left" }):collect()
  local last = str.split(parts[#parts], "%.", { delim = "right" }):collect()
  if last[1] == "" then
    last = gen.ivals(last):slice(2):collect()
  end
  return {
    exts = gen.vals(last):slice(2):collect(),
    name = table.concat(gen.chain(
      gen.ivals(parts):slice(0, #parts - 1),
      gen.ivals(last):slice(0, 1))
        :collect())
  }
end

return M
