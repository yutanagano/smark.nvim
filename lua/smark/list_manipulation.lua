local list_item = require("smark.list_item")
local format = require("smark.format")

local M = {}

---Edit li_array, ispec_array and li_cursor_coords in place to reflect the
---entry of <CR> in insert mode at the specified cursor coordinates. Only call
---this function after fixing format.
---
---@param li_block ListItem[]
---@param li_cursor_coords LiCursorCoords
function M.apply_insert_newline(li_block, li_cursor_coords)
	local current_li = li_block[li_cursor_coords.list_index]

	if li_cursor_coords.list_index == #li_block and list_item.content_is_empty(current_li) then
		M.apply_unindent(li_block, li_cursor_coords.list_index, li_cursor_coords.list_index, li_cursor_coords)
		return
	end

	local content_after_cursor = list_item.get_content_after_cursor(current_li, li_cursor_coords)
	list_item.truncate_content_at_cursor(current_li, li_cursor_coords)

	local new_li = list_item.get_empty_like(current_li)
	new_li.content = content_after_cursor

	table.insert(li_block, li_cursor_coords.list_index + 1, new_li)

	li_cursor_coords.list_index = li_cursor_coords.list_index + 1
	li_cursor_coords.content_lnum = 1

	if li_cursor_coords.col == 0 then
		current_li.indent_rules = {}
	else
		li_cursor_coords.col = list_item.get_preamble_length(new_li)
	end

	format.fix_numbering(li_block, li_cursor_coords)
	format.propagate_indent_rules(li_block, li_cursor_coords.list_index, #li_block, li_cursor_coords)

	if list_item.content_ends_in_colon(current_li) and list_item.content_is_empty(new_li) then
		M.apply_indent(li_block, li_cursor_coords.list_index, li_cursor_coords.list_index, li_cursor_coords)
	end
end

---Edit li_array and li_cursor_coords in place to reflect the entry of "o" in
---normal mode at the specified relative cursor coordinates.
---
---@param li_block ListItem[]
---@param li_cursor_coords LiCursorCoords
function M.apply_normal_o(li_block, li_cursor_coords)
	local current_li = li_block[li_cursor_coords.list_index]

	if li_cursor_coords.list_index == #li_block and list_item.content_is_empty(current_li) then
		local new_li = list_item.get_empty_like(current_li)
		new_li.indent_rules = {}
		table.insert(li_block, new_li)
		li_cursor_coords.list_index = li_cursor_coords.list_index + 1
		li_cursor_coords.content_lnum = 1
		li_cursor_coords.col = 0
		return
	end

	local new_li = list_item.get_empty_like(current_li)
	table.insert(li_block, li_cursor_coords.list_index + 1, new_li)

	li_cursor_coords.list_index = li_cursor_coords.list_index + 1
	li_cursor_coords.content_lnum = 1
	li_cursor_coords.col = list_item.get_preamble_length(new_li)

	format.fix_numbering(li_block, li_cursor_coords)
	format.propagate_indent_rules(li_block, li_cursor_coords.list_index + 1, #li_block, li_cursor_coords)

	if list_item.content_ends_in_colon(current_li) then
		M.apply_indent(li_block, li_cursor_coords.list_index, li_cursor_coords.list_index, li_cursor_coords)
	end
end

---Edit li_block and li_cursor_coords (if supplied) in place to reflect
---indenting one level the list items from start_index to end_index inclusive.
---If the first item to be indented has no siblings above it, it will result in
---a no-op. The one exception to this is the root (first row) of a list block,
---where the entire block will be indented. Only call this function after first
---fixing format. Ensure that start_index and end_index are within bounds of
---the list block, otherwise this can cause undefined behaviour.
---
---@param li_block ListItem[]
---@param start_index integer index of first list item to unindent
---@param end_index integer index of last list item to indent
---@param li_cursor_coords? LiCursorCoords
function M.apply_indent(li_block, start_index, end_index, li_cursor_coords)
	if start_index == 1 then
		for li_index = 1, #li_block do
			local current_li = li_block[li_index]
			local original_preamble_len = list_item.get_preamble_length(current_li)

			for _, irule in ipairs(current_li.indent_rules) do
				irule.num_spaces = irule.num_spaces + 2
			end

			if
				li_cursor_coords ~= nil
				and li_cursor_coords.list_index == li_index
				and li_cursor_coords.col >= original_preamble_len
			then
				li_cursor_coords.col = li_cursor_coords.col + 2
			end
		end
		return
	end

	for li_index = start_index, end_index do
		if li_index == start_index and #li_block[li_index].indent_rules > #li_block[li_index - 1].indent_rules then
			return
		end

		table.insert(li_block[li_index].indent_rules, {
			is_ordered = li_block[li_index].indent_rules[#li_block[li_index].indent_rules].is_ordered, -- to be inferred later
			num_spaces = li_block[li_index].indent_rules[#li_block[li_index].indent_rules].num_spaces, -- to be inferred later
		})
	end

	format.propagate_ordered_type(li_block, start_index, end_index, li_cursor_coords)
	format.fix_numbering(li_block, li_cursor_coords)
	format.propagate_indent_rules(li_block, start_index, #li_block, li_cursor_coords)
	format.sanitise_completion_statuses(li_block)
end

---Edit li_block and li_cursor_coords (if supplied) in place to reflect
---unindenting one level the list items from start_index to end_index
---inclusive. Only call this function after first fixing format. Ensure that
---start_index and end_index are within bounds of the list block, otherwise
---this can cause undefined behaviour.
---
---Special case: if the root list item is already indented (there are a
---positive number of spaces preceding the first bullet), and the selection to
---unindent contains a bullet at the root level, then the whole list block is
---unindented.
---
---@param li_block ListItem[]
---@param start_index integer 1-indexed number of first line to unindent
---@param end_index integer 1-indexed number of last line to indent
---@param li_cursor_coords? LiCursorCoords
function M.apply_unindent(li_block, start_index, end_index, li_cursor_coords)
	local root_num_spaces = li_block[1].indent_rules[#li_block[1].indent_rules].num_spaces

	if root_num_spaces > 0 then
		local min_ilevel_in_selection
		for li_index = start_index, end_index do
			local current_ispaces = li_block[li_index].indent_rules[#li_block[li_index].indent_rules].num_spaces
			if min_ilevel_in_selection == nil or current_ispaces < min_ilevel_in_selection then
				min_ilevel_in_selection = current_ispaces
			end
		end

		if min_ilevel_in_selection == root_num_spaces then
			local deindent_amount = math.min(2, root_num_spaces)
			for li_index = 1, #li_block do
				local current_li = li_block[li_index]
				for _, irule in ipairs(current_li.indent_rules) do
					irule.num_spaces = irule.num_spaces - deindent_amount
				end
			end
			return
		end
	end

	local original_end_index_ilevel = #li_block[end_index].indent_rules
	for li_index = start_index, #li_block do
		local current_li = li_block[li_index]

		if li_index > end_index and #current_li.indent_rules <= math.max(1, original_end_index_ilevel) then
			break
		end

		table.remove(current_li.indent_rules)
	end

	format.fix_numbering(li_block, li_cursor_coords)
	format.propagate_indent_rules(li_block, start_index + 1, #li_block, li_cursor_coords)
	format.sanitise_completion_statuses(li_block)
end

---For a given region within a list block, toggle whether the list element type
---is ordered or unordered. This edits li_block in place to reflect the
---changes. The ordered type is toggled for the list element which the cursor
---is on, as well as all its contiguous siblings (list elements that are at the
---same indent level, and that are all children of the same parent list
---element). Only call this function after first fixing format.
---
---@param li_block ListItem[]
---@param li_cursor_coords LiCursorCoords
function M.toggle_normal_ordered_type(li_block, li_cursor_coords)
	local cursor_li = li_block[li_cursor_coords.list_index]
	local cursor_ilevel = #cursor_li.indent_rules
	local cursor_ordered = cursor_li.indent_rules[cursor_ilevel].is_ordered

	local upper_bound, lower_bound

	for li_index = li_cursor_coords.list_index, 1, -1 do
		local current_li = li_block[li_index]
		if #current_li.indent_rules < cursor_ilevel then
			upper_bound = li_index + 1
			break
		else
			current_li.indent_rules[cursor_ilevel].is_ordered = not cursor_ordered
			if li_index == 1 then
				upper_bound = 1
			end
		end
	end

	if li_cursor_coords.list_index == #li_block then
		lower_bound = #li_block
	else
		for li_index = li_cursor_coords.list_index + 1, #li_block do
			local current_li = li_block[li_index]
			if #current_li.indent_rules < cursor_ilevel then
				lower_bound = li_index - 1
				break
			else
				current_li.indent_rules[cursor_ilevel].is_ordered = not cursor_ordered
				if li_index == #li_block then
					lower_bound = #li_block
				end
			end
		end
	end

	format.fix_numbering(li_block)
	format.propagate_indent_rules(li_block, upper_bound + 1, lower_bound)
end

---For a given region within a list block, toggle whether the list element type
---is ordered or unordered. This edits li_block in place to reflect the
---changes. The ordered type is toggled for the list elements between
---start_index and end_index. The type is toggled to the opposite type from
---that of the list element that is under the cursor. Only call this function
---after first fixing format. Ensure that start_index and end_index are within
---bounds.
---
---@param li_block ListItem[]
---@param start_index integer 1-indexed number of first line to unindent
---@param end_index integer 1-indexed number of last line to indent
---@param li_cursor_coords LiCursorCoords
function M.toggle_visual_ordered_type(li_block, start_index, end_index, li_cursor_coords)
	local cursor_li = li_block[li_cursor_coords.list_index]
	local target_ordered_status = not cursor_li.indent_rules[#cursor_li.indent_rules].is_ordered

	for li_index = start_index, end_index do
		local current_li = li_block[li_index]
		local current_ilevel = #current_li.indent_rules

		current_li.indent_rules[current_ilevel].is_ordered = target_ordered_status

		for subtree_index = li_index + 1, #li_block do
			local subtree_li = li_block[subtree_index]
			local subtree_ilevel = #subtree_li.indent_rules

			if subtree_ilevel <= current_ilevel then
				break
			end

			subtree_li.indent_rules[current_ilevel].is_ordered = target_ordered_status
		end
	end

	format.fix_numbering(li_block)
	format.propagate_indent_rules(li_block, start_index + 1, #li_block)
end

---For a given task list element, toggle wether the task is completed or not.
---This edits li_block in place to reflect the changes. The completion of the
---task list element that the cursor is on will be toggled. If the current list
---element also has any children that are also task list elements, they will
---also all be toggled to the same comletion status as well. Only call this
---function after first fixing format.
---
---@param li_block ListItem[]
---@param li_cursor_coords LiCursorCoords
function M.toggle_normal_checkbox(li_block, li_cursor_coords)
	local cursor_li = li_block[li_cursor_coords.list_index]
	local cursor_ilevel = #cursor_li.indent_rules
	local target_completion_status = not cursor_li.is_completed

	if not cursor_li.is_task then
		return
	end

	cursor_li.is_completed = target_completion_status

	for li_index = li_cursor_coords.list_index + 1, #li_block do
		local child_li = li_block[li_index]

		if #child_li.indent_rules <= cursor_ilevel then
			break
		end

		if child_li.is_task then
			child_li.is_completed = target_completion_status
		end
	end

	if cursor_ilevel == 1 then
		return
	end

	format.sanitise_completion_statuses(li_block)
end

---For a given region within a list block containing task list elements, toggle
---whether they are marked as completed. This edits li_block in place to
---reflect the changes. The ordered type is toggled for the list elements
---between start_index and end_index. For any list elements in the range that
---are not of a checkbox type, this results in a no-op. The completion status
---is toggled to the opposite type from that of the list element that is under
---the cursor. Only call this function after first fixing format. Ensure that
---start_index and end_index are within bounds.
---
---@param li_block ListItem[]
---@param start_row integer 1-indexed number of first line to unindent
---@param end_row integer 1-indexed number of last line to indent
---@param li_cursor_coords LiCursorCoords
function M.toggle_visual_checkbox(li_block, start_row, end_row, li_cursor_coords)
	local cursor_li = li_block[li_cursor_coords.list_index]
	local target_completion_status = not cursor_li.is_completed
	local current_parent_task_li = nil

	for li_index = start_row, end_row do
		local current_li = li_block[li_index]
		if current_li.is_task then
			current_li.is_completed = target_completion_status
			if current_parent_task_li == nil or #current_li.indent_rules <= #current_parent_task_li.indent_rules then
				current_parent_task_li = current_li
			end
		end
	end

	if current_parent_task_li ~= nil then
		for li_index = end_row + 1, #li_block do
			local child_li = li_block[li_index]

			if #child_li.indent_rules <= #current_parent_task_li.indent_rules then
				break
			end

			if child_li.is_task then
				child_li.is_completed = target_completion_status
			end
		end
	end

	format.sanitise_completion_statuses(li_block)
end

return M
