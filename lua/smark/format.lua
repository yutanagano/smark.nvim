local list_item = require("smark.list_item")

local M = {}

---Mutate array of list items in place to enforce correct indentation and
---numbering. Optionally mutate cursor coordinates in place if supplied. Note
---that this function is called automatically whenever smark reads from the
---current buffer and generates a lua table representation of the list block.
---
---@param li_block ListItem[]
---@param li_cursor_coords? LiCursorCoords
---@param original_preamble_len? integer The number of characters before content on the cursor line at read time. If not supplied, then is computed assuming that the list item had no extra whitespace characters before the content, which is not necessarily the case at read time.
function M.fix(li_block, li_cursor_coords, original_preamble_len)
	local index_counter = {}
	local prev_original_num_spaces

	for li_index, li in ipairs(li_block) do
		if li_cursor_coords ~= nil and li_cursor_coords.list_index == li_index and original_preamble_len == nil then
			original_preamble_len = list_item.get_preamble_length(li)
		end

		if li_index == 1 then
			li.indent_rules = { li.indent_rules[#li.indent_rules] }
			li.position_number = 1
			index_counter[1] = 2
			prev_original_num_spaces = li.indent_rules[1].num_spaces
		elseif #li.indent_rules == 0 then
			index_counter[1] = 1
			prev_original_num_spaces = nil
		else
			local li_original_irules = li.indent_rules[#li.indent_rules]
			local prev_li = li_block[li_index - 1]
			local top_level_set = false

			li.indent_rules = {}

			if li_original_irules.num_spaces == prev_original_num_spaces then
				li_original_irules.num_spaces = prev_li.indent_rules[#prev_li.indent_rules].num_spaces
			else
				prev_original_num_spaces = li_original_irules.num_spaces
			end

			local prev_nested_ispaces = list_item.get_nested_indent_spaces(prev_li)
			if li_original_irules.num_spaces >= prev_nested_ispaces then
				li.indent_rules[#prev_li.indent_rules + 1] = {
					is_ordered = li_original_irules.is_ordered,
					num_spaces = prev_nested_ispaces,
				}
				li.position_number = 1
				index_counter[#prev_li.indent_rules + 1] = 2
				top_level_set = true
			end

			for ilevel = #prev_li.indent_rules, 1, -1 do
				local is_ordered = prev_li.indent_rules[ilevel].is_ordered
				local num_spaces = prev_li.indent_rules[ilevel].num_spaces

				if li_original_irules.num_spaces >= num_spaces or ilevel == 1 then
					if not top_level_set then
						if is_ordered ~= li_original_irules.is_ordered then
							index_counter[ilevel] = 1
							is_ordered = li_original_irules.is_ordered
						end

						li.position_number = index_counter[ilevel]
						index_counter[ilevel] = index_counter[ilevel] + 1

						top_level_set = true
					end

					li.indent_rules[ilevel] = { is_ordered = is_ordered, num_spaces = num_spaces }
				end
			end
		end

		if
			li_cursor_coords ~= nil
			and li_cursor_coords.list_index == li_index
			and li_cursor_coords.col >= original_preamble_len
		then
			li_cursor_coords.col = li_cursor_coords.col + list_item.get_preamble_length(li) - original_preamble_len
		end
	end
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

---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param start_index integer
---@param end_index integer
---@param li_cursor_coords? LiCursorCoords
function M.propagate_ordered_type(li_array, ispec_array, start_index, end_index, li_cursor_coords)
	assert(start_index > 1, "ordered type propagation cannot be done for root")

	local lookbehind_ispec = ispec_array[start_index - 1]
	local lookahead_ispec = ispec_array[end_index + 1]

	local template_ispec = M.get_indent_spec_like(lookbehind_ispec)
	if lookahead_ispec ~= nil and #lookahead_ispec > #template_ispec then
		for i = #template_ispec + 1, #lookahead_ispec do
			template_ispec[i] = {
				is_ordered = lookahead_ispec[i].is_ordered,
				indent_spaces = lookahead_ispec[i].indent_spaces,
			}
		end
	end

	for li_index = start_index, end_index do
		local li = li_array[li_index]
		local ispec = ispec_array[li_index]
		local ilevel = #ispec
		local original_preamble_len

		if li_cursor_coords ~= nil and li_index == li_cursor_coords.list_index then
			original_preamble_len = list_item.get_preamble_length(li)
		end

		for ilevel_index = 1, ilevel do
			if template_ispec[ilevel_index] == nil then
				template_ispec[ilevel_index] = {
					is_ordered = false,
					indent_spaces = 0, -- placeholder
				}
			end

			ispec[ilevel_index].is_ordered = template_ispec[ilevel_index].is_ordered

			if ilevel_index == ilevel then
				li.spec.is_ordered = template_ispec[ilevel_index].is_ordered
			end
		end

		if
			li_cursor_coords ~= nil
			and li_index == li_cursor_coords.list_index
			and li_cursor_coords.col >= original_preamble_len
		then
			li_cursor_coords.col = li_cursor_coords.col + list_item.get_preamble_length(li) - original_preamble_len
		end
	end
end

---Modifies li_array and ispec_array in place to reflect an incremental indent spec update for a particular list item.
---The update is done by revising the indent spec of a particular item based on the one directly preceding it.
---This is useful if any edits to part of the list block have caused re-numberings and subsequent changes to indentation specs downstream.
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param start_index integer
---@param end_index integer
---@param li_cursor_coords? LiCursorCoords
function M.propagate_indent_specs(li_array, ispec_array, start_index, end_index, li_cursor_coords)
	for li_index = start_index, end_index do
		local current_li = li_array[li_index]
		local current_ispec = ispec_array[li_index]
		local current_ilevel = #current_ispec

		if current_ilevel > 0 then
			local lookbehind_li = li_array[li_index - 1]
			local lookbehind_ispec = ispec_array[li_index - 1]
			local original_preamble_len

			if li_cursor_coords ~= nil and li_index == li_cursor_coords.list_index then
				original_preamble_len = list_item.get_preamble_length(current_li)
			end

			for ilevel_index = 1, current_ilevel do
				if lookbehind_ispec[ilevel_index] ~= nil then
					current_ispec[ilevel_index].indent_spaces = lookbehind_ispec[ilevel_index].indent_spaces
				else
					current_ispec[ilevel_index].indent_spaces = list_item.get_nested_indent_spaces(lookbehind_li)
				end
			end

			current_li.spec.indent_spaces = current_ispec[current_ilevel].indent_spaces

			if
				li_cursor_coords ~= nil
				and li_index == li_cursor_coords.list_index
				and li_cursor_coords.col >= original_preamble_len
			then
				li_cursor_coords.col = li_cursor_coords.col
					+ list_item.get_preamble_length(current_li)
					- original_preamble_len
			end
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
