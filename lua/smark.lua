--- @class ListItem
--- @field is_ordered boolean True if ordered list element
--- @field is_task boolean True if task list element
--- @field is_completed boolean True if task marked completed
--- @field marker string The list marker
--- @field indent_spaces integer The indentation level of the line in number of spaces
--- @field content string The text content of the list item

local Module = {}
local utils = {}

Module.setup = function(_)
	-- nothing for now
end

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "markdown", "text" },
	callback = function()
		vim.keymap.set("i", "<CR>", function()
			local cursor_row_1_based, cursor_col_0_based = table.unpack(vim.api.nvim_win_get_cursor(0))
			local line_text = utils.read_buffer_line(cursor_row_1_based)
			local text_up_to_cursor = string.sub(line_text, 1, cursor_col_0_based)
			local text_after_cursor = string.sub(line_text, cursor_col_0_based + 1)
			local current_li = utils.list_item_from_string(text_up_to_cursor)

			if current_li == nil then
				local newline = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
				vim.api.nvim_feedkeys(newline, "n", false)
				return
			end

			if current_li.content == "" and text_after_cursor == "" then
				vim.api.nvim_buf_set_lines(0, cursor_row_1_based - 1, cursor_row_1_based, true, { "" })
				return
			end

			local next_li = utils.generate_next_list_item(current_li, text_after_cursor)

			vim.api.nvim_buf_set_lines(0, cursor_row_1_based - 1, cursor_row_1_based, true, { text_up_to_cursor })
			vim.api.nvim_buf_set_lines(0, cursor_row_1_based, cursor_row_1_based, true, { utils.to_string(next_li) })

			if current_li.is_ordered then
				utils.reindex_ordered_block_around(cursor_row_1_based)
			end

			local next_li = utils.list_item_from_line(cursor_row_1_based + 1)
			assert(next_li ~= nil, "Newly generated line after <CR> does not look like a list item")
			vim.api.nvim_win_set_cursor(0, { cursor_row_1_based + 1, utils.get_preamble_length(next_li) })
		end, { buffer = true })
		vim.keymap.set("n", "o", function()
			local cursor_row_1_based, _ = table.unpack(vim.api.nvim_win_get_cursor(0))
			local current_li = utils.list_item_from_line(cursor_row_1_based)

			if current_li == nil or current_li.content == "" then
				vim.api.nvim_buf_set_lines(0, cursor_row_1_based, cursor_row_1_based, true, { "" })
				vim.api.nvim_win_set_cursor(0, { cursor_row_1_based + 1, 0 })
				vim.cmd("startinsert!")
				return
			end

			local next_li = utils.generate_next_list_item(current_li, "")

			vim.api.nvim_buf_set_lines(0, cursor_row_1_based, cursor_row_1_based, true, { utils.to_string(next_li) })

			if current_li.is_ordered then
				utils.reindex_ordered_block_around(cursor_row_1_based)
			end

			vim.api.nvim_win_set_cursor(0, { cursor_row_1_based + 1, 0 })
			vim.cmd("startinsert!")
		end, { buffer = true })
	end,
})

---@param line_num integer 1-indexed line number to parse
---@return ListItem|nil # Nil if line does not contain list item
utils.list_item_from_line = function(line_num)
	local line_text = utils.read_buffer_line(line_num)
	return utils.list_item_from_string(line_text)
end

---@param line_text string Text of line to parse
---@return ListItem|nil # Nil if line does not contain list item
utils.list_item_from_string = function(line_text)
	local list_item = utils.parse_ordered_list_item_text(line_text)
	if list_item ~= nil then
		return list_item
	end

	list_item = utils.parse_unordered_list_item_text(line_text)
	if list_item ~= nil then
		return list_item
	end

	return nil
end

---@param line_text string Text of line to parse
---@return ListItem|nil # Nil if line does not contain ordered list item
utils.parse_ordered_list_item_text = function(line_text)
	local pattern = "^(%s*)(%d+%.)%s+(.*)"
	local indent, marker, content = string.match(line_text, pattern)

	if indent == nil then
		return nil
	end

	local is_task, is_completed, corrected_content = utils.parse_task_marker_text(line_text)
	if is_task then
		content = corrected_content
	end

	return {
		is_ordered = true,
		is_task = is_task,
		is_completed = is_completed,
		marker = marker,
		indent_spaces = string.len(indent),
		content = content,
	}
end

---@param line_text string Text of line to parse
---@return ListItem|nil # Nil if line does not contain unordered list item
utils.parse_unordered_list_item_text = function(line_text)
	local pattern = "^(%s*)(%-)%s+(.*)"
	local indent, marker, content = string.match(line_text, pattern)

	if indent == nil then
		return nil
	end

	local is_task, is_completed, corrected_content = utils.parse_task_marker_text(line_text)
	if is_task then
		content = corrected_content
	end

	return {
		is_ordered = false,
		is_task = is_task,
		is_completed = is_completed,
		marker = marker,
		indent_spaces = string.len(indent),
		content = content,
	}
