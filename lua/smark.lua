local Module = {}
local utils = {}

Module.setup = function(_)
	-- nothing for now
end

Module.carriage_return = function()
	local cursor_line_num = vim.fn.line(".")
	local next_line_num = cursor_line_num + 1
	local cursor_line_text = vim.fn.getline(".")
	local cursor_on_bulleted_line = utils.is_bulleted_line(cursor_line_text)

	if cursor_on_bulleted_line then
		vim.fn.append(cursor_line_num, "- ")
		local col = string.len(vim.fn.getline(next_line_num)) + 1
		vim.fn.setpos(".", { 0, next_line_num, col })
	else
		local cr = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
		vim.api.nvim_feedkeys(cr, "n", false)
	end
end

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

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "markdown", "text" },
	callback = function()
		vim.keymap.set("i", "<CR>", Module.carriage_return, { buffer = true })
	end,
})

return Module
