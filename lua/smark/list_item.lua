---@class ListItem
---@field is_ordered boolean True if ordered list element.
---@field is_task boolean True if task list element.
---@field is_completed boolean True if task which is marked completed.
---@field index integer The item index number.
---@field indent_spaces integer The indentation level of the line in number of spaces. -1 results in a line with no list marker element.
---@field content string The text content of the list item.
---@field original_preamble_length integer The original number of characters before the content begins

local list_item = {}

---@param line_num integer 1-indexed line number to parse
---@return ListItem|nil # Nil if line does not contain list item
function list_item.from_line(line_num)
	local line_text = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, true)[1]
	return list_item.from_string(line_text)
end

---@param line_text string Text of line to parse
---@return ListItem|nil # Nil if line does not contain list item
function list_item.from_string(line_text)
	local li = list_item.parse_ordered_list_item_text(line_text)
	if li ~= nil then
		return li
	end

	li = list_item.parse_unordered_list_item_text(line_text)
	if li ~= nil then
		return li
	end

	return nil
end

---@param line_text string Text of line to parse
---@return ListItem|nil # Nil if line does not contain ordered list item
function list_item.parse_ordered_list_item_text(line_text)
	local pattern = "^((%s*)%d+[%.%)]%s+)(.*)"
	local preamble, indent, content = string.match(line_text, pattern)

	if preamble == nil then
		return nil
	end

	local preamble_length = string.len(preamble)
	local is_task, is_completed, corrected_preamble_length, corrected_content =
		list_item.parse_task_marker_text(line_text)
	if is_task then
		preamble_length = corrected_preamble_length
		content = corrected_content
	end

	return {
		is_ordered = true,
		is_task = is_task,
		is_completed = is_completed,
		indent_spaces = string.len(indent),
		content = content,
		original_preamble_length = preamble_length,
	}
end

---@param line_text string Text of line to parse
---@return ListItem|nil # Nil if line does not contain unordered list item
function list_item.parse_unordered_list_item_text(line_text)
	local pattern = "^((%s*)%-%s+)(.*)"
	local preamble, indent, content = string.match(line_text, pattern)

	if preamble == nil then
		return nil
	end

	local preamble_length = string.len(preamble)
	local is_task, is_completed, corrected_preamble_length, corrected_content =
		list_item.parse_task_marker_text(line_text)
	if is_task then
		preamble_length = corrected_preamble_length
		content = corrected_content
	end

	return {
		is_ordered = false,
		is_task = is_task,
		is_completed = is_completed,
		indent_spaces = string.len(indent),
		content = content,
		original_preamble_length = preamble_length,
	}
end

---@param line_text string Text of line to parse
---@return boolean # True if line is task item
---@return boolean # True if marked as completed
---@return integer # Preamble length correcting for task marker
---@return string # Detected content correcting for task marker
function list_item.parse_task_marker_text(line_text)
	local pattern = "^(%s*%-?%d*%.?%s%s?%s?%s?%[([%sxX])%]%s+)(.*)"
	local preamble, completion, content = string.match(line_text, pattern)

	if preamble == nil then
		return false, false, 0, ""
	end

	local is_completed = completion == "x" or completion == "X"

	return true, is_completed, string.len(preamble), content
end

---See @field original_preamble_length for the original number of characters at read time.
---@param li ListItem
---@return integer # Number of characters until start of contents
function list_item.get_preamble_length(li)
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

	for k, v in pairs(li) do
		print(k, v)
	end

	return li.indent_spaces + marker_len + buffer_len
end

---@param li ListItem
---@return integer # The number of spaces required to be registered as nested list item of one given
function list_item.get_nested_indent_spaces(li)
	if li.is_ordered then
		return li.indent_spaces + string.len(tostring(li.index)) + 2
	else
		return li.indent_spaces + 2
	end
end

---@param li ListItem
---@return string
function list_item.to_string(li)
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
function list_item.get_empty_like(li)
	return {
		is_ordered = li.is_ordered,
		is_task = li.is_task,
		is_completed = false,
		indent_spaces = li.indent_spaces,
		content = "",
	}
end

---Only call this function if the cursor position is inside of the list item's content.
---@param li ListItem
---@param cursor_col integer 0-indexed cursor column position
---@return string
function list_item.get_content_after_cursor(li, cursor_col)
	assert(
		cursor_col >= li.original_preamble_length,
		string.format("Cursor column at %d lies outside of list item content range", cursor_col)
	)

	local relative_col_index = cursor_col - li.original_preamble_length + 1
	return string.sub(li.content, relative_col_index)
end

---Only call this function if the cursor position is inside of the list item's content.
---@param li ListItem
---@param cursor_col integer 0-indexed cursor column position
function list_item.truncate_content_at_cursor(li, cursor_col)
	assert(
		cursor_col >= li.original_preamble_length,
		string.format("Cursor column at %d lies outside of list item content range", cursor_col)
	)

	local relative_cutoff = cursor_col - li.original_preamble_length
	li.content = string.sub(li.content, 1, relative_cutoff)
end

return list_item
