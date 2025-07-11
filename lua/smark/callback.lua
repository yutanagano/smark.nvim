local buffer = require("smark.buffer")
local list_manipulation = require("smark.list_manipulation")
local cursor = require("smark.cursor")

local M = {}

function M.insert_newline()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()

	if li_block_bounds == nil then
		local newline = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
		vim.api.nvim_feedkeys(newline, "ni", false)
		return
	end

	list_manipulation.apply_insert_newline(li_block, li_cursor_coords)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords)

	local cursor_coords = cursor.to_absolute_cursor_coords(li_cursor_coords, li_block, li_block_bounds)
	vim.api.nvim_win_set_cursor(0, { cursor_coords.row, cursor_coords.col })
end

function M.insert_indent()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()

	if li_block_bounds == nil then
		local ctrl_t = vim.api.nvim_replace_termcodes("<C-t>", true, false, true)
		vim.api.nvim_feedkeys(ctrl_t, "ni", false)
		return
	end

	list_manipulation.apply_indent(li_block, li_cursor_coords.list_index, li_cursor_coords.list_index, li_cursor_coords)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords)

	local cursor_coords = cursor.to_absolute_cursor_coords(li_cursor_coords, li_block, li_block_bounds)
	vim.api.nvim_win_set_cursor(0, { cursor_coords.row, cursor_coords.col })
end

function M.insert_unindent()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()

	if li_block_bounds == nil then
		local ctrl_d = vim.api.nvim_replace_termcodes("<C-d>", true, false, true)
		vim.api.nvim_feedkeys(ctrl_d, "ni", false)
		return
	end

	list_manipulation.apply_unindent(
		li_block,
		li_cursor_coords.list_index,
		li_cursor_coords.list_index,
		li_cursor_coords
	)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords)

	local cursor_coords = cursor.to_absolute_cursor_coords(li_cursor_coords, li_block, li_block_bounds)
	vim.api.nvim_win_set_cursor(0, { cursor_coords.row, cursor_coords.col })
end

function M.normal_indent()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()

	if li_block_bounds == nil then
		local indent = vim.api.nvim_replace_termcodes(string.format("%d>>", vim.v.count1), true, false, true)
		vim.api.nvim_feedkeys(indent, "ni", false)
		return
	end

	local start_index = li_cursor_coords.list_index
	local end_index = math.min(#li_block, start_index + vim.v.count1 - 1)
	list_manipulation.apply_indent(li_block, start_index, end_index)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords)
end

function M.normal_unindent()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()

	if li_block_bounds == nil then
		local unindent = vim.api.nvim_replace_termcodes(string.format("%d<<", vim.v.count1), true, false, true)
		vim.api.nvim_feedkeys(unindent, "ni", false)
		return
	end

	local start_index = li_cursor_coords.list_index
	local end_index = math.min(#li_block, start_index + vim.v.count1 - 1)
	list_manipulation.apply_unindent(li_block, start_index, end_index)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords)
end

function M.normal_indent_op()
	local bounds = buffer.get_list_block_around_cursor()

	if bounds == nil then
		return ">"
	end

	vim.opt.operatorfunc = "v:lua.require'smark.callback'.normal_indent_op"
	return "g@"
end

function M.normal_unindent_op()
	local bounds = buffer.get_list_block_around_cursor()

	if bounds == nil then
		return "<"
	end

	vim.opt.operatorfunc = "v:lua.require'smark.callback'.normal_unindent_op"
	return "g@"
end

function M.normal_indent_op()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()
	assert(li_block_bounds ~= nil, "op called outside of list block")

	local start_row = vim.fn.getpos("'[")[2]
	local end_row = vim.fn.getpos("']")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_block, li_block_bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_block, li_block_bounds)

	list_manipulation.apply_indent(li_block, start_index, end_index)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords)
end

function M.normal_unindent_op()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()
	assert(li_block_bounds ~= nil, "op called outside of list block")

	local start_row = vim.fn.getpos("'[")[2]
	local end_row = vim.fn.getpos("']")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_block, li_block_bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_block, li_block_bounds)

	list_manipulation.apply_unindent(li_block, start_index, end_index)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords)
end

function M.normal_o()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()

	if li_block_bounds == nil then
		vim.api.nvim_feedkeys("o", "ni", false)
		return
	end

	list_manipulation.apply_normal_o(li_block, li_cursor_coords)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords)

	local cursor_coords = cursor.to_absolute_cursor_coords(li_cursor_coords, li_block, li_block_bounds)
	vim.api.nvim_win_set_cursor(0, { cursor_coords.row, cursor_coords.col })
	vim.cmd("startinsert!")
