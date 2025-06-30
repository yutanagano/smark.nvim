local list_item = require("smark.list_item")
local format = require("smark.format")

local M = {}

---Edit li_array, ispec_array and rel_cursor_coords in place to reflect the entry of <CR> in insert mode at the specified relative cursor coordinates.
---Only call this function after fixing format.
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param rel_cursor_coords CursorCoords
function M.apply_insert_newline(li_array, ispec_array, rel_cursor_coords)
	local current_li = li_array[rel_cursor_coords.row1]
	local current_ispec = ispec_array[rel_cursor_coords.row1]

	if rel_cursor_coords.row1 == #li_array and current_li.content == "" then
		M.apply_unindent(li_array, ispec_array, rel_cursor_coords.row1, rel_cursor_coords.row1, rel_cursor_coords)
		return
	end

	local content_after_cursor = list_item.get_content_after_cursor(current_li, rel_cursor_coords.col0)
	list_item.truncate_content_at_cursor(current_li, rel_cursor_coords.col0)

	local new_li = list_item.get_empty_like(current_li)
	local new_ispec = format.get_indent_spec_like(current_ispec)
	new_li.content = content_after_cursor

	table.insert(li_array, rel_cursor_coords.row1 + 1, new_li)
	table.insert(ispec_array, rel_cursor_coords.row1 + 1, new_ispec)

	rel_cursor_coords.row1 = rel_cursor_coords.row1 + 1
	if rel_cursor_coords.col0 == 0 then
		current_li.indent_spaces = -1
	else
		rel_cursor_coords.col0 = list_item.get_preamble_length(new_li)
	end

	format.fix_numbering(li_array, ispec_array, rel_cursor_coords)
	for line_num = rel_cursor_coords.row1, #li_array do
		format.update_indent_specs(li_array, ispec_array, line_num)
	end

	if string.sub(current_li.content, -1) == ":" and content_after_cursor == "" then
		M.apply_indent(li_array, ispec_array, rel_cursor_coords.row1, rel_cursor_coords.row1, rel_cursor_coords)
	end
end

---Edit li_array, ispec_array and rel_cursor_coords in place to reflect the entry of "o" in normal mode at the specified relative cursor coordinates.
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param rel_cursor_coords CursorCoords
function M.apply_normal_o(li_array, ispec_array, rel_cursor_coords)
	local current_li = li_array[rel_cursor_coords.row1]
	local current_ispec = ispec_array[rel_cursor_coords.row1]

	if rel_cursor_coords.row1 == #li_array and current_li.content == "" then
		local new_li = list_item.get_empty_like(current_li)
		new_li.indent_spaces = -1
		table.insert(li_array, new_li)
		table.insert(ispec_array, {})
		rel_cursor_coords.row1 = rel_cursor_coords.row1 + 1
		rel_cursor_coords.col0 = 0
		return
	end

	local new_li = list_item.get_empty_like(current_li)
	local new_ispec = format.get_indent_spec_like(current_ispec)

	table.insert(li_array, rel_cursor_coords.row1 + 1, new_li)
	table.insert(ispec_array, rel_cursor_coords.row1 + 1, new_ispec)

	rel_cursor_coords.row1 = rel_cursor_coords.row1 + 1
	rel_cursor_coords.col0 = list_item.get_preamble_length(new_li)

	format.fix_numbering(li_array, ispec_array, rel_cursor_coords)
	for line_num = rel_cursor_coords.row1, #li_array do
		format.update_indent_specs(li_array, ispec_array, line_num)
	end

	if string.sub(current_li.content, -1) == ":" then
		M.apply_indent(li_array, ispec_array, rel_cursor_coords.row1, rel_cursor_coords.row1, rel_cursor_coords)
	end
end

