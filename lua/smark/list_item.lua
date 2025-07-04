---@class ListItem
---@field spec ListSpec List item characteristics necessary to properly render it.
---@field content string[] The text content of the list item.

---@class ListSpec
---@field is_ordered boolean True if ordered list element.
---@field is_task boolean True if task list element.
---@field is_completed boolean True if task which is marked completed.
---@field index integer The item index number.
---@field indent_spaces integer The indentation level of the line in number of spaces. -1 results in a line with no list marker element.

---@class TextBlockBounds
---@field upper integer 1-indexed upper bound line number
---@field lower integer 1-indexed lower bound line number

local M = {}

---Scan current buffer (0) text around the given line number, and if this text is part of a list item, parse the list item and return, along with bounds.
---@param line_num integer 1-indexed line number to scan from
---@return ListItem|nil # Nil if line is not inside list item
---@return TextBlockBounds # Bounds containing list item
---@return string[] raw Raw content within bounds
---@return integer preamble_len The original number of characters before the content begins at the current line
function M.scan_text_around_line(line_num)
	local li = { spec = nil, content = {} }
	local bounds = { upper = line_num, lower = line_num }
	local raw = {}

	local buf_line_count = vim.api.nvim_buf_line_count(0)
	local raw_line, content, preamble_len, li_spec = M.pattern_match_line(line_num)

	if content == "" then
		return nil, bounds, {}, preamble_len
	end

	li.spec = li_spec
	li.content = { content }
	raw = { raw_line }

	if li.spec == nil then
		for current_lnum = line_num - 1, 1, -1 do
			raw_line, content, _, li_spec = M.pattern_match_line(current_lnum)

			if content == "" then
				break
			end

			table.insert(li.content, 1, content)
			table.insert(raw, 1, raw_line)

			if li_spec ~= nil then
				li.spec = li_spec
				bounds.upper = current_lnum
				break
			end
		end

		if li.spec == nil then
			return nil, bounds, {}, preamble_len
		end
	end

	for current_lnum = line_num + 1, buf_line_count do
		raw_line, content, _, li_spec = M.pattern_match_line(current_lnum)

		if content == "" or li_spec ~= nil then
			bounds.lower = current_lnum - 1
			break
		end

		table.insert(li.content, content)
		table.insert(raw, raw_line)

		if current_lnum == buf_line_count then
			bounds.lower = current_lnum
		end
	end

	return li, bounds, raw, preamble_len
end

---@param line_num integer 1-indexed line number to pattern-match
---@return string raw Raw content of that line
---@return string content Content detected in text
---@return integer preamble_len Number of characters before the content begins
---@return ListSpec|nil # Nil if line does not contain list item root
function M.pattern_match_line(line_num)
	local text = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, true)[1]
	local pattern = "^((%s*)%d+[%.%)]%s+)(.*)"
	local is_ordered = true
	local preamble, indent, content = string.match(text, pattern)

	if preamble == nil then
		pattern = "^((%s*)[%-%*%+]%s+)(.*)"
		is_ordered = false
		preamble, indent, content = string.match(text, pattern)

		if preamble == nil then
			pattern = "^(%s*)(.*)"
			preamble, content = string.match(text, pattern)
			return text, content, string.len(preamble), nil
		end
	end

	local preamble_len = string.len(preamble)
	local is_task, is_completed, corrected_content, corrected_preamble_len = M.pattern_match_task_root(text)
	if is_task then
		preamble_len = corrected_preamble_len
		content = corrected_content
	end

	local li_spec = {
		is_ordered = is_ordered,
		is_task = is_task,
		is_completed = is_completed,
		index = 1,
		indent_spaces = string.len(indent),
	}

	return text, content, preamble_len, li_spec
end

