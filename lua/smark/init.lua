---@class TextBlockBounds
---@field upper integer 1-indexed upper bound line number
---@field lower integer 1-indexed lower bound line number

local list_item = require("smark.list_item")
local format = require("smark.format")

local smark = {}
local smark_private = {}

smark.setup = function(_)
	-- nothing for now
end

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "markdown", "text" },
	callback = function()
		vim.keymap.set("i", "<CR>", smark_private.callback_insert_newline, { buffer = true })
		vim.keymap.set("i", "<C-t>", smark_private.callback_insert_indent, { buffer = true })
		vim.keymap.set("i", "<C-d>", smark_private.callback_insert_unindent, { buffer = true })
		vim.keymap.set("n", ">>", smark_private.callback_normal_indent, { buffer = true })
		vim.keymap.set("n", "<<", smark_private.callback_normal_unindent, { buffer = true })
		vim.keymap.set("n", "o", smark_private.callback_normal_o, { buffer = true })
	end,
})

function smark_private.callback_insert_newline()
	local cursor_coords, bounds, li_array = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		local newline = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
		vim.api.nvim_feedkeys(newline, "n", false)
		return
	end

	local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
	local ispec_array = format.fix(li_array, rel_cursor_coords)
	smark_private.apply_insert_newline(li_array, ispec_array, rel_cursor_coords)
	format.fix_numbering(li_array, ispec_array, rel_cursor_coords)

	smark_private.draw_list_items(li_array, bounds)

	cursor_coords = { row1 = rel_cursor_coords.row1 + bounds.upper - 1, col0 = rel_cursor_coords.col0 }
	vim.api.nvim_win_set_cursor(0, { cursor_coords.row1, cursor_coords.col0 })
end

function smark_private.callback_insert_indent()
	local cursor_coords, bounds, li_array = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		local ctrl_t = vim.api.nvim_replace_termcodes("<C-t>", true, false, true)
		vim.api.nvim_feedkeys(ctrl_t, "n", false)
		return
	end

	local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
	smark_private.apply_indent(li_array, rel_cursor_coords.row1, rel_cursor_coords.row1, rel_cursor_coords)
	smark_private.draw_list_items(li_array, bounds)

	cursor_coords = { row1 = rel_cursor_coords.row1 + bounds.upper - 1, col0 = rel_cursor_coords.col0 }
	vim.api.nvim_win_set_cursor(0, { cursor_coords.row1, cursor_coords.col0 })
end

function smark_private.callback_insert_unindent()
	local cursor_coords, bounds, li_array = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		local ctrl_d = vim.api.nvim_replace_termcodes("<C-d>", true, false, true)
		vim.api.nvim_feedkeys(ctrl_d, "n", false)
		return
	end

	local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
	smark_private.apply_unindent(li_array, rel_cursor_coords.row1, rel_cursor_coords.row1, rel_cursor_coords)
	smark_private.draw_list_items(li_array, bounds)

	cursor_coords = { row1 = rel_cursor_coords.row1 + bounds.upper - 1, col0 = rel_cursor_coords.col0 }
	vim.api.nvim_win_set_cursor(0, { cursor_coords.row1, cursor_coords.col0 })
end

