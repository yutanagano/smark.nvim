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

		if li_cursor_coords ~= nil and li_cursor_coords.list_index == li_index then
			if li_cursor_coords.col >= original_preamble_len then
				li_cursor_coords.col = li_cursor_coords.col + list_item.get_preamble_length(li) - original_preamble_len
			elseif li_cursor_coords.col >= list_item.get_preamble_length(li) then
				li_cursor_coords.col = list_item.get_preamble_length(li)
			end
		end
	end
end

---Only call this function _after_ fixing indentation, otherwise there will be
---undefined behaviour with respect to cursor position correction.
---@param li_block ListItem[]
---@param li_cursor_coords? LiCursorCoords
function M.fix_numbering(li_block, li_cursor_coords)
	local index_counter = { 1 }

	for li_index, li in ipairs(li_block) do
		local current_ilevel = #li.indent_rules

		if current_ilevel == 0 then
			index_counter[1] = 1
		else
			if
				li_index > 1
				and li_block[li_index - 1].indent_rules[current_ilevel] ~= nil
				and li_block[li_index - 1].indent_rules[current_ilevel].is_ordered
					~= li.indent_rules[current_ilevel].is_ordered
			then
				index_counter[current_ilevel] = 1
			end

			if index_counter[current_ilevel] == nil then
				index_counter[current_ilevel] = 1
			end

			if li_cursor_coords ~= nil and li_cursor_coords.list_index == li_index then
				local prev_preamble_len = list_item.get_preamble_length(li)
				li.position_number = index_counter[current_ilevel]
				if li_cursor_coords.col >= prev_preamble_len then
					local new_preamble_len = list_item.get_preamble_length(li)
					li_cursor_coords.col = li_cursor_coords.col + new_preamble_len - prev_preamble_len
				end
			else
				li.position_number = index_counter[current_ilevel]
			end

			index_counter[current_ilevel] = index_counter[current_ilevel] + 1
			index_counter[current_ilevel + 1] = 1
		end
	end
end

---Infers what the is_ordered status should be for all the list items within
---the specified range. is_ordered types for as many indent levels as possible
---are first inferred from the list item immediately preceding the range. If
---the list item immediately following the range has further indent level
---specified, then inferences for the is_ordered status for those levels are
---propagated backwards.
---
---@param li_block ListItem[]
---@param start_index integer
---@param end_index integer
---@param li_cursor_coords? LiCursorCoords
function M.propagate_ordered_type(li_block, start_index, end_index, li_cursor_coords)
	assert(start_index > 1, "ordered type propagation cannot be done for root")

	local lookbehind_li = li_block[start_index - 1]
	local lookahead_li = li_block[end_index + 1]

	for li_index = start_index, end_index do
		local current_li = li_block[li_index]
		local original_preamble_len

		if li_cursor_coords ~= nil and li_index == li_cursor_coords.list_index then
			original_preamble_len = list_item.get_preamble_length(current_li)
		end

		for ilevel_index = 1, #current_li.indent_rules do
			if lookbehind_li.indent_rules[ilevel_index] ~= nil then
				current_li.indent_rules[ilevel_index].is_ordered = lookbehind_li.indent_rules[ilevel_index].is_ordered
			elseif lookahead_li ~= nil and lookahead_li.indent_rules[ilevel_index] ~= nil then
				current_li.indent_rules[ilevel_index].is_ordered = lookahead_li.indent_rules[ilevel_index].is_ordered
			else
				current_li.indent_rules[ilevel_index].is_ordered = false
			end
		end

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

---Modifies li_block in place to reflect an incremental indent spec update for
---a particular range. The update is done by revising the indent rules of each
---item in the range based on the one directly preceding it. This is useful if
---any edits to part of the list block have caused re-numberings and subsequent
---changes to indentation specs downstream. li_cursor_coords is updated in
---place too if supplied.
---
---@param li_block ListItem[]
---@param start_index integer
---@param end_index integer
---@param li_cursor_coords? LiCursorCoords
function M.propagate_indent_rules(li_block, start_index, end_index, li_cursor_coords)
	for li_index = start_index, end_index do
		local current_li = li_block[li_index]
		local current_ilevel = #current_li.indent_rules

		if current_ilevel > 0 then
			local lookbehind_li = li_block[li_index - 1]
			local original_preamble_len

			if li_cursor_coords ~= nil and li_index == li_cursor_coords.list_index then
				original_preamble_len = list_item.get_preamble_length(current_li)
			end

			for ilevel_index = 1, current_ilevel do
				if lookbehind_li.indent_rules[ilevel_index] ~= nil then
					current_li.indent_rules[ilevel_index].num_spaces =
						lookbehind_li.indent_rules[ilevel_index].num_spaces
				else
					current_li.indent_rules[ilevel_index].num_spaces = list_item.get_nested_indent_spaces(lookbehind_li)
				end
			end

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

return M
