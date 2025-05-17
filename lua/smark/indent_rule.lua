---@class CursorCoords
---@field row1 integer 1-indexed row number of cursor
---@field col0 integer 0-indexed column number of cursor

---@alias indent_spec integer[] Integer array describing the number of indent spaces required to align to each level, up to current

local list_item = require("smark.list_item")

local indent_rule = {}

---Mutate array of list items in place to enforce correct indentation.
---Optionally mutate relative cursor coordinates in place if supplied.
---Return a corresponding array of indent specs that describe the resulting correct indentation information.
---@param li_array ListItem[]
---@param rel_cursor_coords? CursorCoords Cursor coordinates relative to li_array
---@return indent_spec[]
function indent_rule.fix(li_array, rel_cursor_coords)
	local ispec_array = {}

	for i, li in ipairs(li_array) do
		if i == 1 then
			ispec_array[1] = { li.indent_spaces }
		else
			local ispec = {}
			local ispaces_set = false
			local prev_ispec = ispec_array[i - 1]
			local prev_ilevel = #prev_ispec
			local prev_nested_ispaces = list_item.get_nested_indent_spaces(li_array[i - 1])

			if li.indent_spaces >= prev_nested_ispaces then
				if rel_cursor_coords ~= nil and rel_cursor_coords.row1 == i then
					rel_cursor_coords.col0 =
						math.max(0, rel_cursor_coords.col0 + prev_nested_ispaces - li.indent_spaces)
				end
				li.indent_spaces = prev_nested_ispaces
				ispec[prev_ilevel + 1] = prev_nested_ispaces
				ispaces_set = true
			end

			for ilevel = prev_ilevel, 1, -1 do
				local ispaces = prev_ispec[ilevel]
				if li.indent_spaces >= ispaces then
					if not ispaces_set then
						if rel_cursor_coords ~= nil and rel_cursor_coords.row1 == i then
							rel_cursor_coords.col0 = math.max(0, rel_cursor_coords.col0 + ispaces - li.indent_spaces)
						end
						li.indent_spaces = ispaces
						ispaces_set = true
					end
					ispec[ilevel] = ispaces
				end
			end

			ispec_array[i] = ispec
		end
	end

	return ispec_array
end

return indent_rule
