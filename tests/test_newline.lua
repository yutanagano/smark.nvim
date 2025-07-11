local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local T = new_set()

-- Actual tests definitions will go here
T["works"] = function()
	local x = 2
end

return T
