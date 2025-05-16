---@class ListItem
---@field is_ordered boolean True if ordered list element
---@field is_task boolean True if task list element
---@field is_completed boolean True if task which is marked completed
---@field index integer The item index number
---@field indent_spaces integer The indentation level of the line in number of spaces
---@field content string The text content of the list item

local utils = require("smark.utils")

local list_item = {}

---@param line_num integer 1-indexed line number to parse
---@return ListItem|nil # Nil if line does not contain list item
list_item.from_line = function(line_num)
	local line_text = utils.read_buffer_line(line_num)
	return list_item.from_string(line_text)
end

---@param line_text string Text of line to parse
---@return ListItem|nil # Nil if line does not contain list item
list_item.from_string = function(line_text)
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
list_item.parse_ordered_list_item_text = function(line_text)
	local pattern = "^(%s*)%d+[%.%)]%s+(.*)"
	local indent, content = string.match(line_text, pattern)

	if indent == nil then
		return nil
	end

	local is_task, is_completed, corrected_content = list_item.parse_task_marker_text(line_text)
	if is_task then
		content = corrected_content
	end

	return {
		is_ordered = true,
		is_task = is_task,
		is_completed = is_completed,
		indent_spaces = string.len(indent),
		content = content,
	}
end

---@param line_text string Text of line to parse
---@return ListItem|nil # Nil if line does not contain unordered list item
list_item.parse_unordered_list_item_text = function(line_text)
	local pattern = "^(%s*)%-%s+(.*)"
	local indent, content = string.match(line_text, pattern)

	if indent == nil then
		return nil
	end

	local is_task, is_completed, corrected_content = list_item.parse_task_marker_text(line_text)
	if is_task then
		content = corrected_content
	end

	return {
		is_ordered = false,
		is_task = is_task,
		is_completed = is_completed,
		indent_spaces = string.len(indent),
		content = content,
	}
end

---@param line_text string Text of line to parse
---@return boolean # True if line is task item
---@return boolean # True if marked as completed
---@return string # Detected content correcting for task marker
list_item.parse_task_marker_text = function(line_text)
	local pattern = "^%s*%-?%d*%.?(%s%s?%s?%s?%[([%sxX])%])%s+(.*)"
	local task, completion, content = string.match(line_text, pattern)

	if task == nil then
		return false, false, ""
	end

	local is_completed = completion == "x" or completion == "X"

	return true, is_completed, content
end

---@param li ListItem
---@return integer # Number of characters until start of contents
list_item.get_preamble_length = function(li)
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
list_item.get_nested_indent_spaces = function(li)
	if li.is_ordered then
		return li.indent_spaces + string.len(tostring(li.index)) + 2
	else
		return li.indent_spaces + 2
	end
end

---@param li ListItem
---@return string # String generated from LineInfo input
list_item.to_string = function(li)
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

---Compute the appropriate list item to put below the one that is input
---@param original ListItem
---@param initial_content string
---@return ListItem
list_item.get_next = function(original, initial_content)
	return {
		is_ordered = original.is_ordered,
		is_task = original.is_task,
		is_completed = false,
		index = 1,
		indent_spaces = original.indent_spaces,
		content = initial_content,
	}
end

return list_item
