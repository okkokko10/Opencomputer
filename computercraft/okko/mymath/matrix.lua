





-- -@generic T
-- -@class Ring<T>
-- -@operator add():T
-- -@operator unm():T
-- -@operator mul(T):T

---@alias dim  integer
---@alias three 1|2|3

---@class Field: number

--- a linear map from `Ket<X>` to `Ket<Y>`  
--- `Matrix<Y,X> .. Ket<X> = Ket<Y>`  
--- `Matrix<Y,1> ≃ Ket<Y>`
--- Represents a linear combination of `Ket<Y> .. Bra<X>`  
--- (will `..` as an operator catch on?)  
--- X is cols, Y is rows  
--- `Matrix<Y,X> * Matrix<X,W> = Matrix<Y,W>`
---@generic Y1: dim, X1: dim, F1: Field
---@class Matrix<Y1, X1, F1>
---@field zero F1
---@field cols Y1
---@field rows X1
---@operator add(Matrix<Y1,X1, F1>): Matrix<Y1,X1, F1>
---@operator unm: Matrix<Y1,X1, F1>
---@operator sub(Matrix<Y1,X1, F1>): Matrix<Y1,X1, F1>
---@operator mul(Matrix<X1,any, F1>): Matrix<Y1,any, F1> # doesn't have generics for this
local Matrix = {__name = "Matrix"}

---@generic Y:dim,F:Field
---@alias Ket<Y,F> Matrix<Y,1,F>
---@alias Bra<X,F> Matrix<1,X,F>

Matrix.__index = Matrix

-- col is the input dimension, row the output dimension:
-- A(x: R^col) : R^row

--[[




            . t r i
            c . . .
            o . . .
            l . . .

 . c o l    . t r i 
 r . . .    r . . .
 o . . .    o . . .
 w . . .    w . . .
 . . . .    . . . .

W^(col,row): X^col -> X^row



        X
        Y
        Z
A B C   AX+BY+CZ


<a| |b> : 1
|b><c| : |> --> |>






a bit confusing: a column vector is a matrix with one column


]]


---create a base new matrix, without initializing values 
---@generic Y: dim,X: dim, F: Field
---@param cols `Y`
---@param rows `X`
---@return Matrix<Y,X, F>
function Matrix.new_base(cols,rows)
    local out = setmetatable({cols = cols, rows = rows},Matrix)
    return out
end


--- contiguous row.

---@generic Y: dim, X: dim, F: Field # default
---@param self Matrix<Y,X, F> # default
---@param col Y
---@param row X
---@return integer
function Matrix:getindex(col,row)
    return self.rows*(col-1)+row
end

function Matrix:rawindices()
    return self.rows*self.cols
end

---@generic Y: dim, X: dim, F: Field # default
---@param self Matrix<Y,X, F> # default
---@param col Y
---@param row X
---@param value F
---@return self self 
function Matrix:set(col,row,value)
    self[self:getindex(col,row)] = value
    return self
end

---@generic Y: dim, X: dim, F: Field # default
---@param self Matrix<Y,X, F> # default
---@param col Y
---@param row X
---@return F
function Matrix:get(col,row)
    return self[self:getindex(col,row)]
end


---@generic Y: dim,X: dim, Fa: Field, Fb: Field, Fc: Field
---@param A Matrix<Y,X, Fa>
---@param B Matrix<Y,X, Fb>
---@param target Matrix<Y,X, Fc>
---@param func fun(a:Fa,b:Fb):Fc
function Matrix._zipmapto(A,B,target,func)
    -- todo: can be made more efficient by using raw indices

    for i = 1, target:rawindices() do
        target[i] = func(A[i],B[i])
    end

    -- for y = 1,A.cols do
    --     for x = 1,A.rows do
    --         target:set(y,x,func(A:get(y,x),B:get(y,x)))
    --     end
    -- end
end


