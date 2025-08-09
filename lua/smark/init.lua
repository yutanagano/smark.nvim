local buffer = require("smark.buffer")
local cursor = require("smark.cursor")
local list_manipulation = require("smark.list_manipulation")

local M = {}
local callback = {}

function M.setup(_)
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "markdown", "text" },
		callback = function()
			vim.keymap.set("i", "<CR>", callback.insert_newline, { buffer = true })
			vim.keymap.set("i", "<C-t>", callback.insert_indent, { buffer = true })
			vim.keymap.set("i", "<C-d>", callback.insert_unindent, { buffer = true })
			vim.keymap.set("n", ">>", callback.normal_indent, { buffer = true })
			vim.keymap.set("n", "<<", callback.normal_unindent, { buffer = true })
			vim.keymap.set("n", ">", callback.normal_indent_op, { expr = true, buffer = true })
			vim.keymap.set("n", "<", callback.normal_unindent_op, { expr = true, buffer = true })
			vim.keymap.set("n", "o", callback.normal_o, { buffer = true })
			vim.keymap.set("n", "<leader>lf", callback.normal_format, { buffer = true })
			vim.keymap.set("n", "<leader>lo", callback.normal_ordered, { buffer = true })
			vim.keymap.set("n", "<leader>lx", callback.normal_checkbox, { buffer = true })
			vim.keymap.set("n", "<leader>lt", callback.normal_task, { buffer = true })
			vim.keymap.set("x", ">", callback.visual_indent, { expr = true, buffer = true })
			vim.keymap.set("x", "<", callback.visual_unindent, { expr = true, buffer = true })
			vim.keymap.set("x", "<leader>lo", callback.visual_ordered, { expr = true, buffer = true })
			vim.keymap.set("x", "<leader>lx", callback.visual_checkbox, { expr = true, buffer = true })
			vim.keymap.set("x", "<leader>lt", callback.visual_task, { expr = true, buffer = true })
		end,
	})
end

function callback.insert_newline()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()

	if li_block_bounds == nil then
		local newline = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
		vim.api.nvim_feedkeys(newline, "ni", false)
		return
	end

	local new_line_at_cursor = list_manipulation.apply_insert_newline(li_block, li_cursor_coords)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords, new_line_at_cursor)

	local cursor_coords = cursor.to_absolute_cursor_coords(li_cursor_coords, li_block, li_block_bounds)
	vim.api.nvim_win_set_cursor(0, { cursor_coords.row, cursor_coords.col })
end

function callback.insert_indent()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()

	if li_block_bounds == nil then
		local ctrl_t = vim.api.nvim_replace_termcodes("<C-t>", true, false, true)
		vim.api.nvim_feedkeys(ctrl_t, "ni", false)
		return
	end

	list_manipulation.apply_indent(li_block, li_cursor_coords.list_index, li_cursor_coords.list_index, li_cursor_coords)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords, false)

	local cursor_coords = cursor.to_absolute_cursor_coords(li_cursor_coords, li_block, li_block_bounds)
	vim.api.nvim_win_set_cursor(0, { cursor_coords.row, cursor_coords.col })
end

function callback.insert_unindent()
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
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords, false)

	local cursor_coords = cursor.to_absolute_cursor_coords(li_cursor_coords, li_block, li_block_bounds)
	vim.api.nvim_win_set_cursor(0, { cursor_coords.row, cursor_coords.col })
end

function callback.normal_indent()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()

	if li_block_bounds == nil then
		local indent = vim.api.nvim_replace_termcodes(string.format("%d>>", vim.v.count1), true, false, true)
		vim.api.nvim_feedkeys(indent, "ni", false)
		return
	end

	local start_index = li_cursor_coords.list_index
	local end_index = math.min(#li_block, start_index + vim.v.count1 - 1)
	list_manipulation.apply_indent(li_block, start_index, end_index)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords, false)
end

function callback.normal_unindent()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()

	if li_block_bounds == nil then
		local unindent = vim.api.nvim_replace_termcodes(string.format("%d<<", vim.v.count1), true, false, true)
		vim.api.nvim_feedkeys(unindent, "ni", false)
		return
	end

	local start_index = li_cursor_coords.list_index
	local end_index = math.min(#li_block, start_index + vim.v.count1 - 1)
	list_manipulation.apply_unindent(li_block, start_index, end_index)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords, false)
