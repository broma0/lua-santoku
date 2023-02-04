-- TODO: Add asserts

local lfs = require("lfs")

local compat = require("santoku.compat")
local str = require("santoku.string")
local err = require("santoku.err")
local gen = require("santoku.gen")
local vec = require("santoku.vector")

local M = {}

M.mkdirp = function (dir)
  local p0 = nil
  for p1 in dir:gmatch("([^" .. str.escape(M.pathdelim) .. "]+)/?") do
    if p0 then
      p1 = M.join(p0, p1)
    end
    p0 = p1
    local ok, err, code = lfs.mkdir(p1)
    if not ok and code ~= 17 then
      return ok, err, code
    end
  end
  return true
end

M.exists = function (fp)
  local mode, err, code = lfs.attributes(fp, "mode")
  if mode == nil and code == 2 then
    return true, false
  elseif mode ~= nil then
    return true, true
  else
    return false, err, code
  end
end

M.dir = function (dir)
  local ok, entries, state = pcall(lfs.dir, dir)
  if not ok then
    return false, entries, state
  else
    return true, gen.iter(function ()
      return entries(state)
    end)
  end
end

-- TODO: Breadth vs depth, default to depth so
-- that directory contents are returned before
-- directories themselves
-- TODO: Reverse arg order, allow multiple dirs
M.walk = function (dir, opts)

  local prune = (opts or {}).prune or compat.const(false)
  local prunekeep = (opts or {}).prunekeep or false
  local leaves = (opts or {}).leaves or false

  local ok = true
  local state = "init"
  local parent, parents, children
  local it, mode, err, cd

  return gen(function (gen)
    if state == "init" then
      ok, parents, cd = M.dir(dir)
      if not ok then
        state = "done"
        return gen:yield(false, parents, cd)
      else
        state = "parents"
        return gen:step()
      end
    elseif state == "parents" then
      if parents:step() then
        return parents.vals:span(function (it)
          if it ~= M.dirparent and it ~= M.dirthis then
            parent = M.join(dir, it)
            mode, err, cd = lfs.attributes(parent, "mode")
            if not mode then
              return gen:yield(false, parent, err, cd)
            elseif mode == "directory" then
              if not prune(parent, mode) then
                if not leaves then
                  state = "children"
                  children = M.walk(parent, opts)
                  return gen:yield(true, parent, mode)
                else
                  state = "children"
                  children = M.walk(parent, opts)
                  return gen:step()
                end
              elseif prunekeep then
                return gen:yield(true, parent, mode)
              end
            else
              return gen:yield(true, parent, mode)
            end
          else
            return gen:step()
          end
        end)
      else
        return gen:stop()
      end
    elseif state == "children" then
      if children:step() then
        return gen:pass(children)
      elseif leaves then
        state = "parents"
        return gen:yield(true, parent, mode)
      else
        state = "parents"
        return gen:step()
      end
    end
  end)

  -- return gen(function ()
  --   if not ok then
  --     co.yield(false, entries)
  --   else
  --     while not entries:done() do
  --       local it = entries()
  --       if it ~= M.dirparent and it ~= M.dirthis then
  --         it = M.join(dir, it)
  --         local mode, err, code = lfs.attributes(it, "mode")
  --         if not mode then
  --           co.yield(false, err, code)
  --         elseif mode == "directory" then
  --           if not prune(it, mode) then
  --             if not leaves then
  --               co.yield(true, it, mode)
  --               for ok0, it0, mode0 in M.walk(it, opts) do
  --                 co.yield(ok0, it0, mode0)
  --               end
  --             else
  --               for ok0, it0, mode0 in M.walk(it, opts) do
  --                 co.yield(ok0, it0, mode0)
  --               end
  --               co.yield(true, it, mode)
  --             end
  --           elseif prunekeep then
  --             co.yield(true, it, mode)
  --           end
  --         else
  --           co.yield(true, it, mode)
  --         end
  --       end
  --     end
  --   end
  -- end)

end

-- TODO: Avoid pcall by using io.open/read
-- directly. Potentially use __gc on the
-- coroutine to ensure the file gets closed.
-- Provide binary t/f, chunk size, max line
-- size, max file size, how to handle overunning
-- max line size, etc.
-- TODO: Need a way to abort this iterator and close the file
M.lines = function (fp)
  local ok, lines, cd = pcall(io.lines, fp)
  if not ok then
    return false, lines, cd
  else
    return true, gen.iter(lines)
  end
end

