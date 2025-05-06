local smark = {}

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "markdown", "text" },
	callback = function()
		vim.keymap.set("i", "<CR>", smark.insert_bullet, { buffer = true })
	end,
})

--- @param line_text string
--- @return boolean: true if line_num is a bulleted line, false otherwise
local function is_bulleted_line(line_text)
	local std_bullet_regex = "^%s*[%+%-%*]%s+.*"
	local match = string.find(line_text, std_bullet_regex)
	if match ~= nil then
		return true
	end
	return false
end

smark.insert_bullet = function()
	local cursor_line_num = vim.fn.line(".")
	local next_line_num = cursor_line_num + 1
	local cursor_line_text = vim.fn.getline(".")
	local cursor_on_bulleted_line = is_bulleted_line(cursor_line_text)

	if cursor_on_bulleted_line then
		vim.fn.append(cursor_line_num, "- ")
		local col = string.len(vim.fn.getline(next_line_num)) + 1
		vim.fn.setpos(".", { 0, next_line_num, col })
	end
end

return smark