end

function callback.normal_indent_op()
	local bounds = buffer.get_list_block_around_cursor()

	if bounds == nil then
		return ">"
	end

	vim.opt.operatorfunc = "v:lua.require'smark.operator'.normal_indent"
	return "g@"
end

function callback.normal_unindent_op()
	local bounds = buffer.get_list_block_around_cursor()

	if bounds == nil then
		return "<"
	end

	vim.opt.operatorfunc = "v:lua.require'smark.operator'.normal_unindent"
	return "g@"
end

function callback.normal_o()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()

	if li_block_bounds == nil then
		vim.api.nvim_feedkeys("o", "ni", false)
		return
	end

	list_manipulation.apply_normal_o(li_block, li_cursor_coords)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords, true)

	local cursor_coords = cursor.to_absolute_cursor_coords(li_cursor_coords, li_block, li_block_bounds)
	vim.api.nvim_win_set_cursor(0, { cursor_coords.row, cursor_coords.col })
	vim.cmd("startinsert!")
end

function callback.normal_format()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()

	if li_block_bounds == nil then
		return
	end

	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords, false)
end

function callback.normal_ordered()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()

	if li_block_bounds == nil then
		return
	end

	list_manipulation.toggle_normal_ordered_type(li_block, li_cursor_coords)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords, false)
end

function callback.normal_checkbox()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()

	if li_block_bounds == nil then
		return
	end

	list_manipulation.toggle_normal_checkbox(li_block, li_cursor_coords)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords, false)
end

function callback.normal_task()
	local li_block_bounds, li_block, read_time_lines, li_cursor_coords = buffer.get_list_block_around_cursor()

	if li_block_bounds == nil then
		return
	end

	list_manipulation.toggle_normal_task(li_block, li_cursor_coords)
	buffer.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords, false)
end

function callback.visual_indent()
	local li_block_bounds = buffer.get_list_block_around_cursor()
	local highlight_bound_row = vim.fn.getpos("v")[2]

	if
		li_block_bounds == nil
		or highlight_bound_row < li_block_bounds.upper
		or highlight_bound_row > li_block_bounds.lower
	then
		return ">"
	end

	vim.opt.operatorfunc = "v:lua.require'smark.operator'.visual_indent"
	return "g@"
end

function callback.visual_unindent()
	local li_block_bounds = buffer.get_list_block_around_cursor()
	local highlight_bound_row = vim.fn.getpos("v")[2]

	if
		li_block_bounds == nil
		or highlight_bound_row < li_block_bounds.upper
		or highlight_bound_row > li_block_bounds.lower
	then
		return "<"
	end

	vim.opt.operatorfunc = "v:lua.require'smark.operator'.visual_unindent"
	return "g@"
end

function callback.visual_ordered()
	local li_block_bounds = buffer.get_list_block_around_cursor()
	local highlight_bound_row = vim.fn.getpos("v")[2]

	if
		li_block_bounds == nil
		or highlight_bound_row < li_block_bounds.upper
		or highlight_bound_row > li_block_bounds.lower
	then
		return
	end

	vim.opt.operatorfunc = "v:lua.require'smark.operator'.visual_toggle_ordered"
	return "g@"
end

function callback.visual_checkbox()
	local li_block_bounds = buffer.get_list_block_around_cursor()
	local highlight_bound_row = vim.fn.getpos("v")[2]

	if
		li_block_bounds == nil
		or highlight_bound_row < li_block_bounds.upper
		or highlight_bound_row > li_block_bounds.lower
	then
		return
	end

	vim.opt.operatorfunc = "v:lua.require'smark.operator'.visual_toggle_checkbox"
	return "g@"
end

function callback.visual_task()
	local li_block_bounds = buffer.get_list_block_around_cursor()
	local highlight_bound_row = vim.fn.getpos("v")[2]

	if
		li_block_bounds == nil
		or highlight_bound_row < li_block_bounds.upper
		or highlight_bound_row > li_block_bounds.lower
	then
		return
	end

	vim.opt.operatorfunc = "v:lua.require'smark.operator'.visual_toggle_task"
	return "g@"
end

return M
