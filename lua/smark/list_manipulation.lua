require("smark.types")
local list_item = require("smark.list_item")
local format = require("smark.format")

local M = {}

---Edit li_array, ispec_array and rel_cursor_coords in place to reflect the entry of <CR> in insert mode at the specified relative cursor coordinates.
---Only call this function after fixing format.
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param li_cursor_coords LiCursorCoords
---@param read_time_preamble_len integer
function M.apply_insert_newline(li_array, ispec_array, li_cursor_coords, read_time_preamble_len)
	local current_li = li_array[li_cursor_coords.list_index]
	local current_ispec = ispec_array[li_cursor_coords.list_index]

	if li_cursor_coords.list_index == #li_array and list_item.content_is_empty(current_li) then
		M.apply_unindent(
			li_array,
			ispec_array,
			li_cursor_coords.list_index,
			li_cursor_coords.list_index,
			li_cursor_coords
		)
		return
	end

	local content_after_cursor =
		list_item.get_content_after_cursor(current_li, read_time_preamble_len, li_cursor_coords)
	list_item.truncate_content_at_cursor(current_li, read_time_preamble_len, li_cursor_coords)

	local new_li = list_item.get_empty_like(current_li)
	local new_ispec = format.get_indent_spec_like(current_ispec)
	new_li.content = content_after_cursor

	table.insert(li_array, li_cursor_coords.list_index + 1, new_li)
	table.insert(ispec_array, li_cursor_coords.list_index + 1, new_ispec)

	li_cursor_coords.list_index = li_cursor_coords.list_index + 1
	li_cursor_coords.content_lnum = 1

	if li_cursor_coords.col == 0 then
		current_li.spec.indent_spaces = -1
	else
		li_cursor_coords.col = list_item.get_preamble_length(new_li)
	end

	format.fix_numbering(li_array, ispec_array, li_cursor_coords)
	for i = li_cursor_coords.list_index, #li_array do
		format.update_indent_specs(li_array, ispec_array, i)
	end

	if list_item.content_ends_in_colon(current_li) and list_item.content_is_empty(new_li) then
		M.apply_indent(
			li_array,
			ispec_array,
			li_cursor_coords.list_index,
			li_cursor_coords.list_index,
			li_cursor_coords
		)
	end
end

---Edit li_array, ispec_array and li_cursor_coords in place to reflect the entry of "o" in normal mode at the specified relative cursor coordinates.
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param li_cursor_coords LiCursorCoords
function M.apply_normal_o(li_array, ispec_array, li_cursor_coords)
	local current_li = li_array[li_cursor_coords.list_index]
	local current_ispec = ispec_array[li_cursor_coords.list_index]

	if li_cursor_coords.list_index == #li_array and list_item.content_is_empty(current_li) then
		local new_li = list_item.get_empty_like(current_li)
		new_li.spec.indent_spaces = -1
		table.insert(li_array, new_li)
		table.insert(ispec_array, {})
		li_cursor_coords.list_index = li_cursor_coords.list_index + 1
		li_cursor_coords.content_lnum = 1
		li_cursor_coords.col = 0
		return
	end

	local new_li = list_item.get_empty_like(current_li)
	local new_ispec = format.get_indent_spec_like(current_ispec)

	table.insert(li_array, li_cursor_coords.list_index + 1, new_li)
	table.insert(ispec_array, li_cursor_coords.list_index + 1, new_ispec)

	li_cursor_coords.list_index = li_cursor_coords.list_index + 1
	li_cursor_coords.content_lnum = 1
	li_cursor_coords.col = list_item.get_preamble_length(new_li)

	format.fix_numbering(li_array, ispec_array, li_cursor_coords)
	for i = li_cursor_coords.list_index + 1, #li_array do
		format.update_indent_specs(li_array, ispec_array, i)
	end

	if list_item.content_ends_in_colon(current_li) then
		M.apply_indent(
			li_array,
			ispec_array,
			li_cursor_coords.list_index,
			li_cursor_coords.list_index,
			li_cursor_coords
		)
	end
end

