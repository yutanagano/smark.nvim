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

T["insert"] = new_set()

T["insert"]["<C-t> indents normally outside of list blocks"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"Foo",
		"Bar",
	})
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.type_keys("a<C-t>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 2, true)
	local expected_buffer = {
		"    Foo",
		"Bar",
	}

	eq(result_buffer, expected_buffer)
end

T["insert"]["<C-t> indents"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, { "- Foo", "- Bar" })
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys("a<C-t>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 2, true)
	local expected_buffer = { "- Foo", "  - Bar" }

	eq(result_buffer, expected_buffer)
end

T["insert"]["<C-d> outdents normally outside of list blocks"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"    Foo",
		"    Bar",
	})
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.type_keys("a<C-d>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 2, true)
	local expected_buffer = {
		"Foo",
		"    Bar",
	}

	eq(result_buffer, expected_buffer)
end

T["insert"]["<C-d> outdents"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, { "- Foo", "  - Bar" })
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys("a<C-d>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 2, true)
	local expected_buffer = { "- Foo", "- Bar" }

	eq(result_buffer, expected_buffer)
end

T["normal"] = new_set()

T["normal"][">> indents"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, { "- Foo", "- Bar" })
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys(">>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 2, true)
	local expected_buffer = { "- Foo", "  - Bar" }

	eq(result_buffer, expected_buffer)
end

T["normal"]["indentation without preceding sibling is a no-op"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"- Foo:",
		"  - Bar",
	})
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys(">>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 2, true)
	local expected_buffer = {
		"- Foo:",
		"  - Bar",
	}

	eq(result_buffer, expected_buffer)
end

T["normal"]["indentation should recognise multi-line lists"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"- Foo",
		"- Bar",
		"  Baz",
	})
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys(">>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 3, true)
	local expected_buffer = {
		"- Foo",
		"  - Bar",
		"    Baz",
	}

	eq(result_buffer, expected_buffer)
end

T["normal"][">> with a preceding count works on multiple lines"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"- Foo",
		"- Bar",
		"- Baz",
	})
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys("2>>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 3, true)
	local expected_buffer = {
		"- Foo",
		"  - Bar",
		"  - Baz",
	}

	eq(result_buffer, expected_buffer)
end

T["normal"]["indentation automatically detects list ordered type of nested level"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"- Foo",
		"- Bar",
		"  1. Baz",
	})
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys(">>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 3, true)
	local expected_buffer = {
		"- Foo",
		"  1. Bar",
		"  2. Baz",
	}

	eq(result_buffer, expected_buffer)
end

T["normal"]["indentation at root moves whole tree up"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"- Foo",
		"  1. Bar",
		"     - Baz",
	})
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.type_keys(">>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 3, true)
	local expected_buffer = {
		"  - Foo",
		"    1. Bar",
		"       - Baz",
	}

	eq(result_buffer, expected_buffer)
end

T["normal"]["<< outdents"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"- Foo",
		"  - Bar",
	})
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys("<lt><lt>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 2, true)
	local expected_buffer = {
		"- Foo",
		"- Bar",
	}

	eq(result_buffer, expected_buffer)
end

T["normal"]["<< with a preceding number outdents multiple lines"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"- Foo:",
		"  - Bar",
		"  - Baz",
	})
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys("2<lt><lt>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 3, true)
	local expected_buffer = {
		"- Foo:",
		"- Bar",
		"- Baz",
	}

	eq(result_buffer, expected_buffer)
end

T["normal"]["outdentation drags along subtree"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"1. Foo:",
		"   - Bar:",
		"     - Baz",
		"   - Noice",
	})
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys("<lt><lt>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 4, true)
	local expected_buffer = {
		"1. Foo:",
		"2. Bar:",
		"   - Baz",
		"   - Noice",
	}

	eq(result_buffer, expected_buffer)
end

T["normal"]["outdentation at root destroys list element"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"- Foo",
		"- Bar",
		"- Baz",
	})
	child.api.nvim_win_set_cursor(0, { 2, 2 })
	child.type_keys("<lt><lt>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 5, true)
	local expected_buffer = {
		"- Foo",
		"",
		"Bar",
		"",
		"- Baz",
	}

	eq(result_buffer, expected_buffer)

	local result_cursor_coords = child.api.nvim_win_get_cursor(0)
	local expected_cursor_coords = { 3, 2 }

	eq(result_cursor_coords, expected_cursor_coords)
end

T["normal"]["outdentation understands multi-line lists"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"- Foo:",
		"  - Bar",
		"    Baz",
	})
	child.api.nvim_win_set_cursor(0, { 3, 0 })
	child.type_keys("<lt><lt>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 3, true)
	local expected_buffer = {
		"- Foo:",
		"- Bar",
		"  Baz",
	}

	eq(result_buffer, expected_buffer)
end

T["normal"]["outdentation at the root on hyperindented lists moves the whole tree left"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"   - Foo:",
		"     1. Bar:",
		"        - Baz",
	})
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.type_keys("<lt><lt>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 3, true)
	local expected_buffer = {
		" - Foo:",
		"   1. Bar:",
		"      - Baz",
	}

	eq(result_buffer, expected_buffer)
end

T["normal"]["> is an indent operator"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"1. Foo",
		"2. Bar",
		"3. Baz",
		"   1. Noice",
		"   2. Sheesh",
	})
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys(">2j")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 5, true)
	local expected_buffer = {
		"1. Foo",
		"   1. Bar",
		"   2. Baz",
		"      1. Noice",
		"   3. Sheesh",
	}

	eq(result_buffer, expected_buffer)
end

T["normal"]["< is an outdent operator"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"1. Foo",
		"   1. Noice",
		"   2. Sheesh",
		"2. Bar",
		"3. Baz",
	})
	child.api.nvim_win_set_cursor(0, { 3, 0 })
	child.type_keys("<lt>k")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 5, true)
	local expected_buffer = {
		"1. Foo",
		"2. Noice",
		"3. Sheesh",
		"4. Bar",
		"5. Baz",
	}

	eq(result_buffer, expected_buffer)