-- TODO: Reverse arg order, allow multiple dirs
M.files = function (dir, opts)
  local recurse = (opts or {}).recurse
  local walkopts = {}
  if not recurse then
    walkopts.prune = function (_, mode)
      return mode == "directory"
    end
  end
  return M.walk(dir, walkopts)
    :filter(function (ok, _, mode)
      return not ok or mode == "file"
    end)
end

-- TODO: Reverse arg order, allow multiple dirs
M.dirs = function (dir, opts)
  local recurse = (opts or {}).recurse
  local leaves = (opts or {}).leaves
  local walkopts = { prunekeep = true, leaves = leaves }
  if not recurse then
    walkopts.prune = function (_, mode)
      return mode == "directory"
    end
  end
  return M.walk(dir, walkopts)
    :filter(function (ok, _, mode)
      return not ok or mode == "directory"
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
  if not fp:match(str.escape(M.pathdelim)) then
    return fp
  else
    local parts = str.split(fp, M.pathdelim)
    return parts[parts.n]
  end
end

M.dirname = function (fp)
  local parts = str.split(fp, M.pathdelim, { delim = "left" })
  local dir = table.concat(parts, "", 1, parts.n - 1):gsub("/$", "")
  if dir == "" then
    return "."
  else
    return dir
  end
end

M.join = function (...)
  return M.joinwith(M.pathdelim, ...)
end

-- TODO: Remove . and ..
M.joinwith = function (d, ...)
  local de = str.escape(d)
  local pat = string.format("(%s)*$", de)
  return vec(...)
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

M.splitparts = function (fp, opts)
  return str.split(fp, M.pathdelim, opts)
end

-- TODO: Can probably improve performance by not
-- splitting so much. Perhaps we need an isplit
-- function that just returns indices?
M.splitexts = function (fp)
  local parts = M.splitparts(fp, { delim = "left" })
  local last = str.split(parts[parts.n], "%.", { delim = "right" })
  local lasti = 1
  if last[1] == "" then
    lasti = 2
  end
  return {
    exts = last:slice(lasti + 1),
    name = table.concat(parts, "", 1, parts.n - 1)
        .. table.concat(last, "", lasti, 1)
  }
end

-- TODO: Can we leverage a generalized function
-- for this?
M.writefile = function (fp, str, flag)
  flag = flag or "w"
  assert(type(flag) == "string")
  local fh, err = io.open(fp, flag)
  if not fh then
    return false, err
  else
    fh:write(str)
    return true
  end
end

-- TODO: Leverage fs.chunks or fs.parse
M.readfile = function (fp, flag)
  flag = flag or "r"
  assert(type(flag) == "string")
  local fh, err = io.open(fp, flag)
  if not fh then
    return false, err
  else
    local content = fh:read("*all")
    fh:close()
    return true, content
  end
end

M.rmdir = function (dir)
  local ok, err, code = lfs.rmdir(dir)
  if ok == nil then
    return false, err, code
  else
    return true
  end
end

M.rmdirs = function (dir)
  return err.pwrap(function (check)
   return M.dirs(dir, { recurse = true, leaves = true })
      :map(check)
      :map(M.rmdir)
      :each(check)
  end)
end

M.cwd = function ()
  local dir, err, cd = lfs.currentdir()
  if not dir then
    return false, err, cd
  else
    return true, dir
  end
end

M.absolute = function (fp)
  assert(type(fp) == "string")
  if fp[1] == M.pathroot then
    return M.normalize(fp)
  elseif fp:sub(1, 2) == "~/" then
    local home = os.getenv("HOME")
    if not home then
      return false, "No home directory"
    else
      fp = M.join(home, fp:sub(2))
    end
  else
    local ok, dir, cd = M.cwd()
    if not ok then
      return false, dir, cd
    else
      fp = M.join(dir, fp)
    end
  end
  return M.normalize(fp)
end

M.normalize = function (fp)
  assert(type(fp) == "string")
  fp = fp:match("^/*(.*)$")
  local parts = str.split(fp, M.pathdelim)
  local parts0 = vec()
  for i = 1, parts.n do
    if parts0.n == 0 and parts[i] == ".." then
      return false, "Can't move past root with '..'"
    elseif parts[i] == ".." then
      parts0:pop()
    elseif parts[i] ~= "." and parts[i] ~= "" then
      parts0:append(parts[i])
    end
  end
  fp = M.join(parts0:unpack())
  if fp == "" then
    return true, "."
  else
    return true, M.pathroot .. fp
  end
end

return M
