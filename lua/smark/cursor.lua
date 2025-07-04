require("smark.types")

local M = {}

---@param cursor_coords CursorCoords
---@param li_array ListItem[]
---@param li_array_bounds TextBlockBounds bounds of list block
---@return LiCursorCoords
function M.to_li_cursor_coords(cursor_coords, li_array, li_array_bounds)
	local current_li_bounds = { upper = li_array_bounds.upper - 1, lower = li_array_bounds.upper - 1 }

	for i, li in ipairs(li_array) do
		local current_li_num_lines = #li.content
		current_li_bounds.upper = current_li_bounds.lower + 1
		current_li_bounds.lower = current_li_bounds.lower + current_li_num_lines

		if cursor_coords.row1 >= current_li_bounds.upper and cursor_coords.row1 <= current_li_bounds.lower then
			local content_lnum = cursor_coords.row1 - current_li_bounds.upper + 1
			return { list_index = i, content_lnum = content_lnum, col = cursor_coords.col0 }
		end
	end

	error(
		string.format("rel_cursor_coords.row1 (%d) out of bounds (1 - %d)", cursor_coords.row1, current_li_bounds.lower)
	)
end

---@param li_cursor_coords LiCursorCoords
---@param li_array ListItem[]
---@param li_array_bounds TextBlockBounds bounds of list block
---@return CursorCoords
function M.to_absolute_cursor_coords(li_cursor_coords, li_array, li_array_bounds)
	local offset = 0

	for i = 1, li_cursor_coords.list_index do
		local li = li_array[i]

		if i < li_cursor_coords.list_index then
			offset = offset + #li.content
		else
			offset = offset + li_cursor_coords.content_lnum
		end
	end

	return {
		row1 = li_array_bounds.upper + offset - 1,
		col0 = li_cursor_coords.col,
	}
end

return M
