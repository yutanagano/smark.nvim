---@class CursorCoords
---@field row integer 1-indexed row number of cursor
---@field col integer 0-indexed column number of cursor

---@class LiCursorCoords
---@field list_index integer index of list item that the cursor is inside
---@field content_lnum integer 1-indexed line number relative to the list item contents that the cursor is on
---@field col 0-indexed column number of cursor

local M = {}

---@param cursor_coords CursorCoords
---@param li_array ListItem[]
---@param li_array_bounds TextBlockBounds bounds of list block
---@return LiCursorCoords
function M.to_li_cursor_coords(cursor_coords, li_array, li_array_bounds)
	local li_index, content_lnum = M.make_relative_to_containing_li(cursor_coords.row, li_array, li_array_bounds)
	return { list_index = li_index, content_lnum = content_lnum, col = cursor_coords.col }
end

---Compute the index for the list element that occupies the given line number,
---as well as the line number relative to that list item's content that it
---corresponds to. Throws an error if the line number lies outside of the
---bounds.
---
---@param line_num integer 1-indexed line number
---@param li_array ListItem[]
---@param li_array_bounds TextBlockBounds bounds of list block
---@return integer li_index
---@return integer content_lnum
function M.make_relative_to_containing_li(line_num, li_array, li_array_bounds)
	local current_li_bounds = { upper = li_array_bounds.upper - 1, lower = li_array_bounds.upper - 1 }

	for i, li in ipairs(li_array) do
		local current_li_num_lines = #li.content
		current_li_bounds.upper = current_li_bounds.lower + 1
		current_li_bounds.lower = current_li_bounds.lower + current_li_num_lines

		if line_num >= current_li_bounds.upper and line_num <= current_li_bounds.lower then
			local content_lnum = line_num - current_li_bounds.upper + 1
			return i, content_lnum
		end
	end

	error(
		string.format(
			"line_num (%d) out of bounds (%d - %d)",
			line_num,
			current_li_bounds.upper,
			current_li_bounds.lower
		)
	)
end

---@param li_cursor_coords LiCursorCoords
---@param li_block ListItem[]
---@param li_block_bounds TextBlockBounds bounds of list block
---@return CursorCoords
function M.to_absolute_cursor_coords(li_cursor_coords, li_block, li_block_bounds)
	return {
		row = li_block_bounds.upper - 1 + M.get_row_relative_to_li_block_bounds(li_cursor_coords, li_block),
		col = li_cursor_coords.col,
	}
end

---@param li_cursor_coords LiCursorCoords
---@param li_block ListItem[]
---@return integer
function M.get_row_relative_to_li_block_bounds(li_cursor_coords, li_block)
	local offset = 0

	for i = 1, li_cursor_coords.list_index do
		local li = li_block[i]

		if i < li_cursor_coords.list_index then
			offset = offset + #li.content
		else
			offset = offset + li_cursor_coords.content_lnum
		end
	end

	return offset
end

return M
