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
---@return TextBlockBounds|nil list_block_bounds Boundaries of containing list block, nil if cursor not in list block
---@return ListItem[] list_block Array of list items detected inside the list block
---@return string[] read_time_lines Array of strings representing the original block content, line by line
---@return LiCursorCoords li_cursor_coords The current cursor coordinates, specified semantically relative to the list items
function M.get_list_block_around_cursor()
	local cursor_row, cursor_col = table.unpack(vim.api.nvim_win_get_cursor(0))
	local cursor_coords = { row = cursor_row, col = cursor_col }
	local li, li_bounds, li_read_time_lines, read_time_preamble_len = M.scan_text_around_line(cursor_coords.row)

	if li == nil then
		return nil, {}, {}, cursor_coords
	end

	local li_block_bounds = { upper = li_bounds.upper, lower = li_bounds.lower }
	local li_block = { li }
	local read_time_lines = li_read_time_lines

	while li_block_bounds.upper > 1 do
		li, li_bounds, li_read_time_lines = M.scan_text_around_line(li_block_bounds.upper - 1)

		if li == nil then
			break
		end

		li_block_bounds.upper = li_bounds.upper
		table.insert(li_block, 1, li)
		for i = 1, #li_read_time_lines do
			table.insert(read_time_lines, i, li_read_time_lines[i])
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

	return li_block_bounds, li_block, read_time_lines, li_cursor_coords
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
---@return TextBlockBounds li_bounds
---@return string[] read_time_lines Original buffer text representing the list item
---@return integer read_time_preamble_len The original number of characters before the content begins at the current line
function M.scan_text_around_line(line_num)
	local buf_line_count = vim.api.nvim_buf_line_count(0)
	local li_shell, raw_line, content_line, preamble_len = M.pattern_match_line(line_num)

	local bounds = { upper = line_num, lower = line_num }

	if li_shell == nil and content_line == "" then
		return nil, bounds, {}, preamble_len
	end

	local li = li_shell
	local content = { content_line }
	local read_time_lines = { raw_line }

	if li == nil then
		for current_lnum = line_num - 1, 1, -1 do
			li_shell, raw_line, content_line = M.pattern_match_line(current_lnum)

			if content_line == "" then
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

	if li == nil then
		return nil, bounds, {}, preamble_len
	end

	for current_lnum = line_num + 1, buf_line_count do
		li_shell, raw_line, content_line = M.pattern_match_line(current_lnum)

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

	li.content = content

	return li, bounds, read_time_lines, preamble_len
end

---@param line_num integer 1-indexed line number to pattern-match
---@return table|nil list_item_shell Table containing incomplete definition of list element if current line looks like a list element root. Nil otherwise.
---@return string raw_line Raw content of that line
---@return string content_line Content detected in line (excludes any preamble / whitespace)
---@return integer read_time_preamble_len Number of characters before the content begins
function M.pattern_match_line(line_num)
	local text = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, true)[1]
	local pattern = "^((%s*)%d+[%.%)]%s+)(.*)"
	local is_ordered = true
	local preamble, indent, content_line = string.match(text, pattern)

	if preamble == nil then
		pattern = "^((%s*)[%-%*%+]%s+)(.*)"
		is_ordered = false
		preamble, indent, content_line = string.match(text, pattern)

		if preamble == nil then
			pattern = "^(%s*)(.*)"
			preamble, content_line = string.match(text, pattern)
			return nil, text, content_line, string.len(preamble)
		end
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

	return list_item_shell, text, content_line, read_time_preamble_len
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

---Draw out string representations of list items in li_array between the lines
---specified by bounds.
---
---@param li_block ListItem[]
---@param read_time_lines string[] Array containing original text contents of list block
---@param li_block_bounds TextBlockBounds
---@param li_cursor_coords? LiCursorCoords
function M.draw_list_items(li_block, read_time_lines, li_block_bounds, li_cursor_coords)
	local previous_li_fully_outdented = false
	local write_time_lines = {}
	for _, li in ipairs(li_block) do
		local li_as_strings = list_item.to_lines(li)

		if
			(previous_li_fully_outdented and #li.indent_rules > 0)
			or (not previous_li_fully_outdented and #li.indent_rules == 0)
		then
			table.insert(write_time_lines, "")
		end

		for _, s in ipairs(li_as_strings) do
			table.insert(write_time_lines, s)
		end

		if #li.indent_rules == 0 then
			previous_li_fully_outdented = true
		else
			previous_li_fully_outdented = false
		end
	end

	if #write_time_lines == #read_time_lines then
		for i, s in ipairs(write_time_lines) do
			local absolute_ln = li_block_bounds.upper + i - 1
			if read_time_lines[i] ~= s then
				vim.api.nvim_buf_set_lines(0, absolute_ln - 1, absolute_ln, true, { s })
			end
		end
		return
	end

	assert(li_cursor_coords ~= nil, "li_cursor_coords must be supplied if active changes have been made to the text")

	local relative_row = cursor.get_row_relative_to_li_block_bounds(li_cursor_coords, li_block)

	for i, s in ipairs(write_time_lines) do
		local absolute_ln = li_block_bounds.upper + i - 1

		if i < relative_row then
			if read_time_lines[i] ~= s then
				vim.api.nvim_buf_set_lines(0, absolute_ln - 1, absolute_ln, true, { s })
			end
		elseif i == relative_row then
			vim.api.nvim_buf_set_lines(0, absolute_ln - 1, absolute_ln - 1, true, { s })
		else
			if read_time_lines[i - 1] ~= s then
				vim.api.nvim_buf_set_lines(0, absolute_ln - 1, absolute_ln, true, { s })
			end
		end
	end
end

return M
