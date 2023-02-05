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

  describe("iter", function ()

    it("should wrap a nil-based generator", function ()

      local it = ("this is a test"):gmatch("%w+")
      local vals = gen.iter(it):vec()

      assert.same(vec("this", "is", "a", "test"), vals)

    end)

    it("should work without callbacks", function ()

      local it = ("this is a test"):gmatch("%w+")
      gen.iter(it):each()

    end)

  end)

  describe("isgen", function ()

    it("should detect invalid generators", function ()

      assert(not gen.isgen(1))
      assert(not gen.isgen({}))
      assert(not gen.isgen(vec()))

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

  describe("pack", function ()

    it("iterates over arguments", function ()

      local v = gen.pack(1, 2, 3, 4):vec()

      assert.same(v, { 1, 2, 3, 4, n = 4 })

    end)

    it("handles arg nils", function ()

      local v = gen.pack(1, nil, 2, nil, nil):vec()

      assert.same(v, { 1, nil, 2, nil, nil, n = 5 })

    end)

  end)

  describe("map", function ()

    it("maps over a generator", function ()

      local vals = gen.pack(1, 2):map(function (a)
        return a * 2
      end):vec()

      assert.same(vals, { 2, 4, n = 2 })

    end)

  end)

  describe("reduce", function ()

    it("reduces a generator", function ()
      local vals = gen.pack(1, 2, 3):reduce(function (a, n)
        return a + n
      end)
      assert.same(vals, 6)
    end)

  end)

  describe("filter", function ()

    it("filters a generator", function ()

      local vals = gen
        .pack(1, 2, 3, 4, 5, 6)
        :filter(function (n)
          return (n % 2) == 0
        end)
        :vec()

      assert.same(vals, vec(2, 4, 6))

    end)

  end)

  describe("chunk", function ()

    it("takes n items from a generator", function ()
      local vals = gen.pack(1, 2, 3):chunk(2):tup()
      local a, b = vals()
      assert.same(a, { 1, 2, n = 2 })
      assert.same(b, { 3, n = 1 })
    end)

  end)

  describe("pairs", function ()

    it("iterates pairs in a table", function ()

      local v = gen.pairs({ a = 1, b = 2 }):vec()

      assert.same(v, vec(vec("a", 1), vec("b", 2)))

    end)

  end)

  describe("ipairs", function ()

    it("iterates ipairs in a table", function ()

      local v = gen.ipairs({ 1, 2 }):vec()
      assert.same(v, vec(vec(1, 1), vec(2, 2)))

    end)

  end)

  describe("vals", function ()

    it("iterates table values", function ()

      local v = gen.vals({ a = 1, b = 2 }):vec()
      assert.same(v, vec(1, 2))

    end)

  end)

  describe("keys", function ()

    it("iterates table keys", function ()

      local v = gen.keys({ a = 1, b = 2 }):vec()
      assert.same(v, vec("a", "b"))

    end)

  end)

  describe("ivals", function ()

    it("drops array nils", function ()

      local array = {}

      table.insert(array, "a")
      table.insert(array, nil)
      table.insert(array, "b")
      table.insert(array, nil)
      table.insert(array, nil)
      table.insert(array, "c")
      table.insert(array, nil)

      local v = gen.ivals(array):vec()

      assert.same(v, vec("a", "b", "c"))

    end)

    it("iterates table ivalues", function ()

      local v = gen.ivals({ 1, 2, a = "b" }):vec()

      assert.same(v, vec(1, 2))

    end)

  end)

  describe("ikeys", function ()

    it("iterates table keys", function ()

      local v = gen.ikeys({ "a", "b", a = 12 }):vec()

      assert.same(v, vec(1, 2))

    end)

  end)

  describe("each", function ()

    it("applies a function to each item", function ()
      local gen = gen.pack(1, 2, 3, 4)
      local i = 0
      gen:each(function (x)
        i = i + 1
        assert.equals(i, x)
      end)
      assert(i == 4)
    end)

  end)

  describe("flatten", function ()

    it("flattens a generator of generators", function ()
      local v = gen(function (yield)
        yield(gen.pack(1, 2, 3, 4))
        yield(gen.pack(5, 6, 7, 8))
      end):flatten():vec()
      assert.same(v, vec(1, 2, 3, 4, 5, 6, 7, 8))
    end)

  end)

  describe("all", function ()

    it("reduces with and", function ()

      local gen1 = gen.pack(true, true, true)
      local gen2 = gen.pack(true, false, true)

      assert(gen1:all())
      assert(not gen2:all())

    end)

  end)

  describe("chain", function ()

    it("chains generators", function ()

      local gen1 = gen.pack(1, 2)
      local gen2 = gen.pack(3, 4)
      local vals = gen.chain(gen1, gen2):vec()

      assert.same(vec(1, 2, 3, 4), vals)

    end)

  end)

  describe("max", function ()

    it("returns the max value in a generator", function ()

      local gen = gen.pack(1, 6, 3, 9, 2, 10, 4)

      local max = gen:max()

      assert.equals(10, max)

    end)

  end)

  describe("empty", function ()

    it("should produce an empty generator", function ()

      local gen = gen.empty()

      local called = false

      gen:each(function ()
        called = true
      end)

      assert(not called)

    end)

  end)

  describe("paster", function () 

    it("should paste values to the right", function ()

      local vals = gen.pack(1, 2, 3):paster("num"):vec()

      assert.same(vec(vec(1, "num"), vec(2, "num"), vec(3, "num")), vals)

    end)

  end)

  describe("pastel", function () 

    it("should paste values to the left", function ()

      local vals = gen.pack(1, 2, 3):pastel("num"):vec()

      assert.same(vec(vec("num", 1), vec("num", 2), vec("num", 3)), vals)

    end)

  end)

  describe("discard", function ()

    it("should run a generator without processing vals", function ()

      local called = false

      local val = gen(function (yield)
        called = true
        yield(1)
        yield(2)
      end):discard()

      assert(called)

    end)

  end)

  describe("tup", function ()

    it("should convert a generator to multiple tuples", function ()

      local vals = gen(function (yield)
        yield(1, 2)
        yield(3, 4)
      end):tup()

      local a, b = vals()
      local x, y

      assert.same({ 1, 2 }, { a() })
      assert.same({ 3, 4 }, { b() })

    end)

  end)

  describe("unpack", function ()

    it("should unpack a generator", function ()

      local gen = gen.pack(1, 2, 3)

      assert.same({ 1, 2, 3 }, { gen:unpack() })

    end)

  end)

  describe("last", function ()

    it("should return the last element in a generator", function ()

      local gen = gen.pack(1, 2, 3)

      assert(3, gen:last())

    end)

  end)


end)