---@generic Y: dim,X: dim, Fa: Field, Fb: Field, Fc: Field
---@param A Matrix<Y,X, Fa>
---@param B Matrix<Y,X, Fb>
---@param func fun(a:Fa,b:Fb):Fc
---@return Matrix<Y,X, Fc>
function Matrix.zipmap(A,B,func)
    local out = Matrix.new_base(A.cols,A.rows)
    Matrix._zipmapto(A,B,out,func)
    return out
end

---@generic Y: dim,X: dim, Fa: Field, Fb: Field
---@param A Matrix<Y,X, Fa>
---@param func fun(a:Fa):Fb
---@return Matrix<Y,X, Fb>
function Matrix.map(A,func)
    local target = Matrix.new_base(A.cols,A.rows)
    
    for i = 1, target:rawindices() do
        target[i] = func(A[i])
    end
    -- for y = 1,A.cols do
    --     for x = 1,A.rows do
    --         target:set(y,x,func(A:get(y,x)))
    --     end
    -- end
    return target
end


---@generic Y: dim,X: dim, F: Field
---@param cols `Y`
---@param rows `X`
---@param func fun(y:Y,x:X):F
---@return Matrix<Y,X, F>
function Matrix.fill(cols,rows,func)
    local target = Matrix.new_base(cols,rows)
    for y = 1,cols do
        for x = 1,rows do
            target:set(y,x,func(y,x))
        end
    end
    return target

end


---@generic Y: dim, X: dim, F: Field # default
---@param self Matrix<Y,X, F> # default
---@param other Matrix<Y,X, F>
---@return Matrix<Y,X, F>
function Matrix:__add(other)
    local function addition(s,o)
        return s + o
    end
    return Matrix.zipmap(self,other,addition)
end


---@generic Y: dim, X: dim, F: Field # default
---@param self Matrix<Y,X, F> # default
---@param other Matrix<Y,X, F>
---@return Matrix<Y,X, F>
function Matrix:__sub(other)
    local function subtract(s,o)
        return s - o
    end
    return Matrix.zipmap(self,other,subtract)
    end

---@generic W:dim
---@generic Y: dim, X: dim, F: Field # default
---@param self Matrix<Y,X, F> # default
---@param other Matrix<X,W, F>
---@return Matrix<Y,W, F>
function Matrix:mul(other)
    -- -@type Matrix<Y,W, F>
    local target = Matrix.new_base(self.cols,other.rows)
    for y = 1,self.cols do
        for w = 1,other.rows do
            local total = 0
            for x = 1, self.rows or other.cols do -- or just for clarity
                total = total + self:get(y,x) * other:get(x,w)
            end
            target:set(y --[[@as `Y`]],w--[[@as `W`]],total)
        end
    end
    return target
end


--- with a heterogenous multiplication mulF
---@generic Y:dim,X:dim,W:dim, Fs:Field, Fo:Field, Fr:Field
---@param self Matrix<Y,X, Fs>
---@param other Matrix<X,W, Fo>
---@param mulF fun(s: Fs, o: Fo): Fr
---@param addF fun(a: Fr, b: Fr): Fr
---@return Matrix<Y,W, Fr>
function Matrix:mul_field(other,mulF,addF)
    local target = Matrix.new_base(self.cols,other.rows)
    for y = 1,self.cols do
        for w = 1,other.rows do
            local total = self:get(y,1) * other:get(1,w)
            for x = 2, self.rows or other.cols do
                total = addF(total,mulF(self:get(y,x),other:get(x,w)))
            end
            target:set(y,w,total)
        end
    end
    return target
end

---@generic Y: dim, X: dim, F: Field # default
---@param self Matrix<Y,X, F> # default
---@param scalar F
function Matrix:scalar_mul(scalar)
    return self:map(function(a) return a * scalar end)
end


---@param vec Ket3
---@return Ket3
function Matrix:mul_vector(vec)
    local a = self:__mul(Matrix.fromVector(vec))
    return a:toVector()
end


