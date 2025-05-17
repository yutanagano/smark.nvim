---@class TextBlockBounds
---@field upper integer 1-indexed upper bound line number
---@field lower integer 1-indexed lower bound line number

local list_item = require("smark.list_item")
local format = require("smark.format")

local smark = {}
local private = {}

smark.setup = function(_)
	-- nothing for now
end

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "markdown", "text" },
	callback = function()
		vim.keymap.set("i", "<CR>", function()
			local cursor_coords, bounds, li_array = private.get_list_block_around_cursor()

			if bounds == nil then
				local newline = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
				vim.api.nvim_feedkeys(newline, "n", false)
				return
			end

			local rel_cursor_coords = { row1 = cursor_coords.row1 - bounds.upper + 1, col0 = cursor_coords.col0 }
			local ispec_array = format.fix(li_array, rel_cursor_coords)
			private.reflect_newline(li_array, ispec_array, rel_cursor_coords)
			format.fix_numbering(li_array, ispec_array, rel_cursor_coords)

			local lis_as_strings = {}
			for i, li in ipairs(li_array) do
				lis_as_strings[i] = list_item.to_string(li)
			end
			vim.api.nvim_buf_set_lines(0, bounds.upper - 1, bounds.lower, true, lis_as_strings)

			cursor_coords = { row1 = rel_cursor_coords.row1 + bounds.upper - 1, col0 = rel_cursor_coords.col0 }
			vim.api.nvim_win_set_cursor(0, { cursor_coords.row1, cursor_coords.col0 })
		end, { buffer = true })
		-- vim.keymap.set("n", "o", function()
		-- 	local cursor_row_1_based, _ = table.unpack(vim.api.nvim_win_get_cursor(0))
		-- 	local current_li = list_item.from_line(cursor_row_1_based)
		--
		-- 	if current_li == nil or current_li.content == "" then
		-- 		vim.api.nvim_buf_set_lines(0, cursor_row_1_based, cursor_row_1_based, true, { "" })
		-- 		vim.api.nvim_win_set_cursor(0, { cursor_row_1_based + 1, 0 })
		-- 		vim.cmd("startinsert!")
		-- 		return
		-- 	end
		--
		-- 	local next_li = list_item.get_next(current_li, "")
		--
		-- 	vim.api.nvim_buf_set_lines(
		-- 		0,
		-- 		cursor_row_1_based,
		-- 		cursor_row_1_based,
		-- 		true,
		-- 		{ list_item.to_string(next_li) }
		-- 	)
		--
		-- 	vim.api.nvim_win_set_cursor(0, { cursor_row_1_based + 1, 0 })
		-- 	vim.cmd("startinsert!")
		-- end, { buffer = true })
	end,
})

---@return CursorCoords
---@return TextBlockBounds|nil # Boundaries of containing list block, nil if cursor not in list block
---@return ListItem[] # Array of list items detected inside the list block
private.get_list_block_around_cursor = function()
	local cursor_row1, cursor_col0 = table.unpack(vim.api.nvim_win_get_cursor(0))
	local cursor_coords = { row1 = cursor_row1, col0 = cursor_col0 }

	local li = list_item.from_line(cursor_row1)

	if li == nil then
		return cursor_coords, nil, {}
	end

	local bounds = { upper = cursor_row1, lower = cursor_row1 }
	local upper_bound_found, lower_bound_found = false, false
	local li_array = {}

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

	return cursor_coords, bounds, li_array
end

---Edit li_array, ispec_array and rel_cursor_coords in place to reflect the entry of <CR> at the specified relative cursor coordinates.
---@param li_array ListItem[]
---@param ispec_array indent_spec[]
---@param rel_cursor_coords CursorCoords
function private.reflect_newline(li_array, ispec_array, rel_cursor_coords)
	local current_li = li_array[rel_cursor_coords.row1]
	local current_ispec = ispec_array[rel_cursor_coords.row1]

	if rel_cursor_coords.col0 < current_li.original_preamble_length then
		local new_li = list_item.get_empty_like(current_li)
		table.insert(li_array, rel_cursor_coords.row1, new_li)
		local new_ispec = format.get_indent_spec_like(current_ispec)
		table.insert(ispec_array, rel_cursor_coords.row1, new_ispec)
		rel_cursor_coords.row1 = rel_cursor_coords.row1 + 1
		return
	end

	if rel_cursor_coords.row1 == #li_array and current_li.content == "" then
		current_li.indent_spaces = -1
		rel_cursor_coords.col0 = 0
		return
	end

	local content_after_cursor = list_item.get_content_after_cursor(current_li, rel_cursor_coords.col0)
	list_item.truncate_content_at_cursor(current_li, rel_cursor_coords.col0)

	local new_li = list_item.get_empty_like(current_li)
	local new_ispec = format.get_indent_spec_like(current_ispec)
	new_li.content = content_after_cursor
	if string.sub(current_li.content, -1) == ":" and content_after_cursor == "" then
		local new_ispaces = list_item.get_nested_indent_spaces(current_li)
		new_li.indent_spaces = new_ispaces
		table.insert(new_ispec, new_ispaces)
	end
	table.insert(li_array, rel_cursor_coords.row1 + 1, new_li)
	table.insert(ispec_array, rel_cursor_coords.row1 + 1, new_ispec)

	rel_cursor_coords.row1 = rel_cursor_coords.row1 + 1
	rel_cursor_coords.col0 = list_item.get_preamble_length(new_li)
end

return smark
