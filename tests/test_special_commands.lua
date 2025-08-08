local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality
local child = MiniTest.new_child_neovim()

-- local leader = child.lua_get("vim.g.mapleader")

local T = new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "scripts/minimal_init.lua" })
			child.lua([[require('smark').setup()]])
			child.g.mapleader = " "
			child.bo.filetype = "markdown"
		end,
		post_once = child.stop,
	},
})

T["normal"] = new_set()

T["normal"]["<leader>lf formats list"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"1. Foo",
		" 1. Bar",
		"999999999. Baz",
		"     - Noice",
		"     - Sheesh",
	})
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.type_keys(" lf")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 5, true)
	local expected_buffer = {
		"1. Foo",
		"2. Bar",
		"3. Baz",
		"   - Noice",
		"   - Sheesh",
	}

	eq(result_buffer, expected_buffer)
end

T["normal"]["<leader>lo toggles ordered type for contiguous siblings"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"1. Foo",
		"   - Bar",
		"   - Baz",
		"   - Noice",
		"2. Sheesh",
	})
	child.api.nvim_win_set_cursor(0, { 5, 0 })
	child.type_keys(" lo")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 5, true)
	local expected_buffer = {
		"- Foo",
		"  - Bar",
		"  - Baz",
		"  - Noice",
		"- Sheesh",
	}

	eq(result_buffer, expected_buffer)
end

T["normal"]["<leader>lx toggles completion status for task list elements along with parents' if appropriate"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"1. [ ] Foo",
		"   - [x] Bar",
		"   - [ ] Baz",
	})
	child.api.nvim_win_set_cursor(0, { 3, 0 })
	child.type_keys(" lx")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 3, true)
	local expected_buffer = {
		"1. [x] Foo",
		"   - [x] Bar",
		"   - [x] Baz",
	}

	eq(result_buffer, expected_buffer)
end

T["normal"]["<leader>lt toggles task list items for contiguous siblings"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"1. Foo",
		"   - Bar",
		"     1. Baz",
		"   - Sheesh",
	})
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys(" lt")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 4, true)
	local expected_buffer = {
		"1. Foo",
		"   - [ ] Bar",
		"     1. Baz",
		"   - [ ] Sheesh",
	}

	eq(result_buffer, expected_buffer)
end

T["normal"]["list block toggle should promote whole paragraph with each line into a list element"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"Sheesh",
		"",
		"Foo",
		"Bar",
		"Baz",
		"",
		"Sheesh",
	})
	child.api.nvim_win_set_cursor(0, { 3, 0 })
	child.type_keys(" ll")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 7, true)
	local expected_buffer = {
		"Sheesh",
		"",
		"- Foo",
		"- Bar",
		"- Baz",
		"",
		"Sheesh",
	}

	eq(result_buffer, expected_buffer)
end

T["visual"] = new_set()

T["visual"]["<leader>lo toggles ordered type"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"1. Foo",
		"   - Bar",
		"   - Baz",
		"   - Noice",
		"2. Sheesh",
	})
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys("Vj lo")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 5, true)
	local expected_buffer = {
		"1. Foo",
		"   1. Bar",
		"   2. Baz",
		"   - Noice",
		"2. Sheesh",
	}

	eq(result_buffer, expected_buffer)
end

T["visual"]["<leader>lx toggles completion status"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"1. [ ] Foo",
		"   - [ ] Bar",
		"   - [ ] Baz",
	})
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys("Vk lx")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 3, true)
	local expected_buffer = {
		"1. [x] Foo",
		"   - [x] Bar",
		"   - [x] Baz",
	}

	eq(result_buffer, expected_buffer)
end

T["visual"]["task item toggle should work in visual mode"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"1. Foo",
		"   - Bar",
		"     1. Baz",
		"   - Sheesh",
	})
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys("Vj lt")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 4, true)
	local expected_buffer = {
		"1. Foo",
		"   - [ ] Bar",
		"     1. [ ] Baz",
		"   - Sheesh",
	}

	eq(result_buffer, expected_buffer)
end

return T