---Edit li_array, ispec_array and rel_cursor_coords in place to reflect indenting one level the rows from start_row to end_row inclusive.
---Only call this function after first fixing format.
---Ensure that start_row and end_row are within bounds of the list block, otherwise this can cause undefined behaviour.
---Special case: Any indent applications from the root (first row) of an indent block will cause the entire block to indent.
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param start_row integer 1-indexed number of first line to unindent
---@param end_row integer 1-indexed number of last line to indent
---@param rel_cursor_coords? CursorCoords
function M.apply_indent(li_array, ispec_array, start_row, end_row, rel_cursor_coords)
	if start_row == 1 then
		for row1 = 1, #li_array do
			local current_li = li_array[row1]
			current_li.indent_spaces = current_li.indent_spaces + 2

			local current_ispec = ispec_array[row1]
			for _, ilspec in ipairs(current_ispec) do
				ilspec.indent_spaces = ilspec.indent_spaces + 2
			end
		end
		return
	end

	for row1 = start_row, #li_array do
		local current_li = li_array[row1]
		local current_ispec = ispec_array[row1]
		local current_ilevel = #current_ispec
		local lookbehind_li = li_array[math.max(1, row1 - 1)]
		local lookbehind_ispec = ispec_array[math.max(1, row1 - 1)]
		local lookbehind_ilevel = #lookbehind_ispec

		if row1 > start_row then
			format.update_indent_specs(li_array, ispec_array, row1)
		end

		if row1 <= end_row then
			local lookahead_ref_ispec = ispec_array[row1 + 1]
			local original_preamble_len = list_item.get_preamble_length(current_li)

			local new_ilevelspec
			if lookbehind_ilevel < current_ilevel then
				return
			elseif lookbehind_ilevel == current_ilevel then
				local is_ordered
				if lookahead_ref_ispec == nil or lookahead_ref_ispec[current_ilevel + 1] == nil then
					is_ordered = false
				else
					is_ordered = lookahead_ref_ispec[current_ilevel + 1].is_ordered
				end

				new_ilevelspec = {
					indent_spaces = list_item.get_nested_indent_spaces(lookbehind_li),
					is_ordered = is_ordered,
				}
			else
				new_ilevelspec = {
					indent_spaces = lookbehind_ispec[current_ilevel + 1].indent_spaces,
					is_ordered = lookbehind_ispec[current_ilevel + 1].is_ordered,
				}
			end

			current_ispec[current_ilevel].is_ordered = lookbehind_ispec[current_ilevel].is_ordered
			table.insert(current_ispec, new_ilevelspec)

			current_li.indent_spaces = new_ilevelspec.indent_spaces
			current_li.is_ordered = new_ilevelspec.is_ordered
			if
				rel_cursor_coords ~= nil
				and rel_cursor_coords.row1 == row1
				and rel_cursor_coords.col0 >= original_preamble_len
			then
				rel_cursor_coords.col0 = rel_cursor_coords.col0
					+ list_item.get_preamble_length(current_li)
					- original_preamble_len
			end

			format.fix_numbering(li_array, ispec_array, rel_cursor_coords)
		end
	end
end

