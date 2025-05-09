--- @class LineInfo
--- @field ordered boolean True if ordered list element
--- @field checkbox boolean True if checkbox list element
--- @field marker string The list marker
--- @field indent_spaces integer The indentation level of the line in number of spaces
--- @field content string The text content of the list item
--- @field preamble_length integer The number of characters up to start of content

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
			local cursor_on_list, line_info = utils.parse_line_text(text_up_to_cursor)

			if not cursor_on_list then
				local newline = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
				vim.api.nvim_feedkeys(newline, "n", false)
				return
			end

			if line_info.content == "" then
				vim.api.nvim_buf_set_lines(0, cursor_row_1_based - 1, cursor_row_1_based, true, { "" })
				return
			end

			local next_line_text = string.rep(" ", line_info.indent_spaces)
				.. line_info.marker
				.. " "
				.. text_after_cursor

			vim.api.nvim_buf_set_lines(0, cursor_row_1_based - 1, cursor_row_1_based, true, { text_up_to_cursor })
			vim.api.nvim_buf_set_lines(0, cursor_row_1_based, cursor_row_1_based, true, { next_line_text })

			if line_info.ordered then
				utils.reindex_ordered_block_around(cursor_row_1_based)
			end

			_, line_info = utils.parse_line(cursor_row_1_based + 1)
			vim.api.nvim_win_set_cursor(0, { cursor_row_1_based + 1, line_info.preamble_length })
		end, { buffer = true })
		vim.keymap.set("n", "o", function()
			local cursor_row_1_based, _ = table.unpack(vim.api.nvim_win_get_cursor(0))
			local cursor_on_list, line_info = utils.parse_line(cursor_row_1_based)

			if not cursor_on_list or line_info.content == "" then
				vim.api.nvim_buf_set_lines(0, cursor_row_1_based, cursor_row_1_based, true, { "" })
				vim.api.nvim_win_set_cursor(0, { cursor_row_1_based + 1, 0 })
				vim.cmd("startinsert!")
				return
			end

			local next_line_text = string.rep(" ", line_info.indent_spaces) .. line_info.marker .. " "

			vim.api.nvim_buf_set_lines(0, cursor_row_1_based, cursor_row_1_based, true, { next_line_text })

			if line_info.ordered then
				utils.reindex_ordered_block_around(cursor_row_1_based)
			end

			vim.api.nvim_win_set_cursor(0, { cursor_row_1_based + 1, 0 })
			vim.cmd("startinsert!")
		end, { buffer = true })
	end,
})

---@param line_num integer 1-indexed line number to parse
---@return boolean # True if line is a list item
---@return LineInfo # Parsed info for this line
utils.parse_line = function(line_num)
	local line_text = utils.read_buffer_line(line_num)
	return utils.parse_line_text(line_text)
end

---@param line_text string Text of line to parse
---@return boolean # True if line is a list item
---@return LineInfo # Parsed info for this line
utils.parse_line_text = function(line_text)
	local match, info = utils.parse_ordered_list_item_text(line_text)
	if match then
		return true, info
	end

	match, info = utils.parse_unordered_list_item_text(line_text)
	if match then
		return true, info
	end

	return false, {}
end

---@param line_text string Text of line to parse
---@return boolean # True if line is an ordered list item
---@return LineInfo # Parsed info for this line
utils.parse_ordered_list_item_text = function(line_text)
	local pattern = "^(%s*)(%d+%.)(%s+)(.*)"
	local indent, marker, buffer, content = string.match(line_text, pattern)

	if indent == nil then
		return false, {}
	end

	return true,
		{
			ordered = true,
			marker = marker,
			indent_spaces = string.len(indent),
			content = content,
			preamble_length = string.len(indent) + string.len(marker) + string.len(buffer),
		}
end

---@param line_text string Text of line to parse
---@return boolean # True if line is an unordered list item
---@return LineInfo # Parsed info for this line
utils.parse_unordered_list_item_text = function(line_text)
	local pattern = "^(%s*)(%-)(%s+)(.*)"
	local indent, marker, buffer, content = string.match(line_text, pattern)

	if indent == nil then
		return false, {}
	end

	return true,
		{
			ordered = false,
			marker = marker,
			indent_spaces = string.len(indent),
			content = content,
			preamble_length = string.len(indent) + string.len(marker) + string.len(buffer),
		}
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
	local _, info = utils.parse_ordered_list_item_text(line_text)
	info.marker = string.format("%d.", index)
	local new_line_text = utils.generate_text(info)
	vim.api.nvim_buf_set_lines(0, line_num - 1, line_num, true, { new_line_text })
end

---@param line_num integer 1-indexed line number to read from
---@return string # Text content of that line
utils.read_buffer_line = function(line_num)
	return vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, true)[1]
end

---@param info LineInfo
---@return string # String generated from LineInfo input
utils.generate_text = function(info)
	return string.rep(" ", info.indent_spaces) .. info.marker .. " " .. info.content
end

return Module
