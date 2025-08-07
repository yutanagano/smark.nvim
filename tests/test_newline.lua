local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality
local child = MiniTest.new_child_neovim()

local T = new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "scripts/minimal_init.lua" })
			child.lua([[require('smark').setup()]])
			child.bo.filetype = "markdown"
		end,
		post_once = child.stop,
	},
})

T["insert_CR"] = new_set()

T["insert_CR"]["works as normal when not on list"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"Foobar",
		"",
		"- Test",
	})
	child.api.nvim_win_set_cursor(0, { 1, 3 })
	child.type_keys("i<CR>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 4, true)
	local expected_buffer = {
		"Foo",
		"bar",
		"",
		"- Test",
	}

	eq(result_buffer, expected_buffer)
end

T["insert_CR"]["auto-generates a new list element"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, { "Foobar", "", "- Test" })
	child.api.nvim_win_set_cursor(0, { 3, 0 })
	child.type_keys("A<CR>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 4, true)
	local expected_buffer = { "Foobar", "", "- Test", "- " }

	eq(result_buffer, expected_buffer)
end

T["insert_CR"]["auto-indents if preceding content ends with colon"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, { "Foobar", "", "- Test:" })
	child.api.nvim_win_set_cursor(0, { 3, 0 })
	child.type_keys("A<CR>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 4, true)
	local expected_buffer = { "Foobar", "", "- Test:", "  - " }

	eq(result_buffer, expected_buffer)
end

T["insert_CR"]["auto-numbers ordered list elements"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, { "Foobar", "", "1. Test" })
	child.api.nvim_win_set_cursor(0, { 3, 0 })
	child.type_keys("A<CR>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 4, true)
	local expected_buffer = { "Foobar", "", "1. Test", "2. " }

	eq(result_buffer, expected_buffer)
end

T["insert_CR"]["auto-unindents if current list item empty"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, { "Foobar", "", "- Test:", "  - " })
	child.api.nvim_win_set_cursor(0, { 4, 0 })
	child.type_keys("A<CR>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 4, true)
	local expected_buffer = { "Foobar", "", "- Test:", "- " }

	eq(result_buffer, expected_buffer)
end

T["insert_CR"]["exits list mode if current list item empty at root level"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, { "Foobar", "", "- Test", "- " })
	child.api.nvim_win_set_cursor(0, { 4, 0 })
	child.type_keys("A<CR>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 4, true)
	local expected_buffer = { "Foobar", "", "- Test", "" }

	eq(result_buffer, expected_buffer)
end

T["insert_CR"]["detects ordered type of nested level automatically when auto-indenting"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, { "- Test:", "  1. Foo" })
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.type_keys("A<CR>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 3, true)
	local expected_buffer = { "- Test:", "  1. ", "  2. Foo" }

	eq(result_buffer, expected_buffer)
end

T["insert_CR"]["detects ordered type of parent level automatically when auto-unindenting"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, { "1. Test:", "   - Foo", "   - " })
	child.api.nvim_win_set_cursor(0, { 3, 0 })
	child.type_keys("A<CR>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 3, true)
	local expected_buffer = { "1. Test:", "   - Foo", "2. " }

	eq(result_buffer, expected_buffer)
end

T["insert_CR"]["understands multi-line bullets"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"- Test",
		"  bullet",
	})
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys("A<CR>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 3, true)
	local expected_buffer = {
		"- Test",
		"  bullet",
		"- ",
	}

	eq(result_buffer, expected_buffer)
end

T["insert_CR"]["splits content correctly in multi-line lists, case 1"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"- Test",
		"  bullet",
	})
	child.api.nvim_win_set_cursor(0, { 2, 5 })
	child.type_keys("i<CR>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 3, true)
	local expected_buffer = {
		"- Test",
		"  bul",
		"- let",
	}

	eq(result_buffer, expected_buffer)
end

T["insert_CR"]["splits content correctly in multi-line lists, case 2"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"- Test",
		"  bullet",
	})
	child.api.nvim_win_set_cursor(0, { 2, 2 })
	child.type_keys("i<CR>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 2, true)
	local expected_buffer = {
		"- Test",
		"- bullet",
	}

	eq(result_buffer, expected_buffer)
end

T["insert_CR"]["splits content correctly in multi-line lists, case 3"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"- Test",
		"  bullet",
	})
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.type_keys("A<CR>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 2, true)
	local expected_buffer = {
		"- Test",
		"- bullet",
	}

	eq(result_buffer, expected_buffer)
end

T["insert_CR"]["understands task list elements"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, { "- [ ] Test" })
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.type_keys("A<CR>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 2, true)
	local expected_buffer = { "- [ ] Test", "- [ ] " }

	eq(result_buffer, expected_buffer)
end

T["insert_CR"]["understands alternative list element markers"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, { "- Foo", "* Bar", "+ Baz" })
	child.api.nvim_win_set_cursor(0, { 3, 0 })
	child.type_keys("A<CR>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 4, true)
	local expected_buffer = { "- Foo", "- Bar", "- Baz", "- " }

	eq(result_buffer, expected_buffer)
end

T["insert_CR"]["auto-formats list block"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, { "- Foo", " - Bar", "- Baz", "  1. Foo", " 2. Bar" })
	child.api.nvim_win_set_cursor(0, { 5, 0 })
	child.type_keys("A<CR>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 6, true)
	local expected_buffer = { "- Foo", "- Bar", "- Baz", "  1. Foo", "1. Bar", "2. " }

	eq(result_buffer, expected_buffer)
end

T["insert_CR"]["propagates indent rule changes due to numbering"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"1. Foo",
		"2. Bar",
		"3. Baz",
		"4. Foofoo",
		"5. Foobar",
		"6. Foobaz",
		"7. Barfoo",
		"8. Barbar",
		"9. Barbaz:",
		"   - Bazfoo:",
		"     1. Bazbar",
	})
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys("a<CR>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 12, true)
	local expected_buffer = {
		"1. Foo",
		"2. ",
		"3. Bar",
		"4. Baz",
		"5. Foofoo",
		"6. Foobar",
		"7. Foobaz",
		"8. Barfoo",
		"9. Barbar",
		"10. Barbaz:",
		"    - Bazfoo:",
		"      1. Bazbar",
	}

	eq(result_buffer, expected_buffer)
end

T["insert_CR"]["infers is_ordered type from context"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"1. Foo",
		"   - Bar",
		"2. Baz:",
	})
	child.api.nvim_win_set_cursor(0, { 3, 0 })
	child.type_keys("A<CR>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 4, true)
	local expected_buffer = {
		"1. Foo",
		"   - Bar",
		"2. Baz:",
		"   - ",
	}

	eq(result_buffer, expected_buffer)
end

T["insert_CR"]["sets parent to incomplete if appropriate"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"1. [x] Foo",
		"   - [x] Bar",
	})
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys("A<CR>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 3, true)
	local expected_buffer = {
		"1. [ ] Foo",
		"   - [x] Bar",
		"   - [ ] ",
	}

	eq(result_buffer, expected_buffer)
end

T["insert_CR"]["sets parent to complete if appropriate"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"1. [ ] Foo",
		"   - [x] Bar",
		"   - [ ] ",
	})
	child.api.nvim_win_set_cursor(0, { 3, 0 })
	child.type_keys("A<CR>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 3, true)
	local expected_buffer = {
		"1. [x] Foo",
		"   - [x] Bar",
		"2. [ ] ",
	}

	eq(result_buffer, expected_buffer)
end

T["normal_o"] = new_set()

T["normal_o"]["auto-generates a new list element"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, { "- Test" })
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.type_keys("o")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 2, true)
	local expected_buffer = { "- Test", "- " }

	eq(result_buffer, expected_buffer)
end

T["normal_o"]["auto-indents if preceding content ends with colon"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, { "- Test:" })
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.type_keys("o")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 2, true)
	local expected_buffer = { "- Test:", "  - " }

	eq(result_buffer, expected_buffer)
end

T["normal_o"]["acts normal outside of list block"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, { "- Test", "", "This is normal text" })
	child.api.nvim_win_set_cursor(0, { 3, 0 })
	child.type_keys("o")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 4, true)
	local expected_buffer = { "- Test", "", "This is normal text", "" }

	eq(result_buffer, expected_buffer)
end

T["normal_o"]["acts normal with empty list item at the end of a block"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, { "- Test", "- " })
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys("o")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 3, true)
	local expected_buffer = { "- Test", "- ", "" }

	eq(result_buffer, expected_buffer)
end

T["normal_o"]["propagates indent rule changes due to numbering"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"1. Foo",
		"2. Bar",
		"3. Baz",
		"4. Foofoo",
		"5. Foobar",
		"6. Foobaz",
		"7. Barfoo",
		"8. Barbar",
		"9. Barbaz:",
		"   - Bazfoo:",
		"     1. Bazbar",
	})
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.type_keys("o")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 12, true)
	local expected_buffer = {
		"1. Foo",
		"2. ",
		"3. Bar",
		"4. Baz",
		"5. Foofoo",
		"6. Foobar",
		"7. Foobaz",
		"8. Barfoo",
		"9. Barbar",
		"10. Barbaz:",
		"    - Bazfoo:",
		"      1. Bazbar",
	}

	eq(result_buffer, expected_buffer)
end

T["normal_o"]["updates parent completion status if appropriate"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"1. [x] Foo",
		"   - [x] Bar",
	})
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys("o")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 3, true)
	local expected_buffer = {
		"1. [ ] Foo",
		"   - [x] Bar",
		"   - [ ] ",
	}

	eq(result_buffer, expected_buffer)
end

return T
