local Module = {}
local utils = {}

Module.setup = function(_)
	-- nothing for now
end

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "markdown", "text" },
	callback = function()
		vim.keymap.set("i", "<CR>", function()
			local cursor_row_1_based, _ = table.unpack(vim.api.nvim_win_get_cursor(0))
			local cursor_line_text = vim.api.nvim_buf_get_lines(0, cursor_row_1_based - 1, cursor_row_1_based, true)[1]
			local cursor_on_bulleted_line = utils.is_bulleted_line(cursor_line_text)

			if cursor_on_bulleted_line then
				vim.api.nvim_buf_set_lines(0, cursor_row_1_based, cursor_row_1_based, true, { "- " })
				local target_col_1_based = string.len(
					vim.api.nvim_buf_get_lines(0, cursor_row_1_based, cursor_row_1_based + 1, true)[1]
				) + 1
				vim.api.nvim_win_set_cursor(0, { cursor_row_1_based + 1, target_col_1_based })
			else
				local cr = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
				vim.api.nvim_feedkeys(cr, "n", false)
			end
		end, { buffer = true })
		vim.keymap.set("n", "o", function()
			local cursor_row_1_based, _ = table.unpack(vim.api.nvim_win_get_cursor(0))
			local cursor_line_text = vim.api.nvim_buf_get_lines(0, cursor_row_1_based - 1, cursor_row_1_based, true)[1]
			local cursor_on_bulleted_line = utils.is_bulleted_line(cursor_line_text)

			if cursor_on_bulleted_line then
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

--- @param line_text string Text of line to evaluate
--- @return boolean is_bulleted True if line_num is a bulleted line, false otherwise
utils.is_bulleted_line = function(line_text)
	local std_bullet_regex = "^%s*[%+%-%*]%s+.*"
	local match = string.find(line_text, std_bullet_regex)
	if match ~= nil then
		return true
	end
	return false
end

return Module
