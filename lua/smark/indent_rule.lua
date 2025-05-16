---@class IndentRule
---@field depth integer Number of indentation levels currently on stack

local list_item = require("smark.list_item")

local indent_rule = {}

---@param first_item_ordered boolean True if first list item is ordered
---@return IndentRule
function indent_rule.new(first_item_ordered)
	local next_indent_spaces
	if first_item_ordered then
		next_indent_spaces = 2
	else
		next_indent_spaces = 3
	end

	return {
		[1] = {
			indent_spaces = 0,
			is_ordered = first_item_ordered,
			index = 1,
		},
		[2] = {
			indent_spaces = next_indent_spaces,
			is_ordered = false,
			index = 1,
		},
		depth = 2,
	}
end

---Snap a list item's indentation against an indent rule to figure out the correct number of indent spaces.
---Update both the indent rule and list item in place as necessary.
---@param irule IndentRule
---@param li ListItem
function indent_rule.snap(irule, li)
	for i = irule.depth, 1, -1 do
		if li.indent_spaces >= irule[i].indent_spaces then
			li.indent_spaces = irule[i].indent_spaces

			if irule[i].is_ordered ~= li.is_ordered then
				irule[i].index = 1
				irule[i].is_ordered = li.is_ordered
			end

			li.index = irule[i].index
			irule[i].index = irule[i].index + 1

			irule.depth = i + 1
			irule[i + 1] = {
				indent_spaces = list_item.get_nested_indent_spaces(li),
				is_ordered = false,
				index = 1,
			}
			return
		end
	end

	error("This line should never be executed as all cases should have been caught earlier!")
end

return indent_rule