end

---@param line_text string Text of line to parse
---@return boolean # True if line is task item
---@return boolean # True if marked as completed
---@return string # Detected content correcting for task marker
utils.parse_task_marker_text = function(line_text)
	local pattern = "^%s*%-?%d*%.?(%s%s?%s?%s?%[([%sxX])%])%s+(.*)"
	local task, completion, content = string.match(line_text, pattern)

	if task == nil then
		return false, false, ""
	end

	local is_completed = completion == "x" or completion == "X"

	return true, is_completed, content
end

---Only call this function once you are sure that line_num contains an ordered list item.
---Re-indexes the list markers for all ordered list items contiguous with, and including line_num.
---@param line_num integer 1-indexed line number to survey around for a ordered list block
utils.reindex_ordered_block_around = function(line_num)
	local block_row_bounds_1_based = utils.survey_ordered_block(line_num)
	for line_num_1_based = block_row_bounds_1_based[1], block_row_bounds_1_based[2] do
		local index = line_num_1_based - block_row_bounds_1_based[1] + 1
		utils.reindex_ordered_list_item(line_num_1_based, index)
	end
end

---Only call this function once you are sure that line_num contains an ordered list item.
---@param line_num integer 1-indexed line number to survey around for a ordered list block
---@return integer[] # Two-tuple of 1-indexed line numbers of ( upper, lower ) boundaries of ordered list block
utils.survey_ordered_block = function(line_num)
	local upper_bound, lower_bound = line_num, line_num
	local upper_bound_found, lower_bound_found = false, false

	while not upper_bound_found do
		if upper_bound == 1 then
			upper_bound_found = true
		else
			upper_bound = upper_bound - 1
			local line_text = utils.read_buffer_line(upper_bound)
			local match = utils.parse_ordered_list_item_text(line_text)
			if not match then
				upper_bound_found = true
				upper_bound = upper_bound + 1
			end
		end
	end

	while not lower_bound_found do
		if lower_bound == vim.api.nvim_buf_line_count(0) then
			lower_bound_found = true
		else
			lower_bound = lower_bound + 1
			local line_text = utils.read_buffer_line(lower_bound)
			local match = utils.parse_ordered_list_item_text(line_text)
			if not match then
				lower_bound_found = true
				lower_bound = lower_bound - 1
			end
		end
	end

	return { upper_bound, lower_bound }
end

---Only call this function if you are sure that line_num contains an ordered list item.
---@param line_num integer 1-indexed line number to reset index for
---@param index integer The new index number for this ordered list item
utils.reindex_ordered_list_item = function(line_num, index)
	local line_text = utils.read_buffer_line(line_num)
	local list_item = utils.parse_ordered_list_item_text(line_text)

	assert(
		list_item ~= nil,
		string.format(
			"Attempted to reindex a line that does not look like an ordered list item at line number %d",
			line_num
		)
	)

	list_item.marker = string.format("%d.", index)
	local new_line_text = utils.to_string(list_item)
	vim.api.nvim_buf_set_lines(0, line_num - 1, line_num, true, { new_line_text })
end

---@param line_num integer 1-indexed line number to read from
---@return string # Text content of that line
utils.read_buffer_line = function(line_num)
	return vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, true)[1]
end

---@param list_item ListItem
---@return string # String generated from LineInfo input
utils.to_string = function(list_item)
	local buffer
	if list_item.is_task then
		if list_item.is_completed then
			buffer = " [x] "
		else
			buffer = " [ ] "
		end
	else
		buffer = " "
	end
	return string.rep(" ", list_item.indent_spaces) .. list_item.marker .. buffer .. list_item.content
end

---Compute the appropriate list item to put below the one that is input
---@param original ListItem
---@param initial_content string
---@return ListItem
utils.generate_next_list_item = function(original, initial_content)
	local marker
	if original.is_ordered then
		marker = "1."
	else
		marker = "-"
	end
	return {
		is_ordered = original.is_ordered,
		is_task = original.is_task,
		is_completed = false,
		marker = marker,
		indent_spaces = original.indent_spaces,
		content = initial_content,
	}
end

---@param list_item ListItem
---@return integer # Number of characters until start of contents
utils.get_preamble_length = function(list_item)
	local buffer
	if list_item.is_task then
		if list_item.is_completed then
			buffer = " [x] "
		else
			buffer = " [ ] "
		end
	else
		buffer = " "
	end
	return list_item.indent_spaces + string.len(list_item.marker) + string.len(buffer)
end

return Module
