local list_item = require("smark.list_item")
local cursor = require("smark.cursor")
local format = require("smark.format")

if table.unpack == nil then -- compatibility with older Lua
	table.unpack = unpack
end

local M = {}

---Check if the cursor is currently inside of a list block. If it is, then
---return the items below concerning the current list block.
---
---@return TextBlockBounds|nil list_block_bounds Boundaries of containing list
---block, nil if cursor not in list block
---@return ListItem[] list_block Array of list items detected inside the list
---block, including a separating empty line item at the start if appropriate
---(such an item is inserted if it is necessary to secure empty space between a
---preceding non-list paragraph)
---@return string[] read_time_lines Array of strings representing the original
---block content, line by line
---@return LiCursorCoords li_cursor_coords The current cursor coordinates,
---specified semantically relative to the list items. An empty table if cursor
---is not inside a list block.
---@return boolean to_put_separator_at_start A flat that will be set to true if
---the line preceding the list block is a normal paragraph and an empty
---separator line should be added above the list block to separate the two.
function M.get_list_block_around_cursor()
	local cursor_row, cursor_col = table.unpack(vim.api.nvim_win_get_cursor(0))
	local cursor_coords = { row = cursor_row, col = cursor_col }
	local li, li_bounds, li_read_time_lines, read_time_preamble_len = M.scan_text_around_line(cursor_coords.row)

	if li == nil then
		return nil, {}, {}, {}, false
	end

	local li_block_bounds = { upper = li_bounds.upper, lower = li_bounds.lower }
	local li_block = { li }
	local read_time_lines = li_read_time_lines
	local to_put_separator_at_start = false

	while li_block_bounds.upper > 1 do
		li, li_bounds, li_read_time_lines = M.scan_text_around_line(li_block_bounds.upper - 1)

		if li == nil then
			if string.match(li_read_time_lines[#li_read_time_lines], "^%s*$") == nil then
				to_put_separator_at_start = true
			end
			break
		end

		li_block_bounds.upper = li_bounds.upper
		table.insert(li_block, 1, li)
		for i, line in ipairs(li_read_time_lines) do
			table.insert(read_time_lines, i, line)
		end
	end

	local buf_line_count = vim.api.nvim_buf_line_count(0)
	while li_block_bounds.lower < buf_line_count do
		li, li_bounds, li_read_time_lines = M.scan_text_around_line(li_block_bounds.lower + 1)

		if li == nil then
			break
		end

		li_block_bounds.lower = li_bounds.lower
		table.insert(li_block, li)
		for i = 1, #li_read_time_lines do
			table.insert(read_time_lines, li_read_time_lines[i])
		end
	end

	local li_cursor_coords = cursor.to_li_cursor_coords(cursor_coords, li_block, li_block_bounds)

	format.fix(li_block, li_cursor_coords, read_time_preamble_len)

	return li_block_bounds, li_block, read_time_lines, li_cursor_coords, to_put_separator_at_start
end

---Scan current buffer (0) text around the given line number, and if this text
---is part of a list item, parse the list item and return, along with bounds
---and other info.
---
---IMPORTANT: Note that the returned list item will not yet be fully defined,
---since we are not yet fully certain about the indent rules of the list item
---(e.g. we do not know if the list item is preceded by a parent level with a
---certain indent rule)
---
---@param line_num integer 1-indexed line number to scan from
---@return ListItem|nil li Nil if line is not inside list item
---@return TextBlockBounds block_bounds Bounds of the text contiguous from line
---number line_num (until at either end there is an empty line or the start of
---a list item). This is well-defined regardless of whether that block of text
---qualifies as a list item or not.
---@return string[] read_time_lines Original buffer text representing the lines
---of the contiguous block of text.
---@return integer read_time_preamble_len The original number of characters
---before the content begins on line_num. This is always well-defined.
function M.scan_text_around_line(line_num)
	local buf_line_count = vim.api.nvim_buf_line_count(0)
	local raw_line = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, true)[1]
	local li_shell, content_line, preamble_len = M.pattern_match_line(raw_line)

	local bounds = { upper = line_num, lower = line_num }

	if li_shell == nil and content_line == "" then
		return nil, bounds, { raw_line }, preamble_len
	end

	local li = li_shell
	local content = { content_line }
	local read_time_lines = { raw_line }

	if li == nil then
		for current_lnum = line_num - 1, 1, -1 do
			raw_line = vim.api.nvim_buf_get_lines(0, current_lnum - 1, current_lnum, true)[1]
			li_shell, content_line = M.pattern_match_line(raw_line)

			if content_line == "" then
				bounds.upper = current_lnum + 1
				break
			end

			table.insert(content, 1, content_line)
			table.insert(read_time_lines, 1, raw_line)

			if li_shell ~= nil then
				li = li_shell
				bounds.upper = current_lnum
				break
			end
		end
	end

	for current_lnum = line_num + 1, buf_line_count do
		raw_line = vim.api.nvim_buf_get_lines(0, current_lnum - 1, current_lnum, true)[1]
		li_shell, content_line = M.pattern_match_line(raw_line)

		if content_line == "" or li_shell ~= nil then
			bounds.lower = current_lnum - 1
			break
		end

		table.insert(content, content_line)
		table.insert(read_time_lines, raw_line)

		if current_lnum == buf_line_count then
			bounds.lower = current_lnum
		end
	end

	if li == nil then
		return nil, bounds, read_time_lines, preamble_len
	end

	li.content = content

	return li, bounds, read_time_lines, preamble_len
end

---@param text string Text of line to pattern match
---@return table|nil list_item_shell Table containing incomplete definition of
---list element if current line looks like a list element root. Nil otherwise.
---@return string content_line Content detected in line (excludes any preamble
---/ whitespace). This is always well-defined.
---@return integer read_time_preamble_len Number of characters before the
---content begins. This is always well-defined.
function M.pattern_match_line(text)
	local pattern = "^((%s*)%d+[%.%)]%s+)(.*)"
	local is_ordered = true
	local preamble, indent, content_line = string.match(text, pattern)

	if preamble == nil then
		pattern = "^((%s*)[%-%*%+]%s+)(.*)"
		is_ordered = false
		preamble, indent, content_line = string.match(text, pattern)
	end

	if preamble == nil then
		pattern = "^(%s*)(.*)"
		preamble, content_line = string.match(text, pattern)
		return nil, content_line, string.len(preamble)
	end

	local read_time_preamble_len = string.len(preamble)
	local is_task, is_completed, corrected_content, corrected_preamble_len = M.pattern_match_task_root(text)
	if is_task then
		read_time_preamble_len = corrected_preamble_len
		content_line = corrected_content
	end

	local list_item_shell = {
		indent_rules = {
			{
				is_ordered = is_ordered,
				num_spaces = string.len(indent),
			},
		},
		is_task = is_task,
		is_completed = is_completed,
		index = 1,
	}

	return list_item_shell, content_line, read_time_preamble_len
end

---@param text string Text of line to parse
---@return boolean is_task
---@return boolean is_completed
---@return string content_line Detected content in line, removing preable / preceding whitespace
---@return integer read_time_preamble_len Number of characters until content begins
function M.pattern_match_task_root(text)
	local pattern = "^(%s*%-?%d*%.?%s%s?%s?%s?%[([%sxX])%]%s+)(.*)"
	local preamble, completion, content_line = string.match(text, pattern)

	if preamble == nil then
		return false, false, "", 0
	end

	local is_completed = completion == "x" or completion == "X"

	return true, is_completed, content_line, string.len(preamble)
end

---@return TextBlockBounds|nil paragraph_bounds
---@return string[] paragraph_lines
---@return CursorCoords cursor_coords
function M.get_current_paragraph()
	local cursor_row, cursor_col = table.unpack(vim.api.nvim_win_get_cursor(0))
	local cursor_coords = { row = cursor_row, col = cursor_col }
	local paragraph_bounds = { upper = cursor_row, lower = cursor_row }
	local paragraph_lines = {}

	for line_num = cursor_coords.row, 1, -1 do
		local line = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, true)[1]
		if line == "" then
			break
		end
		table.insert(paragraph_lines, 1, line)
		paragraph_bounds.upper = line_num
	end

	if #paragraph_lines == 0 then
		return nil, {}, cursor_coords
	end

	for line_num = cursor_coords.row + 1, vim.api.nvim_buf_line_count(0) do
		local line = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, true)[1]
		if line == "" then
			break
		end
		table.insert(paragraph_lines, line)
		paragraph_bounds.lower = line_num
	end

	return paragraph_bounds, paragraph_lines, cursor_coords
