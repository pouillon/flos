-- Array2D library
-- Implementing simple Array2D classes

local _m  = require "math"

local cls = require "flos.base"
local error = cls.floserr
local Array = cls.Array
local Array1D = cls.Array1D
local Array2D = cls.Array2D

local istable = cls.istable

-- Create the stride selection 
-- Array2D[i..":"..j..":"..step]

function Array2D.__newindex(self, k, v)
   if string.lower(tostring(k)) == "all" then
      if istable(v) then
	 error("ERROR  Assigning all elements in a vector to a table"
			.." is not allowed. They are assigned by reference.")
      end
      for i = 1 , #self do
	 self[i] = v
      end
   else
      if k < 1 or self.shape[1] < k then
	 error("ERROR  index is out of bounds")
      end
      rawset(self, k, v)
   end
end

function Array2D:initialize(...)
   -- Convert input option to a correct shape
   local shape = {...}
   
   -- Check wheter the table is a table of shape
   if #shape == 1 then
      if cls.istable(shape[1]) then
	 shape = shape[1]
      end
   end

   -- Check shape-arguments
   if #shape == 1 then
      -- this is actually erroneous, does the
      -- user really want a 2D array?
      shape[2] = 1
      
   elseif #shape ~= 2 then
      error("ERROR  shape initialization for Array2D is incompatible")
      
   end
   -- Check sizes
   for i = 1, 2 do
      if shape[i] < 1 then
	 error("ERROR  You are initializing a vector with size <= 0.")
      end
   end
   
   -- Rawset is needed to not call the bounds-check
   rawset(self, "shape", shape)
   rawset(self, "size", self.shape[1] * self.shape[2])
   for i = 1, self.shape[1] do
      self[i] = Array1D.empty(self.shape[2])
   end
end

-- Create an empty 2D array
function Array2D.empty(...)
   return Array2D:new(...)
end


-- Return a 2D array with initialized 0's
function Array2D.zeros(...)
   local new = Array2D.empty(...)
   for i = 1, #new do
      for j = 1, #new[i] do
	 new[i][j] = 0.
      end
   end
   return new
end

-- Return a 2D array with only 1.'s
function Array2D.ones(...)
   local new = Array2D.empty(...)
   for i = 1, #new do
      for j = 1, #new[i] do
	 new[i][j] = 1.
      end
   end
   return new
end

-- Return the absolute value of all elements
function Array2D:abs()
   local new = Array2D.empty(self.shape)
   for i = 1, #new do
      for j = 1, #new[i] do
	 new[i][j] = _m.abs(self[i][j])
      end
   end
   return new
end

-- Return the minimum value
function Array2D:min()
   local min = Array1D.empty(self.shape[1])
   for i = 1, #self do
      min[i] = self[i]:min()
   end
   return min
end

-- Return the maximum value
function Array2D:max()
   local max = Array1D.empty(self.shape[1])
   for i = 1, #self do
      max[i] = self[i]:max()
   end
   return max
end

