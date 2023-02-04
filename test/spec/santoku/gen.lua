-- TODO: Confirm that return values are
-- correctly vectors when they should be vectors

-- TODO: Seems to be an infinite loop with
-- each:flatten, perhaps because each returns a
-- generator when it shouldnt?

local gen = require("santoku.gen")
local vec = require("santoku.vector")

describe("santoku.gen", function ()

  describe("gen", function ()

    it("should create a generator", function ()

      local vals = gen(function (yield)
        yield(1)
        yield(2)
      end)

      local called = 0
      vals:index():each(function (idx, i)
        called = called + 1
        assert(idx == i)
      end)

      assert(called == 2)

    end)

    it("shouldnt call the callback if empty", function ()

      local vals = gen()

      local called = 0

      vals:each(function ()
        called = called + 1
      end)

      assert(called == 0)

    end)

  end)

  describe("vec", function ()

    it("collects generator returns into a vec", function ()

      local vals = gen(function (yield)
        yield(1, 2, 3)
        yield(4, 5, 6)
      end):vec()

      local expected = vec(vec(1, 2, 3), vec(4, 5, 6))

      assert.same(expected, vals)

    end)

  end)

  describe("args", function ()

    it("iterates over arguments", function ()

      local v = gen.args(1, 2, 3, 4):vec()

      assert.same(v, { 1, 2, 3, 4, n = 4 })

    end)

    it("handles arg nils", function ()

      local v = gen.args(1, nil, 2, nil, nil):vec()

      assert.same(v, { 1, nil, 2, nil, nil, n = 5 })

    end)

  end)

  describe("map", function ()

    it("maps over a generator", function ()

      local vals = gen.args(1, 2):map(function (a)
        return a * 2
      end):vec()

      assert.same(vals, { 2, 4, n = 2 })

    end)

  end)

  describe("reduce", function ()

    it("reduces a generator", function ()
      local vals = gen.args(1, 2, 3):reduce(function (a, n)
        return a + n
      end)
      assert.same(vals, 6)
    end)

  end)

  describe("filter", function ()

    it("filters a generator", function ()

      local vals = gen
        .args(1, 2, 3, 4, 5, 6)
        :filter(function (n)
          return (n % 2) == 0
        end)
        :vec()

      assert.same(vals, vec(2, 4, 6))

    end)

  end)

  describe("chunk", function ()

    it("takes n items from a generator", function ()
      local vals = gen.args(1, 2, 3):chunk(2):vec()
      assert.same(vals, vec(vec(1, 2), vec(3)))
    end)

  end)

  --describe("pairs", function ()

  --  it("iterates pairs in a table", function ()

  --    local gen = gen.pairs({ a = 1, b = 2 })
  --    local a, b

  --    a, b = gen()
  --    assert.same({ "a", 1 }, { a, b })

  --    a, b = gen()
  --    assert.same({ "b", 2 }, { a, b })

  --    assert(gen:done())

  --  end)

  --end)

  --describe("ipairs", function ()

  --  it("iterates ipairs in a table", function ()

  --    local gen = gen.ipairs({ 1, 2 })
  --    local a, b

  --    a, b = gen()
  --    assert.same({ 1, 1 }, { a, b })

  --    a, b = gen()
  --    assert.same({ 2, 2 }, { a, b })

  --    assert(gen:done())

  --  end)

  --end)

  --describe("vals", function ()

  --  it("iterates table values", function ()

  --    local gen = gen.vals({ a = 1, b = 2 })

  --    assert.equals(1, gen())
  --    assert.equals(2, gen())

  --    assert(gen:done())

  --  end)

  --end)

  --describe("keys", function ()

  --  it("iterates table keys", function ()

  --    local gen = gen.keys({ a = 1, b = 2 })

  --    assert.equals("a", gen())
  --    assert.equals("b", gen())

  --    assert(gen:done())

  --  end)

  --end)

  --describe("ivals", function ()

  --  it("drops array nils", function ()

  --    local array = {}

  --    table.insert(array, "a")
  --    table.insert(array, nil)
  --    table.insert(array, "b")
  --    table.insert(array, nil)
  --    table.insert(array, nil)
  --    table.insert(array, "c")
  --    table.insert(array, nil)

  --    local vals = gen.ivals(array)

  --    assert.equals(false, vals:done())
  --    assert.equals("a", vals())

  --    assert.equals(false, vals:done())
  --    assert.equals("b", vals())

  --    assert.equals(false, vals:done())
  --    assert.equals("c", vals())

  --    assert.equals(true, vals:done())
  --    assert.is_nil(vals())
  --    assert.is_nil(vals())
  --    assert.is_nil(vals())

  --  end)

  --  it("iterates table ivalues", function ()

  --    local gen = gen.ivals({ 1, 2, a = "b" })

  --    assert.equals(1, gen())
  --    assert.equals(2, gen())

  --    assert(gen:done())

  --  end)

  --end)

  --describe("ikeys", function ()

  --  it("iterates table keys", function ()

  --    local gen = gen.ikeys({ "a", "b", a = 12 })

  --    assert.equals(1, gen())
  --    assert.equals(2, gen())

  --    assert(gen:done())

  --  end)

  --end)

  --describe("zip", function ()

  --  it("zips generators together", function ()

  --    local gen1 = gen.args(1, 2, 3, 4)
  --    local gen2 = gen.args(1, 2, 3, 4)

  --    local gen = gen1:zip(gen2)

  --    local a, b

  --    a, b = gen()
  --    assert.same({ 1, 1 }, { a[1], b[1] })

  --    a, b = gen()
  --    assert.same({ 2, 2 }, { a[1], b[1] })

  --    a, b = gen()
  --    assert.same({ 3, 3 }, { a[1], b[1] })

  --    a, b = gen()
  --    assert.same({ 4, 4 }, { a[1], b[1] })

  --    assert.equals(true, gen1:done())
  --    assert.equals(true, gen2:done())
  --    assert.equals(true, gen:done())

  --  end)

  --end)

  --describe("each", function ()

  --  it("applies a function to each item", function ()
  --    local gen = gen.args(1, 2, 3, 4)
  --    local i = 0
  --    gen:each(function (x)
  --      i = i + 1
  --      assert.equals(i, x)
  --    end)
  --    assert(i == 4 and gen:done())
  --  end)

  --end)

  --describe("flatten", function ()

  --  it("flattens a generator of generators", function ()
  --    local gen = gen.genco(function (co)
  --      co.yield(gen.args(1, 2, 3, 4))
  --      co.yield(gen.args(5, 6, 7, 8))
  --    end):flatten()
  --    assert.equals(1, gen())
  --    assert.equals(2, gen())
  --    assert.equals(3, gen())
  --    assert.equals(4, gen())
  --    assert.equals(5, gen())
  --    assert.equals(6, gen())
  --    assert.equals(7, gen())
  --    assert.equals(8, gen())
  --    assert(gen:done())
  --  end)

  --end)

  --describe("slice", function ()

  --  it("slices the generator", function ()

  --    local gen = gen.args("file", ".txt"):slice(2)

  --    assert.equals(".txt", gen())
  --    assert.equals(true, gen:done())

  --  end)

  --end)

  --describe("tabulate", function ()

  --  it("creates a table from a generator", function ()

  --    local vals = gen.args(1, 2, 3, 4)
  --    local tbl = vals:tabulate("one", "two", "three", "four" )

  --    assert.equals(1, tbl.one)
  --    assert.equals(2, tbl.two)
  --    assert.equals(3, tbl.three)
  --    assert.equals(4, tbl.four)

  --  end)

  --  it("captures remaining values in a 'rest' property", function ()

  --    local vals = gen.args(1, 2, 3, 4)
  --    local tbl = vals:tabulate({ rest = "others" }, "one")

  --    assert.equals(1, tbl.one)
  --    assert.same({ 2, 3, 4, n = 3 }, tbl.others)

  --  end)

  --end)

  --describe("all", function ()

  --  it("reduces with and", function ()

  --    local gen1 = gen.args(true, true, true)
  --    local gen2 = gen.args(true, false, true)

  --    assert(gen1:all())
  --    assert(not gen2:all())

  --  end)

  --end)

  --describe("none", function ()

  --  it("reduces with not and", function ()

  --    local gen1 = gen.args(false, false, false)
  --    local gen2 = gen.args(true, false, true)

  --    assert(gen1:none())
  --    assert(not gen2:none())

  --  end)

  --end)

  --describe("equals", function ()

  --  it("checks if two generators have equal values", function ()

  --    local gen1 = gen.args(1, 2, 3, 4)
  --    local gen2 = gen.args(5, 6, 7, 8)

  --    assert.equals(false, gen1:equals(gen2))
  --    assert(gen1:done())
  --    assert(gen2:done())

  --  end)

  -- it("checks if two generators have equal values", function ()

  --   local gen1 = gen.args(1, 2, 3, 4)
  --   local gen2 = gen.args(1, 2, 3, 4)

  --   assert.equals(true, gen1:equals(gen2))
  --   assert(gen1:done())
  --   assert(gen2:done())

  -- end)

  -- it("checks if two generators have equal values", function ()

  --   local gen1 = gen.args(1, 2, 3, 4)

  --   -- NOTE: this might seem unexpected but
  --   -- generators are not immutable. This will
  --   -- result in comparing 1 to 2 and 3 to 4 due to
  --   -- repeated invocations of the same generator.
  --   assert.equals(false, gen1:equals(gen1))

  -- end)

  -- it("handles odd length generators", function ()

  --   local gen1 = gen.args(1, 2, 3)
  --   local gen2 = gen.args(1, 2, 3, 4)

  --   assert.equals(false, gen1:equals(gen2))
  --   assert(gen1:done())

  --   -- TODO: See the note on the implementation of
  --   -- gen:equals() for why these are commented out.
  --   --
  --   -- assert(not gen2:done())
  --   -- assert.equals(4, gen2())
  --   -- assert(gen2:done())

  -- end)

  --end)

  --describe("find", function ()

  --  it("finds by a predicate", function ()

  --    local gen = gen.args(1, 2, 3, 4)

  --    local v = gen:find(function (a) return a == 3 end)

  --    assert.equals(3, v)

  --  end)

  --end)

  --describe("pick", function ()

  --  it("picks the nth value from a generator", function ()

  --    local gen = gen.args(1, 2, 3, 4)

  --    local v = gen:pick(2)

  --    assert.equals(2, v)

  --  end)

  --end)

  --describe("chain", function ()

  --  it("chains generators", function ()

  --    local gen1 = gen.args(1, 2)
  --    local gen2 = gen.args(3, 4)
  --    local gen = gen.chain(gen1, gen2)

  --    assert.equals(1, gen())
  --    assert.equals(2, gen())
  --    assert.equals(3, gen())
  --    assert.equals(4, gen())
  --    assert(gen:done())

  --  end)

  --end)

  --describe("max", function ()

  --  it("returns the max value in a generator", function ()

  --    local gen = gen.args(1, 6, 3, 9, 2, 10, 4)

  --    local max = gen:max()

  --    assert.equals(10, max)
  --    assert(gen:done())

  --  end)

  --end)

  --describe("tail", function ()

  --  it("simply drops the first element", function ()

  --    local gen = gen.args(1, 2, 3):tail()

  --    assert.equals(2, gen())
  --    assert.equals(3, gen())
  --    assert(gen:done())

  --  end)

  --end)

end)