end

T["visual"] = new_set()

T["visual"]["> is an indent operator"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"- Foo",
		"  1. Bar",
		"- Baz",
		"- Noice",
		"  1. Sheesh",
	})
	child.api.nvim_win_set_cursor(0, { 3, 0 })
	child.type_keys("Vj2>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 5, true)
	local expected_buffer = {
		"- Foo",
		"  1. Bar",
		"     1. Baz",
		"     2. Noice",
		"  2. Sheesh",
	}

	eq(result_buffer, expected_buffer)
end

T["visual"]["indentation automatically infers is_ordered types according to spec"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"- Foo",
		"  1. Bar",
		"     - Baz",
		"       1. Noice",
		"- Sheesh",
		"- Boink",
		"  - Doink",
		"    - Yoink",
	})
	child.api.nvim_win_set_cursor(0, { 6, 0 })
	child.type_keys("V2j>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 8, true)
	local expected_buffer = {
		"- Foo",
		"  1. Bar",
		"     - Baz",
		"       1. Noice",
		"- Sheesh",
		"  1. Boink",
		"     - Doink",
		"       1. Yoink",
	}

	eq(result_buffer, expected_buffer)

	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"- Foo",
		"  1. Bar",
		"     - Baz",
		"       1. Noice",
		"- Sheesh",
		"- Boink",
		"  - Doink",
		"    - Yoink",
		"  - Zoink",
	})
	child.api.nvim_win_set_cursor(0, { 6, 0 })
	child.type_keys("V2j>")

	result_buffer = child.api.nvim_buf_get_lines(0, 0, 8, true)
	expected_buffer = {
		"- Foo",
		"  1. Bar",
		"     - Baz",
		"       1. Noice",
		"- Sheesh",
		"  - Boink",
		"    - Doink",
		"      1. Yoink",
	}

	eq(result_buffer, expected_buffer)
end

T["visual"]["< is an outdent operator"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"1. Foo",
		"   1. Bar",
		"      - Baz",
		"      - Noice",
		"      - Sheesh",
	})
	child.api.nvim_win_set_cursor(0, { 5, 0 })
	child.type_keys("V2k2<lt>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 5, true)
	local expected_buffer = {
		"1. Foo",
		"   1. Bar",
		"2. Baz",
		"3. Noice",
		"4. Sheesh",
	}

	eq(result_buffer, expected_buffer)
end

T["visual"]["over-outdentation should destroy list elements"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"1. Foo",
		"   1. Bar",
		"      - Baz",
		"      - Noice",
		"   2. Sheesh",
	})
	child.api.nvim_win_set_cursor(0, { 4, 0 })
	child.type_keys("V2k10<lt>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, 7, true)
	local expected_buffer = {
		"1. Foo",
		"",
		"Bar",
		"Baz",
		"Noice",
		"",
		"1. Sheesh",
	}

	eq(result_buffer, expected_buffer)
end

T["visual"]["full outdentation inserts empty separator lines wherever necessary"] = function()
	child.api.nvim_buf_set_lines(0, 0, 0, true, {
		"- Foo:",
		"  - Bar",
		"- Foo:",
		"  - Bar",
		"- Baz",
		"",
		"Sheesh",
	})
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.type_keys("Vip<lt>")

	local result_buffer = child.api.nvim_buf_get_lines(0, 0, -2, true)
	local expected_buffer = {
		"Foo:",
		"",
		"- Bar",
		"",
		"Foo:",
		"",
		"- Bar",
		"",
		"Baz",
		"",
		"Sheesh",
	}

	eq(result_buffer, expected_buffer)

	local result_cursor_coords = child.api.nvim_win_get_cursor(0)
	local expected_cursor_coords = { 1, 0 }

	eq(result_cursor_coords, expected_cursor_coords)
end

return T