function Array2D.from(tbl)
   local new
   if istable(tbl[1]) then
      new = Array2D.empty(#tbl, #tbl[1])
      for i = 1, #tbl do
	 for j = 1, #tbl[i] do
	    new[i][j] = tbl[i][j]
	 end
      end
   else
      local n = #tbl
      new = Array1D.empty(n)
      for i = 1, #tbl do
	 new[i] = tbl[i]
      end
      new = new:reshape(-1, 1)
   end
   return new
end


function Array2D:copy()
   local new = Array2D.empty(self.shape)
   for i = 1, self.shape[1] do
      for j = 1, self.shape[2] do
	 new[i][j] = self[i][j]
      end
   end
   return new
end

-- Create a copy of the data in a new shape of the
-- variables
function Array2D:reshape(...)
   -- Grab variable arguments
   local new_size = cls.arrayBounds(self.size, {...})
   local nsize = #new_size
   
   if nsize == 0 then

      -- Simply return a copy, size is the same.
      error("ERROR  reshaping with 0 arguments")

   elseif nsize == 1 then
      
      new = Array1D.empty(new_size[1])
      local k = 0
      for i = 1, self.shape[1] do
	 for j = 1, self.shape[2] do
	    k = k + 1
	    new[k] = self[i][j]
	 end
      end

   elseif nsize == 2 then

      new = Array2D.empty(new_size)
      
      -- initialize loop conters
      local k, l = 1, 0
      for i = 1, new_size[1] do
	 for j = 1, new_size[2] do
	    l = l + 1
	    if l > self.shape[2] then
	       l = 1
	       k = k + 1
	    end
	    new[i][j] = self[k][l]
	 end
      end

   else
      error("Array2D: reshaping not implemented")
      
   end

   return new
end

-- This "fake" table ensures that single values are indexable
-- I.e. we create an index function which returns the same value for any given
-- value.
local function ensurearray(val)
   if istable(val) then
      return val
   else
      -- We must have a number, fake the table (fake double entries
      -- by having a double metatable
      local mt = setmetatable({size = 1,
			       shape = {1},
			       class = false},
			       { __index = 
				    function(t, k)
				       return val
				    end
			       })
      return setmetatable({size = 1,
			   shape = {1, 1},
			   class = false},
			  { __index = 
			       function(t, k)
				  return mt
			       end
			  })
   end
end

local function op_elem(lhs, rhs)
   -- an option parser for the functions
   -- that require ELEMENT wise operations
   -- correct information
   local t = {}
   local s = 0
   local ls , rs = nil , nil

   -- Check LHS
   if cls.instanceOf(lhs, Array2D) then
      ls = lhs.shape
   elseif cls.instanceOf(lhs, Array1D) then
      error("ERROR  can not perform element operations on 2D and 1D arrays.")
   else
      ls = 1
   end
   t.lhz = ensurearray(lhs)
   -- Check RHS
   if cls.instanceOf(rhs, Array2D) then
      rs = rhs.shape
   elseif cls.instanceOf(rhs, Array1D) then
      error("ERROR  can not perform element operations on 1D and 2D arrays.")
   else
      rs = 1
   end
   t.rhz = ensurearray(rhs)
   
   if istable(ls) and istable(rs) then
      if ls[1] ~= rs[1] or ls[2] ~= rs[2] then
	 if #ls ~= 2 and #rs ~= 2 then
	    error("ERROR  Array2D dimensions incompatible")
	 end
      end
      t.shape = ls
      
   elseif istable(ls) then
      if rs ~= 1 then
	 error("ERROR  Array2D dimensions incompatible")
      end
      t.shape = ls
      
   elseif istable(rs) then
      if ls ~= 1 then
	 error("ERROR  Array2D dimensions incompatible")
      end
      t.shape = rs
      
   end

   return t
end

-- Length lookup
-- /for i = 1 , #Array2D do\
function Array2D.__len(self)
   return self.shape[1]
end


-- Implementation of norm function
function Array2D:norm()
   local n = Array1D.empty(self.shape[1])
   for i = 1 , #self do
      local nn = 0.
      for j = 1, self.shape[2] do
	 nn = nn + self[i][j] * self[i][j]
      end
      n[i] = _m.sqrt(nn)
   end
   return n
end

-- Implementation of sum function
function Array2D:sum()
   local n = Array1D.empty(self.shape[1])
   for i = 1 , #self do
      n[i] = self[i]:sum()
   end
   return n
end

-- Implementation of the (flattened) dot product
function Array2D.dot(lhs, rhs)

   function size_err(str)
      error("Array2D.dot: wrong dimensions. " .. str)
   end

   -- Returned value
   local v
   
   -- First we figure out if the dot (matrix-product)
   if cls.instanceOf(lhs, Array1D) then
      if cls.instanceOf(rhs, Array1D) then
	 -- An explicit call of the Array2D dot product
	 -- would probably be the same as doing the
	 --  x . y^T

	 -- vector . vector -> matrix
	 if lhs.size ~= rhs.size then
	    size_err("1D-1D")
	 end
	 v = Array2D.empty(lhs.size, lhs.size)
	 for i = 1, #lhs do
	    for j = 1, #lhs do
	       v[i][j] = lhs[i] * rhs[j]
	    end
	 end
	 
      elseif cls.instanceOf(rhs, Array2D) then
	 -- vector . matrix
	 if lhs.size ~= rhs.shape[1] then
	    size_err("1D-2D")
	 end
	 v = Array1D.empty(rhs.shape[2])
	 for j = 1 , #v do
	    local vv = 0.
	    for i = 1, #lhs do
	       vv = vv + lhs[i] * rhs[i][j]
	    end
	    v[j] = vv
	 end
	 
      else
	 -- simple scaling
	 v = lhs * rhs
      end

   elseif cls.instanceOf(lhs, Array2D) then
      if cls.instanceOf(rhs, Array1D) then

	 -- matrix . vector
	 if lhs.shape[2] ~= rhs.size then
	    size_err("2D-1D")
	 end
	 v = Array1D.empty(lhs.shape[1])
	 for j = 1 , #v do
	    local vv = 0.
	    for i = 1, #rhs do
	       vv = vv + lhs[j][i] * rhs[i]
	    end
	    v[j] = vv
	 end

      elseif cls.instanceOf(rhs, Array2D) then

	 -- matrix . matrix
	 if lhs.shape[2] ~= rhs.shape[1] then
	    size_err("2D-2D")
	 end
	 v = Array2D.empty(lhs.shape[1], rhs.shape[2])
	 for j = 1 , v.shape[1] do
	    -- Get local references
	    local lrow = lhs[j]
	    for i = 1 , v.shape[2] do

	       local vv = 0.
	       for k = 1 , lhs.shape[2] do
		  vv = vv + lrow[k] * rhs[k][i]
	       end
	       v[j][i] = vv
	       
	    end
	 end

      else
	 -- Simple scaling
	 v = lhs * rhs
      end
   else
      -- Simple scaling
      v = lhs * rhs
   end
   
   return v
end

--[[
   We need to create all the different methods for 
   numerical stuff
--]]
function Array2D.__add(lhs, rhs)
   local t = op_elem(lhs, rhs)
   -- Create the new vector
   local v = Array2D.empty(t.shape)
   
   -- We have now created the corrrect new vector for containing the
   -- data
   -- Loop over the vector size
   for i = 1 , #v do
      for j = 1, #v[i] do
	 v[i][j] = t.lhz[i][j] + t.rhz[i][j]
      end
   end
   return v
end

function Array2D.__sub(lhs, rhs)
   local t = op_elem(lhs, rhs)
   -- Create the new vector
   local v = Array2D.empty(t.shape)
   for i = 1 , #v do
      v[i] = t.lhz[i] - t.rhz[i]
   end
   return v
end

function Array2D.__mul(lhs, rhs)
   local t = op_elem(lhs, rhs)
   -- Create the new vector
   local v = Array2D.empty(t.shape)
   for i = 1 , #v do
      v[i] = t.lhz[i] * t.rhz[i]
   end
   return v
end

function Array2D.__div(lhs, rhs)
   local t = op_elem(lhs, rhs)
   -- Create the new vector
   local v = Array2D.empty(t.shape)
   for i = 1 , #v do
      v[i] = t.lhz[i] / t.rhz[i]
   end
   return v
end

function Array2D.__pow(lhs, rhs)
   if type(rhs) == "string" then
      -- it may be transpose we are after
      if rhs == "T" then
	 -- Create the transposed array
	 local v = Array2D.empty(lhs.shape[2], lhs.shape[1])
	 for i = 1 , #v do
	    for j = 1 , #v[i] do
	       v[i][j] = lhs[j][i]
	    end
	 end
	 return v
      end
      error("Unknown string power")
   end
	 
   local t = op_elem(lhs, rhs)
   -- Create the new vector
   local v = Array2D.empty(t.shape)
   for i = 1 , #v do
      v[i] = t.lhz[i] ^ t.rhz[i]
   end
   return v
end

-- Unary minus operation
function Array2D:__unm()
   local v = Array2D.empty(self.shape)
   for i = 1 , #self do
      for j = 1, #self[i] do
	 v[i][j] = -self[i][j]
      end
   end
   return v
end

function Array2D.__tostring(self)
   local s = "["
   for i = 1, #self do
      s = s .. "[" .. tostring(self[i][1])
      for j = 2 , #self[i] do
	 s = s .. ", " .. tostring(self[i][j])
      end
      if i < #self then
	 s = s .. "]\n "
      end
   end
   return s .. ']]'
end

return Array2D