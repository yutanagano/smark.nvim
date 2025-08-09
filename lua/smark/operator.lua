local buffer = require("smark.buffer")
local list_manipulation = require("smark.list_manipulation")
local cursor = require("smark.cursor")

local M = {}

function M.normal_indent()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords, to_put_separator_at_start =
		buffer.get_list_block_around_cursor()
	assert(li_block_bounds ~= nil, "op called outside of list block")

	local start_row = vim.fn.getpos("'[")[2]
	local end_row = vim.fn.getpos("']")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_block, li_block_bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_block, li_block_bounds)

	list_manipulation.apply_indent(li_block, start_index, end_index)
	local cursor_coords = cursor.to_absolute_cursor_coords(li_cursor_coords, li_block, li_block_bounds)

	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, cursor_coords, to_put_separator_at_start, false)
end

function M.normal_unindent()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords, to_put_separator_at_start =
		buffer.get_list_block_around_cursor()
	assert(li_block_bounds ~= nil, "op called outside of list block")

	local start_row = vim.fn.getpos("'[")[2]
	local end_row = vim.fn.getpos("']")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_block, li_block_bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_block, li_block_bounds)

	list_manipulation.apply_unindent(li_block, start_index, end_index)
	local cursor_coords = cursor.to_absolute_cursor_coords(li_cursor_coords, li_block, li_block_bounds)

	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, cursor_coords, to_put_separator_at_start, false)
end

function M.visual_indent()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords, to_put_separator_at_start =
		buffer.get_list_block_around_cursor()
	assert(li_block_bounds ~= nil, "op called outside of list block")

	local start_row = vim.fn.getpos("'<")[2]
	local end_row = vim.fn.getpos("'>")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_block, li_block_bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_block, li_block_bounds)

	for _ = 1, vim.v.count1 do
		list_manipulation.apply_indent(li_block, start_index, end_index)
	end
	local cursor_coords = cursor.to_absolute_cursor_coords(li_cursor_coords, li_block, li_block_bounds)

	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, cursor_coords, to_put_separator_at_start, false)
end

function M.visual_unindent()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords, to_put_separator_at_start =
		buffer.get_list_block_around_cursor()
	assert(li_block_bounds ~= nil, "op called outside of list block")

	local start_row = vim.fn.getpos("'<")[2]
	local end_row = vim.fn.getpos("'>")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_block, li_block_bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_block, li_block_bounds)

	for _ = 1, vim.v.count1 do
		list_manipulation.apply_unindent(li_block, start_index, end_index)
	end
	local cursor_coords = cursor.to_absolute_cursor_coords(li_cursor_coords, li_block, li_block_bounds)

	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, cursor_coords, to_put_separator_at_start, false)
end

function M.visual_toggle_ordered()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords, to_put_separator_at_start =
		buffer.get_list_block_around_cursor()
	assert(li_block_bounds ~= nil, "op called outside of list block")

	local start_row = vim.fn.getpos("'<")[2]
	local end_row = vim.fn.getpos("'>")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_block, li_block_bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_block, li_block_bounds)

	list_manipulation.toggle_visual_ordered_type(li_block, start_index, end_index, li_cursor_coords)
	local cursor_coords = cursor.to_absolute_cursor_coords(li_cursor_coords, li_block, li_block_bounds)

	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, cursor_coords, to_put_separator_at_start, false)
end

function M.visual_toggle_checkbox()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords, to_put_separator_at_start =
		buffer.get_list_block_around_cursor()
	assert(li_block_bounds ~= nil, "op called outside of list block")

	local start_row = vim.fn.getpos("'<")[2]
	local end_row = vim.fn.getpos("'>")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_block, li_block_bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_block, li_block_bounds)

	list_manipulation.toggle_visual_checkbox(li_block, start_index, end_index, li_cursor_coords)
	local cursor_coords = cursor.to_absolute_cursor_coords(li_cursor_coords, li_block, li_block_bounds)

	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, cursor_coords, to_put_separator_at_start, false)
end

function M.visual_toggle_task()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords, to_put_separator_at_start =
		buffer.get_list_block_around_cursor()
	assert(li_block_bounds ~= nil, "op called outside of list block")

	local start_row = vim.fn.getpos("'<")[2]
	local end_row = vim.fn.getpos("'>")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_block, li_block_bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_block, li_block_bounds)

	list_manipulation.toggle_visual_task(li_block, start_index, end_index, li_cursor_coords)
	local cursor_coords = cursor.to_absolute_cursor_coords(li_cursor_coords, li_block, li_block_bounds)

	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, cursor_coords, to_put_separator_at_start, false)
end

return M
