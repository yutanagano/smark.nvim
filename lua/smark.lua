--- @class LineInfo
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
			local line_text = vim.api.nvim_buf_get_lines(0, cursor_row_1_based - 1, cursor_row_1_based, true)[1]

			local text_up_to_cursor = string.sub(line_text, 1, cursor_col_0_based)
			local text_after_cursor = string.sub(line_text, cursor_col_0_based + 1)

			local cursor_on_list = utils.parse_line(text_up_to_cursor)

			if not cursor_on_list then
				local cr = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
				vim.api.nvim_feedkeys(cr, "n", false)
				return
			end

			vim.api.nvim_buf_set_lines(0, cursor_row_1_based - 1, cursor_row_1_based, true, { text_up_to_cursor })
			vim.api.nvim_buf_set_lines(0, cursor_row_1_based, cursor_row_1_based, true, { "- " .. text_after_cursor })
			vim.api.nvim_win_set_cursor(0, { cursor_row_1_based + 1, 2 })
		end, { buffer = true })
		vim.keymap.set("n", "o", function()
			local cursor_row_1_based, _ = table.unpack(vim.api.nvim_win_get_cursor(0))
			local line_text = vim.api.nvim_buf_get_lines(0, cursor_row_1_based - 1, cursor_row_1_based, true)[1]
			local cursor_on_list = utils.parse_line(line_text)

			if cursor_on_list then
				vim.api.nvim_buf_set_lines(0, cursor_row_1_based, cursor_row_1_based, true, { "- " })
				vim.api.nvim_win_set_cursor(0, { cursor_row_1_based + 1, 0 })
				vim.cmd("startinsert!")
			else
				vim.api.nvim_buf_set_lines(0, cursor_row_1_based, cursor_row_1_based, true, { "" })
				vim.api.nvim_win_set_cursor(0, { cursor_row_1_based + 1, 0 })
				vim.cmd("startinsert!")
			end
		end, { buffer = true })
	end,
})

--- @param line_text string Text of line to parse
--- @return boolean is_list True if line is a list item
--- @return LineInfo info
utils.parse_line = function(line_text)
	local parse_regex = "^(%s*)(%-)(%s+)(.*)"
	local indent, marker, intermediate, content = string.match(line_text, parse_regex)

	if indent == nil then
		return false, {}
	end

	local info = {
		marker = marker,
		indent_spaces = string.len(indent),
		content = content,
		preamble_length = string.len(indent) + string.len(marker) + string.len(intermediate),
	}

	return true, info
end

return Module
