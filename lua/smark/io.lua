local M = {}

---Scan current buffer (0) text around the given line number, and if this text is part of a list item, parse the list item and return, along with bounds.
---@param line_num integer 1-indexed line number to scan from
---@return ListItem|nil # Nil if line is not inside list item
---@return TextBlockBounds # Bounds containing list item
---@return string[] raw Raw content within bounds
---@return integer preamble_len The original number of characters before the content begins at the current line
function M.scan_text_around_line(line_num)
	local li = { spec = nil, content = {} }
	local bounds = { upper = line_num, lower = line_num }
	local raw = {}

	local buf_line_count = vim.api.nvim_buf_line_count(0)
	local raw_line, content, preamble_len, li_spec = M.pattern_match_line(line_num)

	if li_spec == nil and content == "" then
		return nil, bounds, {}, preamble_len
	end

	li.spec = li_spec
	li.content = { content }
	raw = { raw_line }

	if li.spec == nil then
		for current_lnum = line_num - 1, 1, -1 do
			raw_line, content, _, li_spec = M.pattern_match_line(current_lnum)

			if content == "" then
				break
			end

			table.insert(li.content, 1, content)
			table.insert(raw, 1, raw_line)

			if li_spec ~= nil then
				li.spec = li_spec
				bounds.upper = current_lnum
				break
			end
		end

		if li.spec == nil then
			return nil, bounds, {}, preamble_len
		end
	end

	for current_lnum = line_num + 1, buf_line_count do
		raw_line, content, _, li_spec = M.pattern_match_line(current_lnum)

		if content == "" or li_spec ~= nil then
			bounds.lower = current_lnum - 1
			break
		end

		table.insert(li.content, content)
		table.insert(raw, raw_line)

		if current_lnum == buf_line_count then
			bounds.lower = current_lnum
		end
	end

	if #li.content == 0 then
		error("empty content!")
	end

	return li, bounds, raw, preamble_len
end

---@param line_num integer 1-indexed line number to pattern-match
---@return string raw Raw content of that line
---@return string content Content detected in text
---@return integer preamble_len Number of characters before the content begins
---@return ListSpec|nil # Nil if line does not contain list item root
function M.pattern_match_line(line_num)
	local text = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, true)[1]
	local pattern = "^((%s*)%d+[%.%)]%s+)(.*)"
	local is_ordered = true
	local preamble, indent, content = string.match(text, pattern)

	if preamble == nil then
		pattern = "^((%s*)[%-%*%+]%s+)(.*)"
		is_ordered = false
		preamble, indent, content = string.match(text, pattern)

		if preamble == nil then
			pattern = "^(%s*)(.*)"
			preamble, content = string.match(text, pattern)
			return text, content, string.len(preamble), nil
		end
	end

	local preamble_len = string.len(preamble)
	local is_task, is_completed, corrected_content, corrected_preamble_len = M.pattern_match_task_root(text)
	if is_task then
		preamble_len = corrected_preamble_len
		content = corrected_content
	end

	local li_spec = {
		is_ordered = is_ordered,
		is_task = is_task,
		is_completed = is_completed,
		index = 1,
		indent_spaces = string.len(indent),
	}

	return text, content, preamble_len, li_spec
end

---@param text string Text of line to parse
---@return boolean # True if line is task item
---@return boolean # True if marked as completed
---@return string # Detected content correcting for task marker
---@return integer # Preamble length correcting for task marker
function M.pattern_match_task_root(text)
	local pattern = "^(%s*%-?%d*%.?%s%s?%s?%s?%[([%sxX])%]%s+)(.*)"
	local preamble, completion, content = string.match(text, pattern)

	if preamble == nil then
		return false, false, "", 0
	end

	local is_completed = completion == "x" or completion == "X"

	return true, is_completed, content, string.len(preamble)
end

return M
