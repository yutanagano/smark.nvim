local utils = {}

---@param line_num integer 1-indexed line number to read from
---@return string # Text content of that line
utils.read_buffer_line = function(line_num)
	return vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, true)[1]
end

return utils