end

function M.normal_format()
	local li_block_bounds, li_block, read_time_lines = buffer.get_list_block_around_cursor()

	if li_block_bounds == nil then
		return
	end

	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds)
end

function M.normal_ordered()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()

	if li_block_bounds == nil then
		return
	end

	list_manipulation.toggle_normal_ordered_type(li_block, li_cursor_coords)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds)
end

function M.normal_checkbox()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()

	if li_block_bounds == nil then
		return
	end

	list_manipulation.toggle_normal_checkbox(li_block, li_cursor_coords)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds)
end

function M.visual_indent()
	local li_block_bounds = buffer.get_list_block_around_cursor()
	local highlight_bound_row = vim.fn.getpos("v")[2]

	if
		li_block_bounds == nil
		or highlight_bound_row < li_block_bounds.upper
		or highlight_bound_row > li_block_bounds.lower
	then
		return ">"
	end

	vim.opt.operatorfunc = "v:lua.require'smark.callback'.visual_indent_op"
	return "g@"
end

function M.visual_unindent()
	local li_block_bounds = buffer.get_list_block_around_cursor()
	local highlight_bound_row = vim.fn.getpos("v")[2]

	if
		li_block_bounds == nil
		or highlight_bound_row < li_block_bounds.upper
		or highlight_bound_row > li_block_bounds.lower
	then
		return "<"
	end

	vim.opt.operatorfunc = "v:lua.require'smark.callback'.visual_unindent_op"
	return "g@"
end

function M.visual_ordered()
	local li_block_bounds = buffer.get_list_block_around_cursor()
	local highlight_bound_row = vim.fn.getpos("v")[2]

	if
		li_block_bounds == nil
		or highlight_bound_row < li_block_bounds.upper
		or highlight_bound_row > li_block_bounds.lower
	then
		return
	end

	vim.opt.operatorfunc = "v:lua.require'smark.callback'.visual_toggle_ordered_op"
	return "g@"
end

function M.visual_checkbox()
	local li_block_bounds = buffer.get_list_block_around_cursor()
	local highlight_bound_row = vim.fn.getpos("v")[2]

	if
		li_block_bounds == nil
		or highlight_bound_row < li_block_bounds.upper
		or highlight_bound_row > li_block_bounds.lower
	then
		return
	end

	vim.opt.operatorfunc = "v:lua.require'smark.callback'.visual_toggle_checkbox_op"
	return "g@"
end

function M.visual_indent_op()
	local li_block_bounds, li_block, read_time_lines = buffer.get_list_block_around_cursor()
	assert(li_block_bounds ~= nil, "op called outside of list block")

	local start_row = vim.fn.getpos("'<")[2]
	local end_row = vim.fn.getpos("'>")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_block, li_block_bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_block, li_block_bounds)

	for _ = 1, vim.v.count1 do
		list_manipulation.apply_indent(li_block, start_index, end_index)
	end
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds)
end

function M.visual_unindent_op()
	local li_block_bounds, li_block, read_time_lines = buffer.get_list_block_around_cursor()
	assert(li_block_bounds ~= nil, "op called outside of list block")

	local start_row = vim.fn.getpos("'<")[2]
	local end_row = vim.fn.getpos("'>")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_block, li_block_bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_block, li_block_bounds)

	for _ = 1, vim.v.count1 do
		list_manipulation.apply_unindent(li_block, start_index, end_index)
	end
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds)
end

function M.visual_toggle_ordered_op()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()
	assert(li_block_bounds ~= nil, "op called outside of list block")

	local start_row = vim.fn.getpos("'<")[2]
	local end_row = vim.fn.getpos("'>")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_block, li_block_bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_block, li_block_bounds)

	list_manipulation.toggle_visual_ordered_type(li_block, start_index, end_index, li_cursor_coords)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds)
end

function M.visual_toggle_checkbox_op()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()
	assert(li_block_bounds ~= nil, "op called outside of list block")

	local start_row = vim.fn.getpos("'<")[2]
	local end_row = vim.fn.getpos("'>")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_block, li_block_bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_block, li_block_bounds)

	list_manipulation.toggle_visual_checkbox(li_block, start_index, end_index, li_cursor_coords)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds)
end

return M