--- number*Matrix, Matrix*number, Matrix*Matrix, Matrix*vector
---@param left Matrix|number
---@param right Matrix|number|Ket3
function Matrix.__mul(left,right)
    if type(left) == "number" then -- number is the only sensical thing to left multiply this by. vector-matrix multiplication is not supported
        return right:scalar_mul(left) -- only way this function was called is if right is a matrix
    end
    if  type(right) == "number" then
        return left:scalar_mul(right)
    elseif getmetatable(right) == Matrix then
        return left:mul(right)
    else
        ---@cast right Ket3
        return left:mul_vector(right)
    end
end



--- makes a column vector -- that's odd. why does a column vector have multiple columns?
---@param vec Ket3
---@return Ket<three,number> 
function Matrix.fromVector(vec)
    ---@type Matrix<three,1,number>
    local out = Matrix.new_base(3,1)
    out:set(1,1,vec.x)
    out:set(2,1,vec.y)
    out:set(3,1,vec.z)
    return out
end
Matrix.fromKet=Matrix.fromVector

---@param vec Bra3
---@return Bra<three,number> 
function Matrix.fromBra(vec)
    ---@type Bra<three,number>
    local out = Matrix.new_base(1,3)
    out:set(1,1,vec.x)
    out:set(1,2,vec.y)
    out:set(1,3,vec.z)
    return out
end


---@param self Ket<three,number>
---@return Ket3
function Matrix:toVector()
    return vector.new(self:get(1,1),self:get(2,1),self:get(3,1))
end
Matrix.toKet = Matrix.toVector

---@param self Bra<three,number>
---@return Bra3
function Matrix:toBra()
    return vector.new(self:get(1,1),self:get(1,2),self:get(1,3))
end

---@generic F:Field
---@param ... F
---@return Ket<unknown,F>
function Matrix.ket(...)
    local out = setmetatable({...},Matrix)
    out.cols = select("#",...)
    out.rows = 1
    return out
end
---@generic F:Field
---@param ... F
---@return Bra<unknown,F>
function Matrix.bra(...)
    local out = setmetatable({...},Matrix)
    out.cols = 1
    out.rows = select("#",...)
    return out
end


---@generic X:dim,F:Field
---@param ... Matrix<any,X,F>
---@return Matrix<any,X,F> 
function Matrix.stack(...)
    local hy = 0
    local out = Matrix.new_base(1,(...).rows)
    local pointer = 1
    for i = 1, select("#",...) do
        ---@type Matrix<any,X,F>
        local mi = select(i,...)
        hy = hy + mi.cols
        for j = 1, mi.cols*mi.rows do
            out[pointer]=mi[j]
            pointer = pointer + 1
        end
    end
    out.cols = hy
    return out
end


function Matrix.identity(cols)
    local out = Matrix.new_base(cols,cols)
    for y = 1, cols do
        for x = 1, cols do
            out:set(y,x,0)
        end
    end
    for z = 1, cols do
        out:set(z,z,1)
    end
    return out
end


