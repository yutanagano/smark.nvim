---@class CursorCoords
---@field row1 integer 1-indexed row number of cursor
---@field col0 integer 0-indexed column number of cursor

---@alias indent_spec IndentLevelSpec[] Integer array describing the number of indent spaces required to align to each level, up to current

---@class IndentLevelSpec
---@field is_ordered boolean
---@field indent_spaces integer

local list_item = require("smark.list_item")

local M = {}

---Mutate array of list items in place to enforce correct indentation and numbering.
---Optionally mutate relative cursor coordinates in place if supplied.
---Return a corresponding array of indent specs that describe the resulting correct indentation information.
---@param li_array ListItem[]
---@param rel_cursor_coords? CursorCoords Cursor coordinates relative to li_array
---@return indent_spec[]
function M.fix(li_array, rel_cursor_coords)
	local ispec_array = {}
	local index_counter = {}
	local prev_original_indent_spaces

	for i, li in ipairs(li_array) do
		local original_preamble_len = list_item.get_preamble_length(li)

		if i == 1 then
			li.index = 1
			ispec_array[1] = { { is_ordered = li.is_ordered, indent_spaces = li.indent_spaces } }
			index_counter[1] = 2
			prev_original_indent_spaces = li.indent_spaces
		else
			local prev_ispec = ispec_array[i - 1]
			local prev_ilevel = #prev_ispec
			local prev_nested_ispaces = list_item.get_nested_indent_spaces(li_array[i - 1])
			local ispec = {}
			local ispaces_set = false

			if li.indent_spaces == prev_original_indent_spaces then
				li.indent_spaces = prev_ispec[prev_ilevel].indent_spaces
			else
				prev_original_indent_spaces = li.indent_spaces
			end

			if li.indent_spaces >= prev_nested_ispaces then
				li.index = 1
				li.indent_spaces = prev_nested_ispaces

				ispec[prev_ilevel + 1] = { is_ordered = li.is_ordered, indent_spaces = prev_nested_ispaces }
				index_counter[prev_ilevel + 1] = 2

				ispaces_set = true
			end

			for ilevel = prev_ilevel, 1, -1 do
				local is_ordered = prev_ispec[ilevel].is_ordered
				local ispaces = prev_ispec[ilevel].indent_spaces
				if li.indent_spaces >= ispaces then
					if not ispaces_set then
						if is_ordered ~= li.is_ordered then
							index_counter[ilevel] = 1
							is_ordered = li.is_ordered
						end

						li.index = index_counter[ilevel]
						li.indent_spaces = ispaces

						index_counter[ilevel] = index_counter[ilevel] + 1

						ispaces_set = true
					end
					ispec[ilevel] = { is_ordered = is_ordered, indent_spaces = ispaces }
				end
			end

			ispec_array[i] = ispec
		end

		if
			rel_cursor_coords ~= nil
			and rel_cursor_coords.row1 == i
			and rel_cursor_coords.col0 >= original_preamble_len
		then
			rel_cursor_coords.col0 = rel_cursor_coords.col0 + list_item.get_preamble_length(li) - original_preamble_len
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

	local index_counter = { 1 }

	for i, li in ipairs(li_array) do
		local current_ilevel = #ispec_array[i]

		if current_ilevel == 0 then
			index_counter[1] = 1
		else
			if
				i > 1
				and ispec_array[i - 1][current_ilevel] ~= nil
				and ispec_array[i - 1][current_ilevel].is_ordered ~= li.is_ordered
			then
				index_counter[current_ilevel] = 1
			end

			if index_counter[current_ilevel] == nil then
				index_counter[current_ilevel] = 1
			end

			if rel_cursor_coords ~= nil and rel_cursor_coords.row1 == i then
				local prev_preamble_len = list_item.get_preamble_length(li)
				li.index = index_counter[current_ilevel]
				if rel_cursor_coords.col0 >= prev_preamble_len then
					local new_preamble_len = list_item.get_preamble_length(li)
					rel_cursor_coords.col0 = rel_cursor_coords.col0 + new_preamble_len - prev_preamble_len
				end
			else
				li.index = index_counter[current_ilevel]
			end

			index_counter[current_ilevel] = index_counter[current_ilevel] + 1
			index_counter[current_ilevel + 1] = 1
		end
	end
end

---@param ispec indent_spec
---@return indent_spec
function M.get_indent_spec_like(ispec)
	local new_ispec = {}
	for i, ils in ipairs(ispec) do
		new_ispec[i] = {
			is_ordered = ils.is_ordered,
			indent_spaces = ils.indent_spaces,
		}
	end
	return new_ispec
end

return M
