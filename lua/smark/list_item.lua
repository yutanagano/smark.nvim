---@class ListItem
---@field indent_rules IndentRule[] Specs for each indentation level up until the current one.
---@field is_task boolean
---@field is_completed boolean True if task which is marked completed.
---@field position_number integer The number of the list item (relevant if ordered list).
---@field content string[] The text content of the list item. Each string in the array will be rendered on a new line.

---@class IndentRule
---@field is_ordered boolean
---@field num_spaces integer The number of spaces to indent to be at this indent level

local M = {}

---@param li ListItem
---@return integer preamble_len Number of characters until start of contents
function M.get_preamble_length(li)
	if #li.indent_rules == 0 then
		return 0
	end

	local marker_len, buffer_len

	if li.indent_rules[#li.indent_rules].is_ordered then
		marker_len = string.len(tostring(li.position_number)) + 1
	else
		marker_len = 1
	end

	if li.is_task then
		buffer_len = 5
	else
		buffer_len = 1
	end

	return li.indent_rules[#li.indent_rules].num_spaces + marker_len + buffer_len
end

---@param li ListItem
---@return integer ispaces The number of spaces required to be at the indent level corresponding to li's child
function M.get_nested_indent_spaces(li)
	if not li.is_task then
		return M.get_preamble_length(li)
	end

	return M.get_preamble_length(li) - 4 -- ignore the task marker element
end

---@param li ListItem
---@return string[] lines Array of strings corresponding to the lines of text rendering out the list item
function M.to_lines(li)
	if #li.indent_rules == 0 then
		return li.content
	end

	local marker, buffer

	if li.indent_rules[#li.indent_rules].is_ordered then
		marker = tostring(li.position_number) .. "."
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

	local preamble = string.rep(" ", li.indent_rules[#li.indent_rules].num_spaces) .. marker .. buffer

	local lines = {}
	for i, content_line in ipairs(li.content) do
		if i == 1 then
			content_line = preamble .. content_line
		else
			content_line = string.rep(" ", string.len(preamble)) .. content_line
		end
		table.insert(lines, content_line)
	end

	return lines
end

---@param li ListItem
---@return ListItem new List item with same specs as li except with empty content, and set as uncompleted
function M.get_empty_like(li)
	local indent_rules = {}

	for i, rules in ipairs(li.indent_rules) do
		indent_rules[i] = {
			is_ordered = rules.is_ordered,
			num_spaces = rules.num_spaces,
		}
	end

	return {
		indent_rules = indent_rules,
		is_task = li.is_task,
		is_completed = false,
		position_number = 1,
		content = { "" },
	}
end

---@param li ListItem
---@param li_cursor_coords LiCursorCoords
---@param read_time_preamble_len integer
---@return string[] content_after_cursor The portion of li's content that lies after the cursor
function M.get_content_after_cursor(li, li_cursor_coords, read_time_preamble_len)
	local content_after_cursor = { table.unpack(li.content, li_cursor_coords.content_lnum + 1, #li.content) }

	local content_on_cursor_line = li.content[li_cursor_coords.content_lnum]
	if li_cursor_coords.col > read_time_preamble_len then
		local col_relative_to_content = li_cursor_coords.col - read_time_preamble_len + 1
		content_on_cursor_line = string.sub(content_on_cursor_line, col_relative_to_content)
	end

	if content_on_cursor_line ~= "" then
		table.insert(content_after_cursor, 1, content_on_cursor_line)
	end

	if #content_after_cursor == 0 then
		content_after_cursor = { "" }
	end

	return content_after_cursor
end

---Modify a list item's contents, truncating any content that lies after the cursor.
---@param li ListItem
---@param li_cursor_coords LiCursorCoords
---@param read_time_preamble_len integer
function M.truncate_content_at_cursor(li, li_cursor_coords, read_time_preamble_len)
	local content_before_cursor = { table.unpack(li.content, 1, li_cursor_coords.content_lnum - 1) }

	local content_on_cursor_line = li.content[li_cursor_coords.content_lnum]
	if li_cursor_coords.col > read_time_preamble_len then
		local col_relative_to_content = li_cursor_coords.col - read_time_preamble_len
		content_on_cursor_line = string.sub(content_on_cursor_line, 1, col_relative_to_content)
		table.insert(content_before_cursor, content_on_cursor_line)
	end

	if #content_before_cursor == 0 then
		content_before_cursor = { "" }
	end

	li.content = content_before_cursor
end

---@param li ListItem
function M.content_is_empty(li)
	return #li.content == 1 and li.content[1] == ""
end

---@param li ListItem
function M.content_ends_in_colon(li)
	return string.sub(li.content[#li.content], -1) == ":"
end

return M