---@generic Y: dim, X: dim, F: Field # default
---@param self Matrix<Y,X, F> # default
---@param debug_print fun(copy:Matrix<Y,X, F>, out: Matrix<Y,X, F>, step: string|nil)|nil
---@return Matrix<X,Y,F>|nil
---@return nil|string
---@overload fun(self: Matrix<Y,X, F>): Matrix<X,Y,F>|nil,nil|string
function Matrix.inverse(self, debug_print)
    if (self.cols~=self.rows) then return nil, "only square matrices have inverses!" end
    local copy = self:scalar_mul(1)
    local out = Matrix.identity(self.cols)
    -- gaussian elimination
    ---@generic Y: dim, X: dim, F: Field # default
    ---@param mat Matrix<Y,X,F>
    ---@param from Y
    ---@param to Y
    ---@param mult F
    local function add(mat,from,to,mult)
        for x = 1, mat.rows do
            mat:set(to,x,mat:get(to,x)+mat:get(from,x)*mult)
        end
    end
    local function mul(mat,y,mult)
        for x = 1, mat.rows do
            mat:set(y,x,mat:get(y,x) * mult)
        end
    end
    local function add2(from,to,mult)
        add(copy,from,to,mult)
        add(out,from,to,mult)
    end
    local function mul2(y,mult)
        mul(copy,y,mult)
        mul(out,y,mult)
    end
    
    if debug_print then debug_print("start gaussian elimination",copy,out) end;

    for from = 1, copy.cols do
        if copy:get(from,from) == 0 then -- this will be false after this branch
            local success
            for y = 1, copy.cols do
                if copy:get(y,from) ~= 0 then
                    add2(y,from,1)
                    if debug_print then debug_print("make diagonal nonzero: add "..y.." -> ["..from.. "]",copy,out) end;
                    success = true
                    break
                end
            end
            if (not success) then
                if debug_print then debug_print("error: not invertible: column of zeroes on col "..from,copy,out) end;
                return nil, ("not invertible")
            end
            
        end
        local diag = copy:get(from,from)
        for to = 1, copy.cols do
            if from ~= to then
                local valu = -copy:get(to,from) / diag
                add2(from,to,valu)
                if debug_print then debug_print("subtract ["..valu.."] "..from.." -> "..to,copy,out) end;
            end
        end
    end
    for z = 1, copy.cols do
        local div = copy:get(z,z)
        mul2(z,1/div)
        if debug_print then debug_print("divide by ["..div.."] at "..z,copy,out) end;

    end
    ---@cast out -unknown
    return out
end


function Matrix:__unm()
    Matrix.map(self,function (x)
        return -x
    end)
end

---@generic Y: dim, X: dim, F: Field # default
---@param self Matrix<Y,X, F> # default
---@param other Matrix<Y,X, F>
---@return F
function Matrix:difference(other)
    local total = 0
    local function func(a,b)
        local diff = a - b
        total = total + diff*diff
    end

    Matrix.zipmap(self,other,func)
    return total
end

function Matrix:__tostring()
    local out = "[\n"
    for y = 1,self.cols do
        out = out .. " ["
        for x = 1,self.rows do
            
            out = out ..string.format("%7s", string.format("%+3.2f ", self:get(y,x)))
        end
        out = out .. "]\n"
    end
    return out .. "]"
end
-- function Matrix:__eq(other)

-- end

---comment
---@param self Matrix<3,3,number>
---@param vec Ket<3,number>
---@return Ket<3,number>
function Matrix:solve(vec)
    return self:inverse()*(vec)
end





local function display(step,...)
    read()
    term.clear()
    term.setCursorPos(1,1)
    print(step)
    for i,v in ipairs({...}) do
        print(v)
    end
end


---inverse, but prints the algorithm.
function Matrix:inverse_debug()
    return self:inverse(display)
end

local function test_inverse()
    local rand = Matrix.fill(5,5,function ()
        return 2 * math.random() - 1
    end)
    local inv = rand:inverse_debug()
    ---@type Matrix
    local back = rand * inv
    print("testing inverse")
    print(back)
    print("difference:",back:difference(Matrix.identity(5)))

end

if ... == "test-inverse" then

    test_inverse()
    
end



---@diagnostic disable-next-line unused-function 
local function test_lint() 
    ---@diagnostic disable: unused-local
    local w23 = Matrix.new_base(2,3) -- Matrix<integer,integer>
    ---@type Matrix<2,3>
    local a23 = Matrix.new_base(2,3)
    ---@type Matrix<1,2>
    local a12 = Matrix.new_base(1,2)
    local a13 = a12*a23 -- unknown
    local b13 = a12:__mul(a23) -- Matrix<1,W>
    local b13_rows = b13.rows -- <W>
    local c13 = Matrix.__mul(a12, a23) -- Matrix<1,3> -- correct
    local c13_zero = c13.zero
    local c13_cols = c13.cols
    local c13_rows = c13.rows
    ---@diagnostic enable: unused-local
end




return Matrix