function smark_private.callback_normal_indent()
	local cursor_coords, bounds, li_array = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		local indent = vim.api.nvim_replace_termcodes(string.format("%d>>", vim.v.count1), true, false, true)
		vim.api.nvim_feedkeys(indent, "n", false)
		return
	end

	local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
	local start_row = rel_cursor_coords.row1
	local end_row = math.min(#li_array, start_row + vim.v.count1 - 1)
	smark_private.apply_indent(li_array, start_row, end_row, rel_cursor_coords)
	smark_private.draw_list_items(li_array, bounds)
end

function smark_private.callback_normal_unindent()
	local cursor_coords, bounds, li_array = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		local unindent = vim.api.nvim_replace_termcodes(string.format("%d<<", vim.v.count1), true, false, true)
		vim.api.nvim_feedkeys(unindent, "n", false)
		return
	end

	local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
	local start_row = rel_cursor_coords.row1
	local end_row = math.min(#li_array, start_row + vim.v.count1 - 1)
	smark_private.apply_unindent(li_array, start_row, end_row)
	smark_private.draw_list_items(li_array, bounds)
end

function smark_private.callback_normal_o()
	local cursor_coords, bounds, li_array = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		vim.api.nvim_feedkeys("o", "n", false)
		return
	end

	local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
	local ispec_array = format.fix(li_array, rel_cursor_coords)
	smark_private.apply_normal_o(li_array, ispec_array, rel_cursor_coords)
	format.fix_numbering(li_array, ispec_array, rel_cursor_coords)
	smark_private.draw_list_items(li_array, bounds)

	cursor_coords = { row1 = rel_cursor_coords.row1 + bounds.upper - 1, col0 = rel_cursor_coords.col0 }
	vim.api.nvim_win_set_cursor(0, { cursor_coords.row1, cursor_coords.col0 })
	vim.cmd("startinsert!")
end

---@return CursorCoords
---@return TextBlockBounds|nil # Boundaries of containing list block, nil if cursor not in list block
---@return ListItem[] # Array of list items detected inside the list block
function smark_private.get_list_block_around_cursor()
	local cursor_row1, cursor_col0 = table.unpack(vim.api.nvim_win_get_cursor(0))
	local cursor_coords = { row1 = cursor_row1, col0 = cursor_col0 }

	local li = list_item.from_line(cursor_row1)

	if li == nil then
		return cursor_coords, nil, {}
	end

	local bounds = { upper = cursor_row1, lower = cursor_row1 }
	local upper_bound_found, lower_bound_found = false, false
	local li_array = {}

	table.insert(li_array, li)

	while not upper_bound_found do
		if bounds.upper == 1 then
			upper_bound_found = true
		else
			li = list_item.from_line(bounds.upper - 1)
			if li == nil then
				upper_bound_found = true
			else
				bounds.upper = bounds.upper - 1
				table.insert(li_array, 1, li)
			end
		end
	end

	while not lower_bound_found do
		if bounds.lower == vim.api.nvim_buf_line_count(0) then
			lower_bound_found = true
		else
			li = list_item.from_line(bounds.lower + 1)
			if li == nil then
				lower_bound_found = true
			else
				bounds.lower = bounds.lower + 1
				table.insert(li_array, li)
			end
		end
	end

	return cursor_coords, bounds, li_array
end

---Edit li_array, ispec_array and rel_cursor_coords in place to reflect the entry of <CR> in insert mode at the specified relative cursor coordinates.
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param rel_cursor_coords CursorCoords
function smark_private.apply_insert_newline(li_array, ispec_array, rel_cursor_coords)
	local current_li = li_array[rel_cursor_coords.row1]
	local current_ispec = ispec_array[rel_cursor_coords.row1]

	if rel_cursor_coords.col0 < current_li.read_time_preamble_length then
		local new_li = list_item.get_empty_like(current_li)
		local new_ispec = format.get_indent_spec_like(current_ispec)
		table.insert(li_array, rel_cursor_coords.row1, new_li)
		table.insert(ispec_array, rel_cursor_coords.row1, new_ispec)
		rel_cursor_coords.row1 = rel_cursor_coords.row1 + 1
		return
	end

	if rel_cursor_coords.row1 == #li_array and current_li.content == "" then
		current_li.indent_spaces = -1
		rel_cursor_coords.col0 = 0
		return
	end

	local content_after_cursor = list_item.get_content_after_cursor(current_li, rel_cursor_coords.col0)
	list_item.truncate_content_at_cursor(current_li, rel_cursor_coords.col0)

	local new_li = list_item.get_empty_like(current_li)
	local new_ispec = format.get_indent_spec_like(current_ispec)
	new_li.content = content_after_cursor
	if string.sub(current_li.content, -1) == ":" and content_after_cursor == "" then
		local new_ispaces = list_item.get_nested_indent_spaces(current_li)
		new_li.indent_spaces = new_ispaces
		new_li.is_ordered = false
		table.insert(new_ispec, { indent_spaces = new_ispaces, is_ordered = new_li.is_ordered })
	end
	table.insert(li_array, rel_cursor_coords.row1 + 1, new_li)
	table.insert(ispec_array, rel_cursor_coords.row1 + 1, new_ispec)

	rel_cursor_coords.row1 = rel_cursor_coords.row1 + 1
	rel_cursor_coords.col0 = list_item.get_preamble_length(new_li)
end

---Edit li_array, ispec_array and rel_cursor_coords in place to reflect the entry of "o" in normal mode at the specified relative cursor coordinates.
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param rel_cursor_coords CursorCoords
function smark_private.apply_normal_o(li_array, ispec_array, rel_cursor_coords)
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
	if string.sub(current_li.content, -1) == ":" then
		local new_ispaces = list_item.get_nested_indent_spaces(current_li)
		new_li.indent_spaces = new_ispaces
		new_li.is_ordered = false
		table.insert(new_ispec, { indent_spaces = new_ispaces, is_ordered = new_li.is_ordered })
	end
	table.insert(li_array, rel_cursor_coords.row1 + 1, new_li)
	table.insert(ispec_array, rel_cursor_coords.row1 + 1, new_ispec)

	rel_cursor_coords.row1 = rel_cursor_coords.row1 + 1
	rel_cursor_coords.col0 = list_item.get_preamble_length(new_li)
end

---Draw out string representations of list items in li_array between the lines specified by bounds.
---@param li_array ListItem[]
---@param bounds TextBlockBounds
function smark_private.draw_list_items(li_array, bounds)
	local lis_as_strings = {}
	for i, li in ipairs(li_array) do
		lis_as_strings[i] = list_item.to_string(li)
	end
	vim.api.nvim_buf_set_lines(0, bounds.upper - 1, bounds.lower, true, lis_as_strings)
end

---Modifies li_array and optionally rel_cursor_coords in place to reflect indenting.
---@param li_array ListItem[]
---@param start_row integer 1-indexed number of first line to unindent
---@param end_row integer 1-indexed number of last line to indent
---@param rel_cursor_coords? CursorCoords
function smark_private.apply_indent(li_array, start_row, end_row, rel_cursor_coords)
	local ispec_array = format.fix(li_array, rel_cursor_coords)

	for row1 = start_row, end_row do
		local current_li = li_array[row1]
		local current_ispec = ispec_array[row1]
		local lookbehind_li = li_array[math.max(1, row1 - 1)]
		local lookbehind_ispec = ispec_array[math.max(1, row1 - 1)]
		local lookahead_ref_ispec = ispec_array[row1 + 1]

		local original_preamble_len = list_item.get_preamble_length(current_li)

		local new_ilevelspec
		if #lookbehind_ispec < #current_ispec then
			return
		elseif #lookbehind_ispec == #current_ispec then
			local is_ordered
			if lookahead_ref_ispec == nil or lookahead_ref_ispec[#current_ispec + 1] == nil then
				is_ordered = false
			else
				is_ordered = lookahead_ref_ispec[#current_ispec + 1].is_ordered
			end

			new_ilevelspec = {
				indent_spaces = list_item.get_nested_indent_spaces(lookbehind_li),
				is_ordered = is_ordered,
			}
		else
			new_ilevelspec = {
				indent_spaces = lookbehind_ispec[#current_ispec + 1].indent_spaces,
				is_ordered = lookbehind_ispec[#current_ispec + 1].is_ordered,
			}
		end

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
	end

	format.fix_numbering(li_array, ispec_array, rel_cursor_coords)
end

---Modifies li_array and optionally rel_cursor_coords in place to reflect changes.
---@param li_array ListItem[]
---@param start_row integer 1-indexed number of first line to unindent
---@param end_row integer 1-indexed number of last line to indent
---@param rel_cursor_coords? CursorCoords
function smark_private.apply_unindent(li_array, start_row, end_row, rel_cursor_coords)
	local ispec_array = format.fix(li_array, rel_cursor_coords)
	local original_end_row_ilevel = #ispec_array[end_row]

	local subtree_traversed = false

	for row1 = start_row, #li_array do
		local current_li = li_array[row1]
		local current_ispec = ispec_array[row1]
		local lookbehind_li = li_array[row1 - 1]
		local lookbehind_ispec = ispec_array[row1 - 1]

		if row1 > start_row then
			for i = 1, #current_ispec do
				if lookbehind_ispec[i] ~= nil then
					current_ispec[i] = {
						indent_spaces = lookbehind_ispec[i].indent_spaces,
						is_ordered = current_ispec[i].is_ordered,
					}
				else
					current_ispec[i] = {
						indent_spaces = list_item.get_nested_indent_spaces(lookbehind_li),
						is_ordered = current_ispec[i].is_ordered,
					}
				end
			end
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
		else
			if not subtree_traversed then
				subtree_traversed = true
			end
			current_li.indent_spaces = current_ispec[#current_ispec].indent_spaces
		end
		format.fix_numbering(li_array, ispec_array, rel_cursor_coords)
	end
end

return smark
