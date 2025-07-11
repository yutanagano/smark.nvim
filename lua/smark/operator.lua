local buffer = require("smark.buffer")
local list_manipulation = require("smark.list_manipulation")
local cursor = require("smark.cursor")

local M = {}

function M.normal_indent()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()
	assert(li_block_bounds ~= nil, "op called outside of list block")

	local start_row = vim.fn.getpos("'[")[2]
	local end_row = vim.fn.getpos("']")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_block, li_block_bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_block, li_block_bounds)

	list_manipulation.apply_indent(li_block, start_index, end_index)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords)
end

function M.normal_unindent()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()
	assert(li_block_bounds ~= nil, "op called outside of list block")

	local start_row = vim.fn.getpos("'[")[2]
	local end_row = vim.fn.getpos("']")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_block, li_block_bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_block, li_block_bounds)

	list_manipulation.apply_unindent(li_block, start_index, end_index)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords)
end

function M.visual_indent()
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

function M.visual_unindent()
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

function M.visual_toggle_ordered()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()
	assert(li_block_bounds ~= nil, "op called outside of list block")

	local start_row = vim.fn.getpos("'<")[2]
	local end_row = vim.fn.getpos("'>")[2]
	local start_index = cursor.make_relative_to_containing_li(start_row, li_block, li_block_bounds)
	local end_index = cursor.make_relative_to_containing_li(end_row, li_block, li_block_bounds)

	list_manipulation.toggle_visual_ordered_type(li_block, start_index, end_index, li_cursor_coords)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds)
end

function M.visual_toggle_checkbox()
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
