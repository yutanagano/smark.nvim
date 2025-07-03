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

---Scan current buffer text around the given line number, and if this text is part of a list item, parse the list item and return, along with bounds.
---@param line_num integer 1-indexed line number to scan from
---@return ListItem|nil # Nil if line is not inside list item
---@return TextBlockBounds # Bounds containing list item
---@return integer # The original number of characters before the content begins at the current line
function M.scan_text_around_line(line_num)
	local li = { spec = nil, content = {} }
	local bounds = { upper = line_num, lower = line_num }
	local buf_line_count = vim.api.nvim_buf_line_count(0)
	local content, preamble_len, li_spec = M.pattern_match_line(line_num)

	if content == "" then
		return nil, bounds, preamble_len
	end

	li.spec = li_spec

	if li.spec == nil then
		for current_line = line_num - 1, 1, -1 do
			content, _, li_spec = M.pattern_match_line(current_line)

			if content == "" then
				break
			end

			table.insert(li.content, 0, content)

			if li_spec ~= nil then
				li.spec = li_spec
				bounds.upper = current_line
				break
			end
		end

		if li.spec == nil then
			return nil, bounds, preamble_len
		end
	end

	for current_line = line_num + 1, buf_line_count do
		content, _, li_spec = M.pattern_match_line(current_line)

		if content == "" or li_spec ~= nil then
			bounds.lower = current_line - 1
			break
		end

		table.insert(li.content, content)

		if current_line == buf_line_count then
			bounds.lower = current_line
		end
	end

	return li, bounds, preamble_len
end

---@param line_num integer 1-indexed line number to pattern-match
---@return string # Content detected in text i f root
---@return integer # Number of whitespace characters before the content begins
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
			return content, string.len(preamble), nil
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

	return content, preamble_len, li_spec
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

---See @field read_time_preamble_length for the original number of characters at read time.
---@param li ListItem
---@return integer # Number of characters until start of contents
function M.get_preamble_length(li)
	if li.indent_spaces == -1 then
		return 0
	end

	local marker_len, buffer_len

	if li.is_ordered then
		marker_len = string.len(tostring(li.index)) + 1
	else
		marker_len = 1
	end

	if li.is_task then
		buffer_len = 5
	else
		buffer_len = 1
	end

	return li.indent_spaces + marker_len + buffer_len
end

---@param li ListItem
---@return integer # The number of spaces required to be registered as nested list item of one given
function M.get_nested_indent_spaces(li)
	if li.indent_spaces == -1 then
		return 0
	end

	if li.is_ordered then
		return li.indent_spaces + string.len(tostring(li.index)) + 2
	else
		return li.indent_spaces + 2
	end
end

---@param li ListItem
---@return string
function M.to_string(li)
	if li.indent_spaces == -1 then
		return li.content
	end

	local marker, buffer

	if li.is_ordered then
		marker = tostring(li.index) .. "."
	else
		marker = "-"
	end

	if li.is_task then
		if li.is_completed then
			buffer = " [x] "
		else
			buffer = " [ ] "
		end
	else
		buffer = " "
	end

	return string.rep(" ", li.indent_spaces) .. marker .. buffer .. li.content
end

---@param li ListItem
---@return ListItem
function M.get_empty_like(li)
	return {
		is_ordered = li.is_ordered,
		is_task = li.is_task,
		is_completed = false,
		index = 1,
		indent_spaces = li.indent_spaces,
		content = "",
	}
end

---Return the content string that lies to the right of the cursor.
---@param li ListItem
---@param cursor_col integer 0-indexed cursor column position
---@return string
function M.get_content_after_cursor(li, cursor_col)
	if cursor_col <= li.read_time_preamble_length then
		return li.content
	end

	local relative_col_index = cursor_col - li.read_time_preamble_length + 1
	return string.sub(li.content, relative_col_index)
end

---Modify a list item's content string, truncating any content to the right of the cursor.
---@param li ListItem
---@param cursor_col integer 0-indexed cursor column position
function M.truncate_content_at_cursor(li, cursor_col)
	if cursor_col <= li.read_time_preamble_length then
		li.content = ""
		return
	end

	local relative_cutoff = cursor_col - li.read_time_preamble_length
	li.content = string.sub(li.content, 1, relative_cutoff)
end

return M