end

---Draw out string representations of list items in li_array between the lines
---specified by bounds. Also may modify cursor_coords in place (move it down
---some rows) if new seaparator lines are written above it.
---
---@param li_block ListItem[]
---@param read_time_lines string[] Array containing original text contents of
---list block
---@param li_block_bounds TextBlockBounds
---@param cursor_coords CursorCoords
---@param to_put_separator_at_start boolean Set to true if an empty line should
---be inserted at the beginning to separate the list block from other contents
---above.
---@param new_line_at_cursor boolean Set to true if new line has explicitly
---been generated at the cursor
function M.draw_list_items(
	li_block,
	read_time_lines,
	li_block_bounds,
	cursor_coords,
	to_put_separator_at_start,
	new_line_at_cursor
)
	local relative_cursor_line_num = cursor_coords.row - li_block_bounds.upper + 1
	local new_line_numbers = {}

	local current_line_index = 1
	local write_time_lines = {}
	if to_put_separator_at_start then
		table.insert(write_time_lines, "")
		table.insert(new_line_numbers, 1)
		relative_cursor_line_num = relative_cursor_line_num + 1
		current_line_index = 2
	end

	local preceding_item_type = list_item.li_type.EMPTY
	for _, li in ipairs(li_block) do
		local li_as_strings = list_item.to_lines(li)
		local current_item_type = list_item.get_list_type(li)

		if
			preceding_item_type ~= list_item.li_type.EMPTY
			and current_item_type ~= list_item.li_type.EMPTY
			and preceding_item_type ~= current_item_type
		then
			table.insert(write_time_lines, "")
			table.insert(new_line_numbers, current_line_index)
			if relative_cursor_line_num >= current_line_index then
				relative_cursor_line_num = relative_cursor_line_num + 1
			end
			current_line_index = current_line_index + 1
		end

		for _, s in ipairs(li_as_strings) do
			table.insert(write_time_lines, s)
			current_line_index = current_line_index + 1
		end

		preceding_item_type = current_item_type
	end

	if new_line_at_cursor then
		table.insert(new_line_numbers, relative_cursor_line_num)
	end

	if #write_time_lines == #read_time_lines then
		for line_index, s in ipairs(write_time_lines) do
			local absolute_ln = li_block_bounds.upper + line_index - 1
			if read_time_lines[line_index] ~= s then
				vim.api.nvim_buf_set_lines(0, absolute_ln - 1, absolute_ln, true, { s })
			end
		end
		return
	end

	table.sort(new_line_numbers, function(a, b)
		return a > b
	end)
	local read_time_line_index = 1

	for i, s in ipairs(write_time_lines) do
		local absolute_ln = li_block_bounds.upper + i - 1

		if i == new_line_numbers[#new_line_numbers] then
			vim.api.nvim_buf_set_lines(0, absolute_ln - 1, absolute_ln - 1, true, { s })
			table.remove(new_line_numbers)
		else
			if read_time_lines[read_time_line_index] ~= s then
				vim.api.nvim_buf_set_lines(0, absolute_ln - 1, absolute_ln, true, { s })
			end
			read_time_line_index = read_time_line_index + 1
		end
	end

	cursor_coords.row = relative_cursor_line_num + li_block_bounds.upper - 1
end

return M
