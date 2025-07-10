local cursor = require("smark.cursor")
local format = require("smark.format")
local list_manipulation = require("smark.list_manipulation")
local smarkio = require("smark.io")

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
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = smarkio.get_list_block_around_cursor()

	if li_block_bounds == nil then
		local newline = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
		vim.api.nvim_feedkeys(newline, "ni", false)
		return
	end

	list_manipulation.apply_insert_newline(li_block, li_cursor_coords)
	smarkio.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords)

	local cursor_coords = cursor.to_absolute_cursor_coords(li_cursor_coords, li_block, li_block_bounds)
	vim.api.nvim_win_set_cursor(0, { cursor_coords.row, cursor_coords.col })
end

function smark_private.callback_insert_indent()
	local cursor_coords, bounds, li_array, original_text, read_time_preamble_len =
		smark_private.get_list_block_around_cursor()

	if bounds == nil then
		local ctrl_t = vim.api.nvim_replace_termcodes("<C-t>", true, false, true)
		vim.api.nvim_feedkeys(ctrl_t, "ni", false)
		return
	end

	local li_cursor_coords = cursor.to_li_cursor_coords(cursor_coords, li_array, bounds)
	local ispec_array = format.fix(li_array, li_cursor_coords, read_time_preamble_len)
	list_manipulation.apply_indent(
		li_array,
		ispec_array,
		li_cursor_coords.list_index,
		li_cursor_coords.list_index,
		li_cursor_coords
	)
	smark_private.draw_list_items(li_array, original_text, bounds, li_cursor_coords)

	cursor_coords = cursor.to_absolute_cursor_coords(li_cursor_coords, li_array, bounds)
	vim.api.nvim_win_set_cursor(0, { cursor_coords.row, cursor_coords.col })
end

function smark_private.callback_insert_unindent()
	local cursor_coords, bounds, li_array, original_text, read_time_preamble_len =
		smark_private.get_list_block_around_cursor()

	if bounds == nil then
		local ctrl_d = vim.api.nvim_replace_termcodes("<C-d>", true, false, true)
		vim.api.nvim_feedkeys(ctrl_d, "ni", false)
		return
	end

	local li_cursor_coords = cursor.to_li_cursor_coords(cursor_coords, li_array, bounds)
	local ispec_array = format.fix(li_array, li_cursor_coords, read_time_preamble_len)
	list_manipulation.apply_unindent(
		li_array,
		ispec_array,
		li_cursor_coords.list_index,
		li_cursor_coords.list_index,
		li_cursor_coords
	)
	smark_private.draw_list_items(li_array, original_text, bounds, li_cursor_coords)

	cursor_coords = cursor.to_absolute_cursor_coords(li_cursor_coords, li_array, bounds)
	vim.api.nvim_win_set_cursor(0, { cursor_coords.row, cursor_coords.col })
end

