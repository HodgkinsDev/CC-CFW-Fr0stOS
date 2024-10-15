local getmetatable = getmetatable
local expect = dofile("crom/modules/main/cc/expect.lua").expect
local vmetatable
local vector = {
    add = function(self, o)
        if getmetatable(self) ~= vmetatable then expect(1, self, "vector") end
        if getmetatable(o) ~= vmetatable then expect(2, o, "vector") end
        return vector.new(
            self.x + o.x,
            self.y + o.y,
            self.z + o.z
        )
    end,
    sub = function(self, o)
        if getmetatable(self) ~= vmetatable then expect(1, self, "vector") end
        if getmetatable(o) ~= vmetatable then expect(2, o, "vector") end
        return vector.new(
            self.x - o.x,
            self.y - o.y,
            self.z - o.z
        )
    end,
    mul = function(self, factor)
        if getmetatable(self) ~= vmetatable then expect(1, self, "vector") end
        expect(2, factor, "number")
        return vector.new(
            self.x * factor,
            self.y * factor,
            self.z * factor
        )
    end,
    div = function(self, factor)
        if getmetatable(self) ~= vmetatable then expect(1, self, "vector") end
        expect(2, factor, "number")
        return vector.new(
            self.x / factor,
            self.y / factor,
            self.z / factor
        )
    end,
    unm = function(self)
        if getmetatable(self) ~= vmetatable then expect(1, self, "vector") end
        return vector.new(
            -self.x,
            -self.y,
            -self.z
        )
    end,
    dot = function(self, o)
        if getmetatable(self) ~= vmetatable then expect(1, self, "vector") end
        if getmetatable(o) ~= vmetatable then expect(2, o, "vector") end
        return self.x * o.x + self.y * o.y + self.z * o.z
    end,
    cross = function(self, o)
        if getmetatable(self) ~= vmetatable then expect(1, self, "vector") end
        if getmetatable(o) ~= vmetatable then expect(2, o, "vector") end
        return vector.new(
            self.y * o.z - self.z * o.y,
            self.z * o.x - self.x * o.z,
            self.x * o.y - self.y * o.x
        )
    end,
    length = function(self)
        if getmetatable(self) ~= vmetatable then expect(1, self, "vector") end
        return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
    end,
    normalize = function(self)
        return self:mul(1 / self:length())
    end,
    round = function(self, tolerance)
        if getmetatable(self) ~= vmetatable then expect(1, self, "vector") end
        expect(2, tolerance, "number", "nil")
        tolerance = tolerance or 1.0
        return vector.new(
            math.floor((self.x + tolerance * 0.5) / tolerance) * tolerance,
            math.floor((self.y + tolerance * 0.5) / tolerance) * tolerance,
            math.floor((self.z + tolerance * 0.5) / tolerance) * tolerance
        )
    end,
    tostring = function(self)
        if getmetatable(self) ~= vmetatable then expect(1, self, "vector") end
        return self.x .. "," .. self.y .. "," .. self.z
    end,
    equals = function(self, other)
        if getmetatable(self) ~= vmetatable then expect(1, self, "vector") end
        if getmetatable(other) ~= vmetatable then expect(2, other, "vector") end
        return self.x == other.x and self.y == other.y and self.z == other.z
    end,
}
vmetatable = {
    __name = "vector",
    __index = vector,
    __add = vector.add,
    __sub = vector.sub,
    __mul = vector.mul,
    __div = vector.div,
    __unm = vector.unm,
    __tostring = vector.tostring,
    __eq = vector.equals,
}
function new(x, y, z)
    return setmetatable({
        x = tonumber(x) or 0,
        y = tonumber(y) or 0,
        z = tonumber(z) or 0,
    }, vmetatable)
end