---Edit li_array, ispec_array and li_cursor_coords (if supplied) in place to reflect indenting one level the rows from start_row to end_row inclusive.
---Only call this function after first fixing format.
---Ensure that start_row and end_row are within bounds of the list block, otherwise this can cause undefined behaviour.
---Special case: Any indent applications from the root (first row) of an indent block will cause the entire block to indent.
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param start_index integer index of first list item to unindent
---@param end_index integer index of last list item to indent
---@param li_cursor_coords? LiCursorCoords
function M.apply_indent(li_array, ispec_array, start_index, end_index, li_cursor_coords)
	if start_index == 1 then
		for i = 1, #li_array do
			local current_li = li_array[i]
			current_li.spec.indent_spaces = current_li.spec.indent_spaces + 2

			local current_ispec = ispec_array[i]
			for _, ilspec in ipairs(current_ispec) do
				ilspec.indent_spaces = ilspec.indent_spaces + 2
			end
		end
		return
	end

	for i = start_index, #li_array do
		local current_li = li_array[i]
		local current_ispec = ispec_array[i]
		local current_ilevel = #current_ispec
		local lookbehind_li = li_array[math.max(1, i - 1)]
		local lookbehind_ispec = ispec_array[math.max(1, i - 1)]
		local lookbehind_ilevel = #lookbehind_ispec

		if i > start_index then
			format.update_indent_specs(li_array, ispec_array, i)
		end

		if i <= end_index then
			local lookahead_ref_ispec = ispec_array[i + 1]
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

			current_li.spec.indent_spaces = new_ilevelspec.indent_spaces
			current_li.spec.is_ordered = new_ilevelspec.is_ordered

			if
				li_cursor_coords ~= nil
				and li_cursor_coords.list_index == i
				and li_cursor_coords.col >= original_preamble_len
			then
				li_cursor_coords.col = li_cursor_coords.col
					+ list_item.get_preamble_length(current_li)
					- original_preamble_len
			end

			format.fix_numbering(li_array, ispec_array, li_cursor_coords)
		end
	end
end