function smark_private.callback_normal_indent()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		local indent = vim.api.nvim_replace_termcodes(string.format("%d>>", vim.v.count1), true, false, true)
		vim.api.nvim_feedkeys(indent, "ni", false)
		return
	end

	local li_cursor_coords = cursor.to_li_cursor_coords(cursor_coords, li_array, bounds)
	local start_index = li_cursor_coords.list_index
	local end_index = math.min(#li_array, start_index + vim.v.count1 - 1)
	local ispec_array = format.fix(li_array)
	list_manipulation.apply_indent(li_array, ispec_array, start_index, end_index)
	smark_private.draw_list_items(li_array, original_text, bounds, li_cursor_coords)
end

function smark_private.callback_normal_unindent()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		local unindent = vim.api.nvim_replace_termcodes(string.format("%d<<", vim.v.count1), true, false, true)
		vim.api.nvim_feedkeys(unindent, "ni", false)
		return
	end

	local li_cursor_coords = cursor.to_li_cursor_coords(cursor_coords, li_array, bounds)
	local start_index = li_cursor_coords.list_index
	local end_index = math.min(#li_array, start_index + vim.v.count1 - 1)
	local ispec_array = format.fix(li_array)
	list_manipulation.apply_unindent(li_array, ispec_array, start_index, end_index)
	smark_private.draw_list_items(li_array, original_text, bounds, li_cursor_coords)
end

function smark_private.callback_normal_indentop()
	local _, bounds = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		return ">"
	end

	vim.opt.operatorfunc = "v:lua.require'smark'.normal_indent_op"
	return "g@"
end

function smark_private.callback_normal_unindentop()
	local _, bounds = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		return "<"
	end

	vim.opt.operatorfunc = "v:lua.require'smark'.normal_unindent_op"
	return "g@"
end

function smark.normal_indent_op()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()
	assert(bounds ~= nil, "op called outside of list block")

	local li_cursor_coords = cursor.to_li_cursor_coords(cursor_coords, li_array, bounds)
	local start_row = vim.fn.getpos("'[")[2]
	local end_row = vim.fn.getpos("']")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_array, bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_array, bounds)

	local ispec_array = format.fix(li_array)
	list_manipulation.apply_indent(li_array, ispec_array, start_index, end_index)
	smark_private.draw_list_items(li_array, original_text, bounds, li_cursor_coords)
end

function smark.normal_unindent_op()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()
	assert(bounds ~= nil, "op called outside of list block")

	local li_cursor_coords = cursor.to_li_cursor_coords(cursor_coords, li_array, bounds)
	local start_row = vim.fn.getpos("'[")[2]
	local end_row = vim.fn.getpos("']")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_array, bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_array, bounds)

	local ispec_array = format.fix(li_array)
	list_manipulation.apply_unindent(li_array, ispec_array, start_index, end_index)
	smark_private.draw_list_items(li_array, original_text, bounds, li_cursor_coords)
end

function smark_private.callback_normal_o()
	local cursor_coords, bounds, li_array, original_text, read_time_preamble_len =
		smark_private.get_list_block_around_cursor()

	if bounds == nil then
		vim.api.nvim_feedkeys("o", "ni", false)
		return
	end

	local li_cursor_coords = cursor.to_li_cursor_coords(cursor_coords, li_array, bounds)
	local ispec_array = format.fix(li_array, li_cursor_coords, read_time_preamble_len)
	list_manipulation.apply_normal_o(li_array, ispec_array, li_cursor_coords)
	smark_private.draw_list_items(li_array, original_text, bounds, li_cursor_coords)

	cursor_coords = cursor.to_absolute_cursor_coords(li_cursor_coords, li_array, bounds)
	vim.api.nvim_win_set_cursor(0, { cursor_coords.row, cursor_coords.col })
	vim.cmd("startinsert!")
end

function smark_private.callback_normal_format()
	local _, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		return
	end

	format.fix(li_array)
	smark_private.draw_list_items(li_array, original_text, bounds)
end

function smark_private.callback_normal_toggle_ordered()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		return
	end

	local li_cursor_coords = cursor.to_li_cursor_coords(cursor_coords, li_array, bounds)
	local ispec_array = format.fix(li_array, li_cursor_coords)
	list_manipulation.toggle_normal_ordered_type(li_array, ispec_array, li_cursor_coords)
	smark_private.draw_list_items(li_array, original_text, bounds, li_cursor_coords)
end

function smark_private.callback_normal_checkbox()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()

	if bounds == nil then
		return
	end

	local li_cursor_coords = cursor.to_li_cursor_coords(cursor_coords, li_array, bounds)
	local ispec_array = format.fix(li_array, li_cursor_coords)
	list_manipulation.toggle_normal_checkbox(li_array, ispec_array, li_cursor_coords)
	smark_private.draw_list_items(li_array, original_text, bounds, li_cursor_coords)
end

function smark_private.callback_visual_indent()
	local _, bounds = smark_private.get_list_block_around_cursor()
	local highlight_bound_row = vim.fn.getpos("v")[2]

	if bounds == nil or highlight_bound_row < bounds.upper or highlight_bound_row > bounds.lower then
		return ">"
	end

	vim.opt.operatorfunc = "v:lua.require'smark'.visual_indent_op"
	return "g@"
