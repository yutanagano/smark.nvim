local callback = require("smark.callback")

local smark = {}

smark.setup = function(_)
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "markdown", "text" },
		callback = function()
			vim.keymap.set("i", "<CR>", callback.insert_newline, { buffer = true })
			vim.keymap.set("i", "<C-t>", callback.insert_indent, { buffer = true })
			vim.keymap.set("i", "<C-d>", callback.insert_unindent, { buffer = true })
			vim.keymap.set("n", ">>", callback.normal_indent, { buffer = true })
			vim.keymap.set("n", "<<", callback.normal_unindent, { buffer = true })
			vim.keymap.set("n", ">", callback.normal_indent_op, { expr = true, buffer = true })
			vim.keymap.set("n", "<", callback.normal_unindent_op, { expr = true, buffer = true })
			vim.keymap.set("n", "o", callback.normal_o, { buffer = true })
			vim.keymap.set("n", "<leader>ll", callback.normal_format, { buffer = true })
			vim.keymap.set("n", "<leader>lo", callback.normal_ordered, { buffer = true })
			vim.keymap.set("n", "<leader>lx", callback.normal_checkbox, { buffer = true })
			vim.keymap.set("x", ">", callback.visual_indent, { expr = true, buffer = true })
			vim.keymap.set("x", "<", callback.visual_unindent, { expr = true, buffer = true })
			vim.keymap.set("x", "<leader>lo", callback.visual_ordered, { expr = true, buffer = true })
			vim.keymap.set("x", "<leader>lx", callback.visual_checkbox, { expr = true, buffer = true })
		end,
	})
end

return smark
