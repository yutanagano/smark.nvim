---@class CursorCoords
---@field row1 integer 1-indexed row number of cursor
---@field col0 integer 0-indexed column number of cursor

---@alias indent_spec integer[] Integer array describing the number of indent spaces required to align to each level, up to current

local list_item = require("smark.list_item")

local M = {}

---Mutate array of list items in place to enforce correct indentation.
---Optionally mutate relative cursor coordinates in place if supplied.
---Return a corresponding array of indent specs that describe the resulting correct indentation information.
---@param li_array ListItem[]
---@param rel_cursor_coords? CursorCoords Cursor coordinates relative to li_array
---@return indent_spec[]
function M.fix(li_array, rel_cursor_coords)
	local ispec_array = {}
	local index_counter = {}

	for i, li in ipairs(li_array) do
		if i == 1 then
			li.index = 1
			ispec_array[1] = { li.indent_spaces }
			index_counter[1] = { index = 2, is_ordered = li.is_ordered }
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

				li.index = 1
				li.indent_spaces = prev_nested_ispaces

				ispec[prev_ilevel + 1] = prev_nested_ispaces
				index_counter[prev_ilevel + 1] = { index = 2, is_ordered = li.is_ordered }

				ispaces_set = true
			end

			for ilevel = prev_ilevel, 1, -1 do
				local ispaces = prev_ispec[ilevel]
				if li.indent_spaces >= ispaces then
					if not ispaces_set then
						if rel_cursor_coords ~= nil and rel_cursor_coords.row1 == i then
							rel_cursor_coords.col0 = math.max(0, rel_cursor_coords.col0 + ispaces - li.indent_spaces)
						end

						if index_counter[ilevel].is_ordered ~= li.is_ordered then
							index_counter[ilevel].index = 1
							index_counter[ilevel].is_ordered = li.is_ordered
						end

						li.index = index_counter[ilevel].index
						li.indent_spaces = ispaces

						index_counter[ilevel].index = index_counter[ilevel].index + 1

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

---Only call this function _after_ fixing indentation, otherwise there will be undefined behaviour with respect to cursor position correction.
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param rel_cursor_coords? CursorCoords Cursor coordinates relative to li_array
function M.fix_numbering(li_array, ispec_array, rel_cursor_coords)
	assert(
		#li_array == #ispec_array,
		string.format("Lengths of li_array (%d) and ispec_array (%d) must be the same", #li_array, #ispec_array)
	)

	local index_counter = { { index = 1, is_ordered = false } }

	for i, li in ipairs(li_array) do
		local current_ilevel = #ispec_array[i]

		if current_ilevel > 0 then
			if index_counter[current_ilevel].is_ordered ~= li.is_ordered then
				index_counter[current_ilevel].index = 1
				index_counter[current_ilevel].is_ordered = li.is_ordered
			end

			if rel_cursor_coords ~= nil and rel_cursor_coords.row1 == i then
				local prev_preamble_len = list_item.get_preamble_length(li)
				li.index = index_counter[current_ilevel].index
				if rel_cursor_coords.col0 >= prev_preamble_len then
					local new_preamble_len = list_item.get_preamble_length(li)
					rel_cursor_coords.col0 = rel_cursor_coords.col0 + new_preamble_len - prev_preamble_len
				end
			else
				li.index = index_counter[current_ilevel].index
			end

			index_counter[current_ilevel].index = index_counter[current_ilevel].index + 1
			index_counter[current_ilevel + 1] = { index = 1, is_ordered = false }
		end
	end
end

---@param ispec indent_spec
---@return indent_spec
function M.get_indent_spec_like(ispec)
	local new_ispec = {}
	for i, v in ipairs(ispec) do
		new_ispec[i] = v
	end
	return new_ispec
end

return M