end

function smark_private.callback_visual_unindent()
	local _, bounds = smark_private.get_list_block_around_cursor()
	local highlight_bound_row = vim.fn.getpos("v")[2]

	if bounds == nil or highlight_bound_row < bounds.upper or highlight_bound_row > bounds.lower then
		return "<"
	end

	vim.opt.operatorfunc = "v:lua.require'smark'.visual_unindent_op"
	return "g@"
end

function smark_private.callback_visual_toggle_ordered()
	local _, bounds = smark_private.get_list_block_around_cursor()
	local highlight_bound_row = vim.fn.getpos("v")[2]

	if bounds == nil or highlight_bound_row < bounds.upper or highlight_bound_row > bounds.lower then
		return
	end

	vim.opt.operatorfunc = "v:lua.require'smark'.visual_toggle_ordered_op"
	return "g@"
end

function smark_private.callback_visual_checkbox()
	local _, bounds = smark_private.get_list_block_around_cursor()
	local highlight_bound_row = vim.fn.getpos("v")[2]

	if bounds == nil or highlight_bound_row < bounds.upper or highlight_bound_row > bounds.lower then
		return
	end

	vim.opt.operatorfunc = "v:lua.require'smark'.visual_toggle_checkbox_op"
	return "g@"
end

function smark.visual_indent_op()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()
	assert(bounds ~= nil, "op called outside of list block")

	local li_cursor_coords = cursor.to_li_cursor_coords(cursor_coords, li_array, bounds)
	local start_row = vim.fn.getpos("'<")[2]
	local end_row = vim.fn.getpos("'>")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_array, bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_array, bounds)

	local ispec_array = format.fix(li_array)
	for _ = 1, vim.v.count1 do
		list_manipulation.apply_indent(li_array, ispec_array, start_index, end_index)
	end
	smark_private.draw_list_items(li_array, original_text, bounds, li_cursor_coords)
end

function smark.visual_unindent_op()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()
	assert(bounds ~= nil, "op called outside of list block")

	local li_cursor_coords = cursor.to_li_cursor_coords(cursor_coords, li_array, bounds)
	local start_row = vim.fn.getpos("'<")[2]
	local end_row = vim.fn.getpos("'>")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_array, bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_array, bounds)

	local ispec_array = format.fix(li_array)
	for _ = 1, vim.v.count1 do
		list_manipulation.apply_unindent(li_array, ispec_array, start_index, end_index)
	end
	smark_private.draw_list_items(li_array, original_text, bounds, li_cursor_coords)
end

function smark.visual_toggle_ordered_op()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()
	assert(bounds ~= nil, "op called outside of list block")

	local li_cursor_coords = cursor.to_li_cursor_coords(cursor_coords, li_array, bounds)
	local start_row = vim.fn.getpos("'<")[2]
	local end_row = vim.fn.getpos("'>")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_array, bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_array, bounds)

	local ispec_array = format.fix(li_array)
	list_manipulation.toggle_visual_ordered_type(li_array, ispec_array, start_index, end_index, li_cursor_coords)
	smark_private.draw_list_items(li_array, original_text, bounds, li_cursor_coords)
end

function smark.visual_toggle_checkbox_op()
	local cursor_coords, bounds, li_array, original_text = smark_private.get_list_block_around_cursor()
	assert(bounds ~= nil, "op called outside of list block")

	local li_cursor_coords = cursor.to_li_cursor_coords(cursor_coords, li_array, bounds)
	local start_row = vim.fn.getpos("'<")[2]
	local end_row = vim.fn.getpos("'>")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_array, bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_array, bounds)

	local ispec_array = format.fix(li_array)
	list_manipulation.toggle_visual_checkbox(li_array, ispec_array, start_index, end_index, li_cursor_coords)
	smark_private.draw_list_items(li_array, original_text, bounds, li_cursor_coords)
end

return smark
