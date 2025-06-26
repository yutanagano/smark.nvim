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
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param start_row integer 1-indexed number of first line to unindent
---@param end_row integer 1-indexed number of last line to indent
---@param rel_cursor_coords? CursorCoords
function M.apply_indent(li_array, ispec_array, start_row, end_row, rel_cursor_coords)
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
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param start_row integer 1-indexed number of first line to unindent
---@param end_row integer 1-indexed number of last line to indent
---@param rel_cursor_coords? CursorCoords
function M.apply_unindent(li_array, ispec_array, start_row, end_row, rel_cursor_coords)
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
				if current_li.indent_spaces == 0 then
					current_li.indent_spaces = -1
				else
					current_ispec[1] = {
						indent_spaces = math.max(0, current_li.indent_spaces - 2),
						is_ordered = current_li.is_ordered,
					}
					current_li.indent_spaces = current_ispec[1].indent_spaces
				end
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

return M