---Edit li_array, ispec_array and rel_cursor_coords in place to reflect unindenting one level the rows from start_row to end_row inclusive.
---Only call this function after first fixing format.
---Ensure that start_row and end_row are within bounds of the list block, otherwise this can cause undefined behaviour.
---Special case: if the root list item is already indented (there are a positive number of spaces preceding the first bullet), and the selection to unindent contains a bullet at the root level, then the whole list block is unindented.
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param start_row integer 1-indexed number of first line to unindent
---@param end_row integer 1-indexed number of last line to indent
---@param rel_cursor_coords? CursorCoords
function M.apply_unindent(li_array, ispec_array, start_row, end_row, rel_cursor_coords)
	local root_indent_level = li_array[1].indent_spaces

	if root_indent_level > 0 then
		local min_ilevel_in_selection
		for row1 = start_row, end_row do
			local current_ilevel = li_array[row1].indent_spaces
			if min_ilevel_in_selection == nil or current_ilevel < min_ilevel_in_selection then
				min_ilevel_in_selection = current_ilevel
			end
		end

		if min_ilevel_in_selection == root_indent_level then
			local deindent_amount = math.min(2, root_indent_level)
			for row1 = 1, #li_array do
				local current_li = li_array[row1]
				current_li.indent_spaces = current_li.indent_spaces - deindent_amount

				local current_ispec = ispec_array[row1]
				for _, ilspec in ipairs(current_ispec) do
					ilspec.indent_spaces = ilspec.indent_spaces - deindent_amount
				end
			end
			return
		end
	end

	local original_end_row_ilevel = #ispec_array[end_row]
	local subtree_traversed = false

	for row1 = start_row, #li_array do
		local current_li = li_array[row1]
		local current_ispec = ispec_array[row1]

		if #current_ispec == 0 then
			return
		end

		if row1 > start_row then
			format.update_indent_specs(li_array, ispec_array, row1)
		end

		if row1 <= end_row or (not subtree_traversed and #current_ispec > original_end_row_ilevel) then
			local original_preamble_len = list_item.get_preamble_length(current_li)
			table.remove(current_ispec)

			if #current_ispec == 0 then
				assert(
					current_li.indent_spaces == 0,
					"The case of hyperindented list blocks should be handled in the special case block at the beginning"
				)
				current_li.indent_spaces = -1
			else
				current_li.indent_spaces = current_ispec[#current_ispec].indent_spaces
				current_li.is_ordered = current_ispec[#current_ispec].is_ordered
			end

			if
				rel_cursor_coords ~= nil
				and rel_cursor_coords.row1 == row1
				and rel_cursor_coords.col0 >= original_preamble_len
			then
				rel_cursor_coords.col0 = math.max(
					0,
					rel_cursor_coords.col0 + list_item.get_preamble_length(current_li) - original_preamble_len
				)
			end

			format.fix_numbering(li_array, ispec_array, rel_cursor_coords)
		else
			if not subtree_traversed then
				subtree_traversed = true
			end
		end
	end
end

---For a given region within a list block, toggle whether the list element type is ordered or unordered.
---This edits li_array and ispec_array in place to reflect the changes.
---The ordered type is toggled for the list element which the cursor is on, as well as all its contiguous siblings (list elements that are at the same indent level, and that are all children of the same parent list element).
---Only call this function after first fixing format.
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param rel_cursor_coords CursorCoords
function M.toggle_normal_ordered_type(li_array, ispec_array, rel_cursor_coords)
	local cursor_ispec = ispec_array[rel_cursor_coords.row1]
	local cursor_ilevel = #cursor_ispec
	local cursor_ordered = cursor_ispec[cursor_ilevel].is_ordered

	local current_row = rel_cursor_coords.row1
	local upper_bound_reached = false
	local upper_bound = 1
	while current_row >= 1 and not upper_bound_reached do
		local current_ispec = ispec_array[current_row]
		if #current_ispec < cursor_ilevel then
			upper_bound_reached = true
			upper_bound = current_row + 1
		else
			current_ispec[cursor_ilevel].is_ordered = not cursor_ordered
			if #current_ispec == cursor_ilevel then
				li_array[current_row].is_ordered = not cursor_ordered
			end
		end
		current_row = current_row - 1
	end

	current_row = rel_cursor_coords.row1 + 1
	local lower_bound_reached = false
	local lower_bound = #li_array
	while current_row <= #li_array and not lower_bound_reached do
		local current_ispec = ispec_array[current_row]
		if #current_ispec < cursor_ilevel then
			lower_bound_reached = true
			lower_bound = current_row - 1
		else
			current_ispec[cursor_ilevel].is_ordered = not cursor_ordered
			if #current_ispec == cursor_ilevel then
				li_array[current_row].is_ordered = not cursor_ordered
			end
		end
		current_row = current_row + 1
	end

	format.fix_numbering(li_array, ispec_array)

	for row1 = upper_bound + 1, lower_bound do
		format.update_indent_specs(li_array, ispec_array, row1)
	end
end

---For a given region within a list block, toggle whether the list element type is ordered or unordered.
---This edits li_array and ispec_array in place to reflect the changes.
---The ordered type is toggled for the list elements between start_row and end_row.
---The type is toggled to the opposite type from that of the list element that is under the cursor.
---Only call this function after first fixing format.
---Ensure that start_row and end_row are within bounds.
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param start_row integer 1-indexed number of first line to unindent
---@param end_row integer 1-indexed number of last line to indent
---@param rel_cursor_coords CursorCoords
function M.toggle_visual_ordered_type(li_array, ispec_array, start_row, end_row, rel_cursor_coords)
	local cursor_ispec = ispec_array[rel_cursor_coords.row1]
	local cursor_ordered = cursor_ispec[#cursor_ispec].is_ordered

	for current_row = start_row, end_row do
		li_array[current_row].is_ordered = not cursor_ordered
		local current_ispec = ispec_array[current_row]
		local current_ilevel = #current_ispec
		current_ispec[current_ilevel].is_ordered = not cursor_ordered

		for subtree_row = current_row + 1, #li_array do
			local subtree_ispec = ispec_array[subtree_row]
			local subtree_ilevel = #subtree_ispec

			if subtree_ilevel <= current_ilevel then
				break
			end

			subtree_ispec[current_ilevel].is_ordered = not cursor_ordered
		end
	end

	format.fix_numbering(li_array, ispec_array)

	for row1 = start_row + 1, #li_array do
		format.update_indent_specs(li_array, ispec_array, row1)
	end
end

---For a given task list element, toggle wether the task is completed or not.
---This edits li_array and ispec_array in place to reflect the changes.
---The completion of the task list element that the cursor is on will be toggled.
---If the current list element also has any children that are also task list elements, they will also all be toggled to the same comletion status as well.
---Only call this function after first fixing format.
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param rel_cursor_coords CursorCoords
function M.toggle_normal_checkbox(li_array, ispec_array, rel_cursor_coords)
	local cursor_li = li_array[rel_cursor_coords.row1]
	local cursor_ispec = ispec_array[rel_cursor_coords.row1]
	local cursor_ilevel = #cursor_ispec

	if not cursor_li.is_task then
		return
	end

	local toggle_to = not cursor_li.is_completed
	cursor_li.is_completed = toggle_to

	for current_row = rel_cursor_coords.row1 + 1, #li_array do
		local current_ispec = ispec_array[current_row]

		if #current_ispec <= cursor_ilevel then
			break
		end

		local current_li = li_array[current_row]
		if current_li.is_task then
			current_li.is_completed = toggle_to
		end
	end
end

---For a given region within a list block containing task list elements, toggle whether they are marked as completed.
---This edits li_array and ispec_array in place to reflect the changes.
---The ordered type is toggled for the list elements between start_row and end_row.
---For any list elements in the range that are not of a checkbox type, this results in a no-op.
---The completion status is toggled to the opposite type from that of the list element that is under the cursor.
---Only call this function after first fixing format.
---Ensure that start_row and end_row are within bounds.
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param start_row integer 1-indexed number of first line to unindent
---@param end_row integer 1-indexed number of last line to indent
---@param rel_cursor_coords CursorCoords
function M.toggle_visual_checkbox(li_array, ispec_array, start_row, end_row, rel_cursor_coords)
	local cursor_li = li_array[rel_cursor_coords.row1]

	local toggle_to = true
	if cursor_li.is_task then
		toggle_to = not cursor_li.is_completed
	end

	for current_row = start_row, end_row do
		local current_li = li_array[current_row]
		if current_li.is_task then
			current_li.is_completed = toggle_to
		end
	end
end

return M
