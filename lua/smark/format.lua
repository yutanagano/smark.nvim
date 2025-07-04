require("smark.types")

local list_item = require("smark.list_item")

local M = {}

---Mutate array of list items in place to enforce correct indentation and numbering.
---Optionally mutate relative cursor coordinates in place if supplied.
---Return a corresponding array of indent specs that describe the resulting correct indentation information.
---@param li_array ListItem[]
---@param li_cursor_coords? LiCursorCoords
---@param original_preamble_len? integer The number of characters before content on the cursor line at read time. If not supplied, then is computed assuming that the list item had no extra whitespace characters before the content, which is not necessarily the case at read time.
---@return indent_spec[]
function M.fix(li_array, li_cursor_coords, original_preamble_len)
	local ispec_array = {}
	local index_counter = {}
	local prev_original_indent_spaces

	for i, li in ipairs(li_array) do
		if li_cursor_coords ~= nil and li_cursor_coords.list_index == i and original_preamble_len == nil then
			original_preamble_len = list_item.get_preamble_length(li)
		end

		if i == 1 then
			li.spec.index = 1
			ispec_array[1] = { { is_ordered = li.spec.is_ordered, indent_spaces = li.spec.indent_spaces } }
			index_counter[1] = 2
			prev_original_indent_spaces = li.spec.indent_spaces
		elseif li.spec.indent_spaces == -1 then
			ispec_array[i] = {}
			index_counter[1] = 1
			prev_original_indent_spaces = nil
		else
			local prev_ispec = ispec_array[i - 1]
			local prev_ilevel = #prev_ispec
			local prev_nested_ispaces = list_item.get_nested_indent_spaces(li_array[i - 1])
			local ispec = {}
			local ispaces_set = false

			if li.spec.indent_spaces == prev_original_indent_spaces then
				li.spec.indent_spaces = prev_ispec[prev_ilevel].indent_spaces
			else
				prev_original_indent_spaces = li.spec.indent_spaces
			end

			if li.spec.indent_spaces >= prev_nested_ispaces then
				li.spec.index = 1
				li.spec.indent_spaces = prev_nested_ispaces

				ispec[prev_ilevel + 1] = { is_ordered = li.spec.is_ordered, indent_spaces = prev_nested_ispaces }
				index_counter[prev_ilevel + 1] = 2

				ispaces_set = true
			end

			for ilevel = prev_ilevel, 1, -1 do
				local is_ordered = prev_ispec[ilevel].is_ordered
				local ispaces = prev_ispec[ilevel].indent_spaces
				if li.spec.indent_spaces >= ispaces or (ilevel == 1 and li.spec.indent_spaces ~= -1) then
					if not ispaces_set then
						if is_ordered ~= li.spec.is_ordered then
							index_counter[ilevel] = 1
							is_ordered = li.spec.is_ordered
						end

						li.spec.index = index_counter[ilevel]
						li.spec.indent_spaces = ispaces

						index_counter[ilevel] = index_counter[ilevel] + 1

						ispaces_set = true
					end
					ispec[ilevel] = { is_ordered = is_ordered, indent_spaces = ispaces }
				end
			end

			ispec_array[i] = ispec
		end

		if
			li_cursor_coords ~= nil
			and li_cursor_coords.list_index == i
			and li_cursor_coords.col >= original_preamble_len
		then
			li_cursor_coords.col = li_cursor_coords.col + list_item.get_preamble_length(li) - original_preamble_len
		end
	end

	return ispec_array
end

---Only call this function _after_ fixing indentation, otherwise there will be undefined behaviour with respect to cursor position correction.
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param li_cursor_coords? LiCursorCoords
function M.fix_numbering(li_array, ispec_array, li_cursor_coords)
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
				and ispec_array[i - 1][current_ilevel].is_ordered ~= li.spec.is_ordered
			then
				index_counter[current_ilevel] = 1
			end

			if index_counter[current_ilevel] == nil then
				index_counter[current_ilevel] = 1
			end

			if li_cursor_coords ~= nil and li_cursor_coords.list_index == i then
				local prev_preamble_len = list_item.get_preamble_length(li)
				li.spec.index = index_counter[current_ilevel]
				if li_cursor_coords.col >= prev_preamble_len then
					local new_preamble_len = list_item.get_preamble_length(li)
					li_cursor_coords.col = li_cursor_coords.col + new_preamble_len - prev_preamble_len
				end
			else
				li.spec.index = index_counter[current_ilevel]
			end

			index_counter[current_ilevel] = index_counter[current_ilevel] + 1
			index_counter[current_ilevel + 1] = 1
		end
	end
end

---Modifies li_array and ispec_array in place to reflect an incremental indent spec update for a particular list item.
---The update is done by revising the indent spec of a particular item based on the one directly preceding it.
---This is useful if any edits to part of the list block have caused re-numberings and subsequent changes to indentation specs downstream.
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param line_num 1-indexed position of list item to update indentation for. Must be greater than 1.
function M.update_indent_specs(li_array, ispec_array, line_num)
	local current_li = li_array[line_num]
	local current_ispec = ispec_array[line_num]
	local current_ilevel = #current_ispec

	if current_ilevel == 0 then
		return
	end

	local lookbehind_li = li_array[line_num - 1]
	local lookbehind_ispec = ispec_array[line_num - 1]

	for i = 1, current_ilevel do
		if lookbehind_ispec[i] ~= nil then
			current_ispec[i].indent_spaces = lookbehind_ispec[i].indent_spaces
		else
			current_ispec[i].indent_spaces = list_item.get_nested_indent_spaces(lookbehind_li)
		end
	end

	current_li.spec.indent_spaces = current_ispec[current_ilevel].indent_spaces
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