---Edit li_array, ispec_array and li_cursor_coords in place to reflect unindenting one level the rows from start_row to end_row inclusive.
---Only call this function after first fixing format.
---Ensure that start_row and end_row are within bounds of the list block, otherwise this can cause undefined behaviour.
---Special case: if the root list item is already indented (there are a positive number of spaces preceding the first bullet), and the selection to unindent contains a bullet at the root level, then the whole list block is unindented.
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param start_index integer 1-indexed number of first line to unindent
---@param end_index integer 1-indexed number of last line to indent
---@param li_cursor_coords? LiCursorCoords
function M.apply_unindent(li_array, ispec_array, start_index, end_index, li_cursor_coords)
	local root_indent_spaces = li_array[1].spec.indent_spaces

	if root_indent_spaces > 0 then
		local min_ilevel_in_selection
		for i = start_index, end_index do
			local current_ispaces = li_array[i].spec.indent_spaces
			if min_ilevel_in_selection == nil or current_ispaces < min_ilevel_in_selection then
				min_ilevel_in_selection = current_ispaces
			end
		end

		if min_ilevel_in_selection == root_indent_spaces then
			local deindent_amount = math.min(2, root_indent_spaces)
			for i = 1, #li_array do
				local current_li = li_array[i]
				current_li.spec.indent_spaces = current_li.spec.indent_spaces - deindent_amount

				local current_ispec = ispec_array[i]
				for _, ilspec in ipairs(current_ispec) do
					ilspec.indent_spaces = ilspec.indent_spaces - deindent_amount
				end
			end
			return
		end
	end

	local original_end_row_ilevel = #ispec_array[end_index]
	local subtree_traversed = false

	for i = start_index, #li_array do
		local current_li = li_array[i]
		local current_ispec = ispec_array[i]

		if #current_ispec == 0 then
			return
		end

		if i > start_index then
			format.update_indent_specs(li_array, ispec_array, i)
		end

		if i <= end_index or (not subtree_traversed and #current_ispec > original_end_row_ilevel) then
			local original_preamble_len = list_item.get_preamble_length(current_li)
			table.remove(current_ispec)

			if #current_ispec == 0 then
				assert(
					current_li.spec.indent_spaces == 0,
					"The case of hyperindented list blocks should be handled in the special case block at the beginning"
				)
				current_li.spec.indent_spaces = -1
			else
				current_li.spec.indent_spaces = current_ispec[#current_ispec].indent_spaces
				current_li.spec.is_ordered = current_ispec[#current_ispec].is_ordered
			end

			if
				li_cursor_coords ~= nil
				and li_cursor_coords.list_index == i
				and li_cursor_coords.col >= original_preamble_len
			then
				li_cursor_coords.col = math.max(
					0,
					li_cursor_coords.col + list_item.get_preamble_length(current_li) - original_preamble_len
				)
			end

			format.fix_numbering(li_array, ispec_array, li_cursor_coords)
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
---@param li_cursor_coords LiCursorCoords
function M.toggle_normal_ordered_type(li_array, ispec_array, li_cursor_coords)
	local cursor_ispec = ispec_array[li_cursor_coords.list_index]
	local cursor_ilevel = #cursor_ispec
	local cursor_ordered = cursor_ispec[cursor_ilevel].is_ordered

	local i = li_cursor_coords.list_index
	local upper_bound_reached = false
	local upper_bound = 1
	while i >= 1 and not upper_bound_reached do
		local current_ispec = ispec_array[i]
		if #current_ispec < cursor_ilevel then
			upper_bound_reached = true
			upper_bound = i + 1
		else
			current_ispec[cursor_ilevel].is_ordered = not cursor_ordered
			if #current_ispec == cursor_ilevel then
				li_array[i].spec.is_ordered = not cursor_ordered
			end
		end
		i = i - 1
	end

	i = li_cursor_coords.list_index + 1
	local lower_bound_reached = false
	local lower_bound = #li_array
	while i <= #li_array and not lower_bound_reached do
		local current_ispec = ispec_array[i]
		if #current_ispec < cursor_ilevel then
			lower_bound_reached = true
			lower_bound = i - 1
		else
			current_ispec[cursor_ilevel].is_ordered = not cursor_ordered
			if #current_ispec == cursor_ilevel then
				li_array[i].spec.is_ordered = not cursor_ordered
			end
		end
		i = i + 1
	end

	format.fix_numbering(li_array, ispec_array)

	for index = upper_bound + 1, lower_bound do
		format.update_indent_specs(li_array, ispec_array, index)
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
---@param start_index integer 1-indexed number of first line to unindent
---@param end_index integer 1-indexed number of last line to indent
---@param li_cursor_coords LiCursorCoords
function M.toggle_visual_ordered_type(li_array, ispec_array, start_index, end_index, li_cursor_coords)
	local cursor_ispec = ispec_array[li_cursor_coords.list_index]
	local cursor_ordered = cursor_ispec[#cursor_ispec].is_ordered

	for i = start_index, end_index do
		li_array[i].spec.is_ordered = not cursor_ordered
		local current_ispec = ispec_array[i]
		local current_ilevel = #current_ispec
		current_ispec[current_ilevel].is_ordered = not cursor_ordered

		for subtree_row = i + 1, #li_array do
			local subtree_ispec = ispec_array[subtree_row]
			local subtree_ilevel = #subtree_ispec

			if subtree_ilevel <= current_ilevel then
				break
			end

			subtree_ispec[current_ilevel].is_ordered = not cursor_ordered
		end
	end

	format.fix_numbering(li_array, ispec_array)

	for i = start_index + 1, #li_array do
		format.update_indent_specs(li_array, ispec_array, i)
	end
end

---For a given task list element, toggle wether the task is completed or not.
---This edits li_array and ispec_array in place to reflect the changes.
---The completion of the task list element that the cursor is on will be toggled.
---If the current list element also has any children that are also task list elements, they will also all be toggled to the same comletion status as well.
---Only call this function after first fixing format.
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param li_cursor_coords LiCursorCoords
function M.toggle_normal_checkbox(li_array, ispec_array, li_cursor_coords)
	local cursor_li = li_array[li_cursor_coords.list_index]
	local cursor_ispec = ispec_array[li_cursor_coords.list_index]
	local cursor_ilevel = #cursor_ispec

	if not cursor_li.spec.is_task then
		return
	end

	local toggle_to = not cursor_li.spec.is_completed
	cursor_li.spec.is_completed = toggle_to

	for i = li_cursor_coords.list_index + 1, #li_array do
		local current_ispec = ispec_array[i]

		if #current_ispec <= cursor_ilevel then
			break
		end

		local child_li = li_array[i]
		if child_li.spec.is_task then
			child_li.spec.is_completed = toggle_to
		end
	end

	if cursor_ilevel == 1 then
		return
	end

	local parent
	local incomplete_sibling_found = false

	if toggle_to == false then
		incomplete_sibling_found = true
	end

	for i = li_cursor_coords.list_index - 1, 1, -1 do
		local current_ispec = ispec_array[i]
		local current_li = li_array[i]

		if
			not incomplete_sibling_found
			and #current_ispec == cursor_ilevel
			and current_li.spec.is_task
			and not current_li.spec.is_completed
		then
			incomplete_sibling_found = true
		end

		if #current_ispec < cursor_ilevel then
			parent = current_li
			break
		end
	end

	if incomplete_sibling_found then
		parent.spec.is_completed = false
		return
	end

	for i = li_cursor_coords.list_index + 1, #li_array do
		local current_ispec = ispec_array[i]
		local current_li = li_array[i]

		if
			not incomplete_sibling_found
			and #current_ispec == cursor_ilevel
			and current_li.spec.is_task
			and not current_li.spec.is_completed
		then
			incomplete_sibling_found = true
			break
		end

		if #current_ispec < cursor_ilevel then
			break
		end
	end

	if incomplete_sibling_found then
		parent.spec.is_completed = false
	else
		parent.spec.is_completed = true
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
---@param li_cursor_coords LiCursorCoords
function M.toggle_visual_checkbox(li_array, ispec_array, start_row, end_row, li_cursor_coords)
	local cursor_li = li_array[li_cursor_coords.list_index]

	local toggle_to = true
	if cursor_li.spec.is_task then
		toggle_to = not cursor_li.spec.is_completed
	end

	for i = start_row, end_row do
		local current_li = li_array[i]
		if current_li.spec.is_task then
			current_li.spec.is_completed = toggle_to
		end
	end
end

return M