---@param text string Text of line to parse
---@return boolean # True if line is task item
---@return boolean # True if marked as completed
---@return string # Detected content correcting for task marker
---@return integer # Preamble length correcting for task marker
function M.pattern_match_task_root(text)
	local pattern = "^(%s*%-?%d*%.?%s%s?%s?%s?%[([%sxX])%]%s+)(.*)"
	local preamble, completion, content = string.match(text, pattern)

	if preamble == nil then
		return false, false, "", 0
	end

	local is_completed = completion == "x" or completion == "X"

	return true, is_completed, content, string.len(preamble)
end

---@param li ListItem
---@return integer preamble_len Number of characters until start of contents
function M.get_preamble_length(li)
	if li.spec.indent_spaces == -1 then
		return 0
	end

	local marker_len, buffer_len

	if li.spec.is_ordered then
		marker_len = string.len(tostring(li.spec.index)) + 1
	else
		marker_len = 1
	end

	if li.spec.is_task then
		buffer_len = 5
	else
		buffer_len = 1
	end

	return li.spec.indent_spaces + marker_len + buffer_len
end

---@param li ListItem
---@return integer ispaces The number of spaces required to be registered as nested list item of one given
function M.get_nested_indent_spaces(li)
	if li.spec.indent_spaces == -1 then
		return 0
	end

	if li.spec.is_ordered then
		return li.spec.indent_spaces + string.len(tostring(li.spec.index)) + 2
	else
		return li.spec.indent_spaces + 2
	end
end

---@param li ListItem
---@return string[]
function M.to_strings(li)
	if li.spec.indent_spaces == -1 then
		return li.content
	end

	local marker, buffer

	if li.spec.is_ordered then
		marker = tostring(li.spec.index) .. "."
	else
		marker = "-"
	end

	if li.spec.is_task then
		if li.spec.is_completed then
			buffer = " [x] "
		else
			buffer = " [ ] "
		end
	else
		buffer = " "
	end

	local li_as_strings = {}
	for i, content_line in ipairs(li.content) do
		if i == 1 then
			content_line = string.rep(" ", li.spec.indent_spaces) .. marker .. buffer .. content_line
		end
		table.insert(li_as_strings, content_line)
	end

	return li_as_strings
end

---@param li ListItem
---@return ListItem
function M.get_empty_like(li)
	return {
		spec = {
			is_ordered = li.spec.is_ordered,
			is_task = li.spec.is_task,
			is_completed = false,
			index = 1,
			indent_spaces = li.spec.indent_spaces,
		},
		content = "",
	}
end

---Return the content string that lies to the right of the cursor.
---@param li ListItem
---@param read_time_preamble_len integer
---@param cursor_col integer 0-indexed cursor column position
---@param content_lnum integer The 1-index line number within the list item contents that the cursor is on
---@return string[]
function M.get_content_after_cursor(li, read_time_preamble_len, cursor_col, content_lnum)
	local content_after_cursor = { table.unpack(li.content, content_lnum, #li.content) }

	if cursor_col <= read_time_preamble_len then
		return content_after_cursor
	end

	local relative_col_index = cursor_col - read_time_preamble_len + 1
	content_after_cursor[1] = string.sub(content_after_cursor[1], relative_col_index)
	return content_after_cursor
end

---Modify a list item's content string, truncating any content to the right of the cursor.
---@param li ListItem
---@param read_time_preamble_len integer
---@param cursor_col integer 0-indexed cursor column position
---@param content_lnum integer The 1-index line number within the list item contents that the cursor is on
function M.truncate_content_at_cursor(li, read_time_preamble_len, cursor_col, content_lnum)
	local content_before_cursor = { table.unpack(li.content, 1, content_lnum - 1) }
	local content_on_cursor_line = li.content[content_lnum]

	if cursor_col <= read_time_preamble_len then
		li.content = content_before_cursor
		return
	end

	local relative_cutoff = cursor_col - read_time_preamble_len
	content_on_cursor_line = string.sub(content_on_cursor_line, 1, relative_cutoff)
	table.insert(content_before_cursor, content_on_cursor_line)
	li.content = content_before_cursor
end

return M
