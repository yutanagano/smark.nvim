--- @class TextBlockBounds
--- @field upper integer 1-indexed upper bound line number
--- @field lower integer 1-indexed lower bound line number

local list_item = require("smark.list_item")
local indent_rule = require("smark.indent_rule")
local utils = require("smark.utils")

local smark = {}
local private = {}

smark.setup = function(_)
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
			local current_li = list_item.from_string(text_up_to_cursor)

			if current_li == nil then
				local newline = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
				vim.api.nvim_feedkeys(newline, "n", false)
				return
			end

			if current_li.content == "" and text_after_cursor == "" then
				vim.api.nvim_buf_set_lines(0, cursor_row_1_based - 1, cursor_row_1_based, true, { "" })
				return
			end

			local next_li = list_item.get_next(current_li, text_after_cursor)

			vim.api.nvim_buf_set_lines(0, cursor_row_1_based - 1, cursor_row_1_based, true, { text_up_to_cursor })
			vim.api.nvim_buf_set_lines(
				0,
				cursor_row_1_based,
				cursor_row_1_based,
				true,
				{ list_item.to_string(next_li) }
			)

			if current_li.is_ordered then
				private.reindex_ordered_block_around(cursor_row_1_based)
			end

			local bounds, li_array = private.get_containing_list_block_bounds(cursor_row_1_based)
			assert(bounds ~= nil)
			private.standardize_list_block(li_array)
			local lis_as_strings = {}
			for i, li in ipairs(li_array) do
				lis_as_strings[i] = list_item.to_string(li)
			end
			vim.api.nvim_buf_set_lines(0, bounds.upper - 1, bounds.lower, true, lis_as_strings)

			local next_li = list_item.from_line(cursor_row_1_based + 1)
			assert(next_li ~= nil, "Newly generated line after <CR> does not look like a list item")
			vim.api.nvim_win_set_cursor(0, { cursor_row_1_based + 1, list_item.get_preamble_length(next_li) })
		end, { buffer = true })
		vim.keymap.set("n", "o", function()
			local cursor_row_1_based, _ = table.unpack(vim.api.nvim_win_get_cursor(0))
			local current_li = list_item.from_line(cursor_row_1_based)

			if current_li == nil or current_li.content == "" then
				vim.api.nvim_buf_set_lines(0, cursor_row_1_based, cursor_row_1_based, true, { "" })
				vim.api.nvim_win_set_cursor(0, { cursor_row_1_based + 1, 0 })
				vim.cmd("startinsert!")
				return
			end

			local next_li = list_item.get_next(current_li, "")

			vim.api.nvim_buf_set_lines(
				0,
				cursor_row_1_based,
				cursor_row_1_based,
				true,
				{ list_item.to_string(next_li) }
			)

			if current_li.is_ordered then
				private.reindex_ordered_block_around(cursor_row_1_based)
			end

			vim.api.nvim_win_set_cursor(0, { cursor_row_1_based + 1, 0 })
			vim.cmd("startinsert!")
		end, { buffer = true })
	end,
})

---Only call this function once you are sure that line_num contains an ordered list item.
---Re-indexes the list markers for all ordered list items contiguous with, and including line_num.
---@param line_num integer 1-indexed line number to survey around for a ordered list block
private.reindex_ordered_block_around = function(line_num)
	local block_row_bounds_1_based = private.survey_ordered_block(line_num)
	for line_num_1_based = block_row_bounds_1_based[1], block_row_bounds_1_based[2] do
		local index = line_num_1_based - block_row_bounds_1_based[1] + 1
		private.reindex_ordered_list_item(line_num_1_based, index)
	end
end

---If the supplied line number is inside of a list block (consecutive lines containing list elements), return its upper and lower boundaires as well as an array of constituent list items
---@param line_num integer 1-indexed line number
---@return TextBlockBounds|nil # Two-tuple of 1-indexed line numbers of ( upper, lower ) boundaries of containing list block, nil if not in list block
---@return ListItem[] # Array of list items detected inside the list block
private.get_containing_list_block_bounds = function(line_num)
	local bounds = { upper = line_num, lower = line_num }
	local upper_bound_found, lower_bound_found = false, false
	local li_array = {}

	local li = list_item.from_line(line_num)
	if li == nil then
		return nil, li_array
	end

	table.insert(li_array, li)

	while not upper_bound_found do
		if bounds.upper == 1 then
			upper_bound_found = true
		else
			li = list_item.from_line(bounds.upper - 1)
			if li == nil then
				upper_bound_found = true
			else
				bounds.upper = bounds.upper - 1
				table.insert(li_array, 1, li)
			end
		end
	end

	while not lower_bound_found do
		if bounds.lower == vim.api.nvim_buf_line_count(0) then
			lower_bound_found = true
		else
			li = list_item.from_line(bounds.lower + 1)
			if li == nil then
				lower_bound_found = true
			else
				bounds.lower = bounds.lower + 1
				table.insert(li_array, li)
			end
		end
	end

	return bounds, li_array
end

---Standardize a list block, comprised of consecutive list items (in-place)
---@param li_array ListItem[]
private.standardize_list_block = function(li_array)
	local bias = li_array[1].indent_spaces
	local irule = indent_rule.new(li_array[1].is_ordered)

	for _, li in ipairs(li_array) do
		li.indent_spaces = li.indent_spaces - bias
		indent_rule.snap(irule, li)
	end
end

---Only call this function once you are sure that line_num contains an ordered list item.
---@param line_num integer 1-indexed line number to survey around for a ordered list block
---@return integer[] # Two-tuple of 1-indexed line numbers of ( upper, lower ) boundaries of ordered list block
private.survey_ordered_block = function(line_num)
	local upper_bound, lower_bound = line_num, line_num
	local upper_bound_found, lower_bound_found = false, false

	while not upper_bound_found do
		if upper_bound == 1 then
			upper_bound_found = true
		else
			upper_bound = upper_bound - 1
			local line_text = utils.read_buffer_line(upper_bound)
			local match = list_item.parse_ordered_list_item_text(line_text)
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
			local match = list_item.parse_ordered_list_item_text(line_text)
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
private.reindex_ordered_list_item = function(line_num, index)
	local line_text = utils.read_buffer_line(line_num)
	local li = list_item.parse_ordered_list_item_text(line_text)

	assert(
		li ~= nil,
		string.format(
			"Attempted to reindex a line that does not look like an ordered list item at line number %d",
			line_num
		)
	)

	li.index = index
	local new_line_text = list_item.to_string(li)
	vim.api.nvim_buf_set_lines(0, line_num - 1, line_num, true, { new_line_text })
end

return smark
