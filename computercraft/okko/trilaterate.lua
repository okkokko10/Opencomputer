local Matrix = require "/okko/mymath/matrix"
local tri = {}

---@class vector: table
---@field x number
---@field y number
---@field z number

---@class Bra3: vector
---@class Ket3: vector



-- the equation |origin-x| = radius
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
    local A1 = left.origin * (-2)
    local B1 = -left.radius*left.radius + left.origin:dot(left.origin)
    local A2 = right.origin * (-2)
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
    print(mat)
    print("bra:",Matrix.bra(A.offset,B.offset,C.offset))
    print("ket: ",vec)
    print("fromBra:", Matrix.fromBra(A.normal))
    print("fromKet:", Matrix.fromKet(A.normal))
    local out = (Matrix.solve(mat,vec)) -- note that the inverse only depends on the origins
    print(out)
    return out

end


--- intersection of A B and C
---@param A Circle
---@param B Circle
---@param C Circle
---@return vector
function tri.solve_circles(A,B,C)
    local pA = tri.plane_of_circles(B,C)
    local pB = tri.plane_of_circles(A,C)
    local pC = tri.plane_of_circles(A,B)
    return (tri.solve_planes(pA,pB,pC))

end


function tri.execute()
    local X = peripheral.wrap("left").getClosestDistance()
    local Y = peripheral.wrap("top").getClosestDistance()
    local Z = peripheral.wrap("back").getClosestDistance()
    tri.solve_circles({
        origin = vector.new(1.01,0,0.001),
        radius = X
    },{
        origin = vector.new(0.003,1.2,0),
        radius = Y
    },{
        origin = vector.new(0,0,1.001),
        radius = Z
    })


end
tri.execute()

---@param ... Circle
function tri.calc(...)
    local circles = {...}
    -- local w = circles[1]
    local guess = vector.new(1,1,1)
    local w = guess + guess

    

end
