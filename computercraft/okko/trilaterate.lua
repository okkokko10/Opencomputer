local Matrix = require "/okko/mymath/matrix"
local tri = {}

---@class vector: table
---@field x number
---@field y number
---@field z number

---@class Bra3: vector
---@class Ket3: vector



-- the equation |x-origin| = radius
---@class Circle
---@field origin vector
---@field radius number


---@param guess vector
---@param circle Circle
function tri.effect(guess,circle)
    local dv = (guess - circle.origin)
    local d = dv:length()
end

-- idea: find it quicker by having points on each circle that attract each other.
-- make sure both are such that their own circle is closer at the point
-- no, just solve the quadratic form

--- represents the linear equation normal * x = offset 
---@class Plane
---@field normal Bra3
---@field offset number


---@param left Circle
---@param right Circle
---@return Plane
function tri.plane_of_circles(left, right)
    local A1 = left.origin * (2)
    local B1 = -left.radius*left.radius + left.origin:dot(left.origin)
    local A2 = right.origin * (2)
    local B2 = -right.radius*right.radius + right.origin:dot(right.origin)
    return {normal = A1 - A2, offset = B1 - B2}
end

--- intersection of A B and C
---@param A Plane
---@param B Plane
---@param C Plane
---@return vector
function tri.solve_planes(A,B,C)
    -- [A.normal; B.normal; C.normal] * x = [A.offset; B.offset; C.offset]
    local mat = Matrix.stack(
        Matrix.fromBra(A.normal),
        Matrix.fromBra(B.normal),
        Matrix.fromBra(C.normal)
    )
    local vec = Matrix.ket(A.offset,B.offset,C.offset)
    -- print(mat)
    -- print("bra:",Matrix.bra(A.offset,B.offset,C.offset))
    -- print("ket: ",vec)
    -- print("fromBra:", Matrix.fromBra(A.normal))
    -- print("fromKet:", Matrix.fromKet(A.normal))
    local out = (Matrix.solve(mat,vec)) -- note that the inverse only depends on the origins
    -- print(out)
    return Matrix.toKet(out)
end


---does the point truly lie at the intersection?
---@param circles Circle[]
---@param point Location
---@return boolean small
---@return number variance
function tri.circles_validate(circles,point)

    local total_variance = 0.0
    for key, circle in pairs(circles) do
        local dev = (point - circle.origin):length() - circle.radius
        total_variance = total_variance + dev*dev
    end
    return total_variance < 0.01, total_variance
end



--- intersection of A B and C
---@param A Circle
---@param B Circle
---@param C Circle
---@param D Circle
---@return vector
function tri.solve_circles(A,B,C,D)
    local AB = tri.plane_of_circles(A,B)
    local AC = tri.plane_of_circles(A,C)
    local AD = tri.plane_of_circles(A,D)
    return (tri.solve_planes(AB,AC,AD))

end

---@class constellation
---@field origins {[string]: Location}

local directions = {
    top = vector.new(0,1,0),
    bottom = vector.new(0,-1,0),
    left = vector.new(-1,0,0),
    right = vector.new(1,0,0),
    back = vector.new(0,0,-1),
    front = vector.new(0,0,1)
}



function tri.get_peripheral_constellation()
    local out = {}
    for key, value in pairs(directions) do
        if peripheral.getType(key) == "modulating_link" then
            out[key] = value
        end
    end
    return {
        origins = out
    }
end

function tri.radii_of_peripheral_constellation(constellation)
    local radii = {}
    for key, value in pairs(constellation.origins) do
        peripheral.call(key,"getClosestDistance")
    end
    return radii
end



---is the radius valid? 0 can mean null. also takes care of the nil case
---@param radius number|nil
---@return boolean|nil
function tri.valid_radius(radius)
    return radius and radius > 0
end


function tri.use_constellation_with_radii(constellation,radii)

    ---@type Circle[]
    local okay = {}
    for key, value in pairs(constellation.origins) do
        local radius = radii[key]
        if tri.valid_radius(radius) then
            okay[#okay + 1] = {
                origin = value,
                radius = radius
            }
        end
        if #okay >= 4 then 
            break
        end
    end
    if not #okay >= 4 then 
        return
    end
    tri.solve_circles(table.unpack(okay))

    
end

---@class PrecalculatedConstellation
---@field points {[1|2|3|4] : Location}
---@field inv Matrix<three,three,number>
---@field B {[three]: number}


---comment
---@param points {[1|2|3|4] : Location}
function tri.precalculate(points)
    local function normal(left,right)
        return 2*(left.origin - right.origin)
    end
    local mat = Matrix.stack(
        Matrix.fromBra(normal(points[1],points[2])),
        Matrix.fromBra(normal(points[1],points[3])),
        Matrix.fromBra(normal(points[1],points[4]))
    )
    local inv = mat:inverse()
    
    local B1 = -left.radius*left.radius + left.origin:dot(left.origin)
    --todo: incomplete
    
end
---comment
---@param prec PrecalculatedConstellation
---@param radii {[1|2|3|4] : number}
function tri.precalculate_after(prec,radii)
    -- todo: incomplete
end


-- todo: matrices that use non-number indices

function tri.execute()
    local X = peripheral.wrap("left").getClosestDistance()
    local Y = peripheral.wrap("top").getClosestDistance()
    local Z = peripheral.wrap("back").getClosestDistance()
    -- local mY = peripheral.wrap("bottom").getClosestDistance()
    local mX = peripheral.wrap("right").getClosestDistance()
    return tri.solve_circles({
        origin = vector.new(1,0,0),
        radius = X
    },{
        origin = vector.new(0,1,0),
        radius = Y
    },{
        origin = vector.new(0,0,1),
        radius = Z
    },
    {
        origin = vector.new(-1,0,0),
        radius = mX
    }
    )
end

function tri.test()
    local c = {}
    local p = vector.new(math.random(),math.random(),math.random())
    for i = 1,4 do
        local origin = vector.new(math.random(),math.random(),math.random())
        c[i] = {
            origin = origin,
            radius = (origin - p):length()
        }
    end
    local res = tri.solve_circles(c[1],c[2],c[3],c[4])
    return (p - res):length(), p, res
    
end


tri.execute()

do
    local d,p,res = tri.test()
    if d > 0.01 then
        print(p,res)
        error("trilaterate test fails: ".. d.. " > 0.01")
    end
end

return tri