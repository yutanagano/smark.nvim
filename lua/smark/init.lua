---@class TextBlockBounds
---@field upper integer 1-indexed upper bound line number
---@field lower integer 1-indexed lower bound line number

local list_item = require("smark.list_item")
local format = require("smark.format")
local list_manipulation = require("smark.list_manipulation")

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
		vim.keymap.set("n", ">", smark_private.callback_normal_indentop, { expr = true, buffer = true })
		vim.keymap.set("n", "<", smark_private.callback_normal_unindentop, { expr = true, buffer = true })
		vim.keymap.set("n", "o", smark_private.callback_normal_o, { buffer = true })
		vim.keymap.set("n", "<leader>ll", smark_private.callback_normal_format, { buffer = true })
		vim.keymap.set("n", "<leader>lo", smark_private.callback_normal_toggle_ordered, { buffer = true })
		vim.keymap.set("n", "<leader>lx", smark_private.callback_normal_checkbox, { buffer = true })
		vim.keymap.set("x", ">", smark_private.callback_visual_indent, { expr = true, buffer = true })
		vim.keymap.set("x", "<", smark_private.callback_visual_unindent, { expr = true, buffer = true })
		vim.keymap.set("x", "<leader>lo", smark_private.callback_visual_toggle_ordered, { expr = true, buffer = true })
		vim.keymap.set("x", "<leader>lx", smark_private.callback_visual_checkbox, { expr = true, buffer = true })
	end,
})

function smark_private.callback_insert_newline()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		local newline = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
		vim.api.nvim_feedkeys(newline, "ni", false)
		return
	end

	local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
	local ispec_array = format.fix(li_array, rel_cursor_coords)
	list_manipulation.apply_insert_newline(li_array, ispec_array, rel_cursor_coords)
	smark_private.draw_list_items(li_array, original_text, bounds, rel_cursor_coords)

	cursor_coords = { row1 = rel_cursor_coords.row1 + bounds.upper - 1, col0 = rel_cursor_coords.col0 }
	vim.api.nvim_win_set_cursor(0, { cursor_coords.row1, cursor_coords.col0 })
end

function smark_private.callback_insert_indent()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		local ctrl_t = vim.api.nvim_replace_termcodes("<C-t>", true, false, true)
		vim.api.nvim_feedkeys(ctrl_t, "ni", false)
		return
	end

	local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
	local ispec_array = format.fix(li_array, rel_cursor_coords)
	list_manipulation.apply_indent(
		li_array,
		ispec_array,
		rel_cursor_coords.row1,
		rel_cursor_coords.row1,
		rel_cursor_coords
	)
	smark_private.draw_list_items(li_array, original_text, bounds, rel_cursor_coords)

	cursor_coords = { row1 = rel_cursor_coords.row1 + bounds.upper - 1, col0 = rel_cursor_coords.col0 }
	vim.api.nvim_win_set_cursor(0, { cursor_coords.row1, cursor_coords.col0 })
end

function smark_private.callback_insert_unindent()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		local ctrl_d = vim.api.nvim_replace_termcodes("<C-d>", true, false, true)
		vim.api.nvim_feedkeys(ctrl_d, "ni", false)
		return
	end

	local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
	local ispec_array = format.fix(li_array, rel_cursor_coords)
	list_manipulation.apply_unindent(
		li_array,
		ispec_array,
		rel_cursor_coords.row1,
		rel_cursor_coords.row1,
		rel_cursor_coords
	)
	smark_private.draw_list_items(li_array, original_text, bounds, rel_cursor_coords)

	cursor_coords = { row1 = rel_cursor_coords.row1 + bounds.upper - 1, col0 = rel_cursor_coords.col0 }
	vim.api.nvim_win_set_cursor(0, { cursor_coords.row1, cursor_coords.col0 })
end

function smark_private.callback_normal_indent()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		local indent = vim.api.nvim_replace_termcodes(string.format("%d>>", vim.v.count1), true, false, true)
		vim.api.nvim_feedkeys(indent, "ni", false)
		return
	end

	local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
	local start_row = rel_cursor_coords.row1
	local end_row = math.min(#li_array, start_row + vim.v.count1 - 1)
	local ispec_array = format.fix(li_array, rel_cursor_coords)
	list_manipulation.apply_indent(li_array, ispec_array, start_row, end_row)
	smark_private.draw_list_items(li_array, original_text, bounds, rel_cursor_coords)
end

function smark_private.callback_normal_unindent()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		local unindent = vim.api.nvim_replace_termcodes(string.format("%d<<", vim.v.count1), true, false, true)
		vim.api.nvim_feedkeys(unindent, "ni", false)
		return
	end

	local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
	local start_row = rel_cursor_coords.row1
	local end_row = math.min(#li_array, start_row + vim.v.count1 - 1)
	local ispec_array = format.fix(li_array, rel_cursor_coords)
	list_manipulation.apply_unindent(li_array, ispec_array, start_row, end_row)
	smark_private.draw_list_items(li_array, original_text, bounds, rel_cursor_coords)
end

function smark_private.callback_normal_indentop()
	local _, bounds, _ = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		return ">"
	end

	vim.opt.operatorfunc = "v:lua.require'smark'.normal_indentop"
	return "g@"
end

function smark_private.callback_normal_unindentop()
	local _, bounds, _ = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		return "<"
	end

	vim.opt.operatorfunc = "v:lua.require'smark'.normal_unindentop"
	return "g@"
end

function smark.normal_indentop()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()
	local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
	local start_row = vim.fn.getpos("'[")[2] - bounds.upper + 1
	local end_row = vim.fn.getpos("']")[2] - bounds.upper + 1
	local ispec_array = format.fix(li_array, rel_cursor_coords)
	list_manipulation.apply_indent(li_array, ispec_array, start_row, end_row)
	smark_private.draw_list_items(li_array, original_text, bounds, rel_cursor_coords)
end

function smark.normal_unindentop()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()
	local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
	local start_row = vim.fn.getpos("'[")[2] - bounds.upper + 1
	local end_row = vim.fn.getpos("']")[2] - bounds.upper + 1
	local ispec_array = format.fix(li_array, rel_cursor_coords)
	list_manipulation.apply_unindent(li_array, ispec_array, start_row, end_row)
	smark_private.draw_list_items(li_array, original_text, bounds, rel_cursor_coords)
end

function smark_private.callback_normal_o()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		vim.api.nvim_feedkeys("o", "ni", false)
		return
	end

	local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
	local ispec_array = format.fix(li_array, rel_cursor_coords)
	list_manipulation.apply_normal_o(li_array, ispec_array, rel_cursor_coords)
	smark_private.draw_list_items(li_array, original_text, bounds, rel_cursor_coords)

	cursor_coords = { row1 = rel_cursor_coords.row1 + bounds.upper - 1, col0 = rel_cursor_coords.col0 }
	vim.api.nvim_win_set_cursor(0, { cursor_coords.row1, cursor_coords.col0 })
	vim.cmd("startinsert!")
end

function smark_private.callback_normal_format()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		return
	end

	local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
	format.fix(li_array, rel_cursor_coords)
	smark_private.draw_list_items(li_array, original_text, bounds, rel_cursor_coords)
end

function smark_private.callback_normal_toggle_ordered()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		return
	end

	local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
	local ispec_array = format.fix(li_array, rel_cursor_coords)
	list_manipulation.toggle_normal_ordered_type(li_array, ispec_array, rel_cursor_coords)
	smark_private.draw_list_items(li_array, original_text, bounds, rel_cursor_coords)
end

function smark_private.callback_normal_checkbox()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		return
	end

	local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
	local ispec_array = format.fix(li_array, rel_cursor_coords)
	list_manipulation.toggle_normal_checkbox(li_array, ispec_array, rel_cursor_coords)
	smark_private.draw_list_items(li_array, original_text, bounds, rel_cursor_coords)
end

function smark_private.callback_visual_indent()
	local _, bounds, _ = smark_private.get_list_block_around_cursor()
	local highlight_bound_row = vim.fn.getpos("v")[2]

	if bounds == nil or highlight_bound_row < bounds.upper or highlight_bound_row > bounds.lower then
		return ">"
	end

	vim.opt.operatorfunc = "v:lua.require'smark'.visual_indent_op"
	return "g@"
end

function smark_private.callback_visual_unindent()
	local _, bounds, _ = smark_private.get_list_block_around_cursor()
	local highlight_bound_row = vim.fn.getpos("v")[2]

	if bounds == nil or highlight_bound_row < bounds.upper or highlight_bound_row > bounds.lower then
		return "<"
	end

	vim.opt.operatorfunc = "v:lua.require'smark'.visual_unindent_op"
	return "g@"
end

function smark_private.callback_visual_toggle_ordered()
	local _, bounds, _ = smark_private.get_list_block_around_cursor()
	local highlight_bound_row = vim.fn.getpos("v")[2]

	if bounds == nil or highlight_bound_row < bounds.upper or highlight_bound_row > bounds.lower then
		return
	end

	vim.opt.operatorfunc = "v:lua.require'smark'.visual_toggle_ordered_op"
	return "g@"
end

function smark_private.callback_visual_checkbox()
	local _, bounds, _ = smark_private.get_list_block_around_cursor()
	local highlight_bound_row = vim.fn.getpos("v")[2]

	if bounds == nil or highlight_bound_row < bounds.upper or highlight_bound_row > bounds.lower then
		return
	end

	vim.opt.operatorfunc = "v:lua.require'smark'.visual_toggle_checkbox_op"
	return "g@"
end

function smark.visual_indent_op()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()
	local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
	local start_row = vim.fn.getpos("'<")[2] - bounds.upper + 1
	local end_row = vim.fn.getpos("'>")[2] - bounds.upper + 1
	local ispec_array = format.fix(li_array, rel_cursor_coords)
	for _ = 1, vim.v.count1 do
		list_manipulation.apply_indent(li_array, ispec_array, start_row, end_row)
	end
	smark_private.draw_list_items(li_array, original_text, bounds, rel_cursor_coords)
end

function smark.visual_unindent_op()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()
	local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
	local start_row = vim.fn.getpos("'<")[2] - bounds.upper + 1
	local end_row = vim.fn.getpos("'>")[2] - bounds.upper + 1
	local ispec_array = format.fix(li_array, rel_cursor_coords)
	for _ = 1, vim.v.count1 do
		list_manipulation.apply_unindent(li_array, ispec_array, start_row, end_row)
	end
	smark_private.draw_list_items(li_array, original_text, bounds, rel_cursor_coords)
end

function smark.visual_toggle_ordered_op()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()
	local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
	local start_row = vim.fn.getpos("'<")[2] - bounds.upper + 1
	local end_row = vim.fn.getpos("'>")[2] - bounds.upper + 1
	local ispec_array = format.fix(li_array, rel_cursor_coords)
	list_manipulation.toggle_visual_ordered_type(li_array, ispec_array, start_row, end_row, rel_cursor_coords)
	smark_private.draw_list_items(li_array, original_text, bounds, rel_cursor_coords)
end

function smark.visual_toggle_checkbox_op()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()
	local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
	local start_row = vim.fn.getpos("'<")[2] - bounds.upper + 1
	local end_row = vim.fn.getpos("'>")[2] - bounds.upper + 1
	local ispec_array = format.fix(li_array, rel_cursor_coords)
	list_manipulation.toggle_visual_checkbox(li_array, ispec_array, start_row, end_row, rel_cursor_coords)
	smark_private.draw_list_items(li_array, original_text, bounds, rel_cursor_coords)
end

---@return CursorCoords
---@return TextBlockBounds|nil # Boundaries of containing list block, nil if cursor not in list block
---@return ListItem[] # Array of list items detected inside the list block
---@return string[] # Array of strings representing the original block content, line by line
function smark_private.get_list_block_around_cursor()
	local cursor_row1, cursor_col0 = table.unpack(vim.api.nvim_win_get_cursor(0))
	local cursor_coords = { row1 = cursor_row1, col0 = cursor_col0 }
	local text = vim.api.nvim_buf_get_lines(0, cursor_row1 - 1, cursor_row1, true)[1]

	local li = list_item.from_string(text)

	if li == nil then
		return cursor_coords, nil, {}, {}
	end

	local bounds = { upper = cursor_row1, lower = cursor_row1 }
	local upper_bound_found, lower_bound_found = false, false
	local li_array = {}
	local text_array = {}

	table.insert(li_array, li)
	table.insert(text_array, text)

	while not upper_bound_found do
		if bounds.upper == 1 then
			upper_bound_found = true
		else
			text = vim.api.nvim_buf_get_lines(0, bounds.upper - 2, bounds.upper - 1, true)[1]
			li = list_item.from_string(text)
			if li == nil then
				upper_bound_found = true
			else
				bounds.upper = bounds.upper - 1
				table.insert(li_array, 1, li)
				table.insert(text_array, 1, text)
			end
		end
	end

	while not lower_bound_found do
		if bounds.lower == vim.api.nvim_buf_line_count(0) then
			lower_bound_found = true
		else
			text = vim.api.nvim_buf_get_lines(0, bounds.lower, bounds.lower + 1, true)[1]
			li = list_item.from_string(text)
			if li == nil then
				lower_bound_found = true
			else
				bounds.lower = bounds.lower + 1
				table.insert(li_array, li)
				table.insert(text_array, text)
			end
		end
	end

	return cursor_coords, bounds, li_array, text_array
end

---Draw out string representations of list items in li_array between the lines specified by bounds.
---@param li_array ListItem[]
---@param original_text string[] Array containing original text contents of list block
---@param bounds TextBlockBounds
---@param rel_cursor_coords CursorCoords Cursor coordinates relative to bounds of list block
function smark_private.draw_list_items(li_array, original_text, bounds, rel_cursor_coords)
	if #li_array == #original_text then
		for i, li in ipairs(li_array) do
			local new_text = list_item.to_string(li)
			local absolute_ln = bounds.upper + i - 1
			if original_text[i] ~= new_text then
				vim.api.nvim_buf_set_lines(0, absolute_ln - 1, absolute_ln, true, { new_text })
			end
		end
		return
	end

	for i, li in ipairs(li_array) do
		local new_text = list_item.to_string(li)
		local absolute_ln = bounds.upper + i - 1

		if i < rel_cursor_coords.row1 then
			if original_text[i] ~= new_text then
				vim.api.nvim_buf_set_lines(0, absolute_ln - 1, absolute_ln, true, { new_text })
			end
		elseif i == rel_cursor_coords.row1 then
			vim.api.nvim_buf_set_lines(0, absolute_ln - 1, absolute_ln - 1, true, { new_text })
		else
			if original_text[i - 1] ~= new_text then
				vim.api.nvim_buf_set_lines(0, absolute_ln - 1, absolute_ln, true, { new_text })
			end
		end
	end
end

return smark
