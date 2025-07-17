local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality
local child = MiniTest.new_child_neovim()

local T = new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "scripts/minimal_init.lua" })
			child.lua("require('smark').setup()")
			child.lua([[
				_G._set_lines_calls = {}
				local orig = vim.api.nvim_buf_set_lines
				vim.api.nvim_buf_set_lines = function(buf, start, end_, strict, lines)
					table.insert(_G._set_lines_calls, {buf=buf, start=start, end_=end_, strict=strict, lines=vim.deepcopy(lines)})
					return orig(buf, start, end_, strict, lines)
				end
			]])
			child.bo.filetype = "markdown"
		end,
		post_once = child.stop,
	},
})

T["insert_CR"] = new_set()

T["insert_CR"]["rewrite_lines"] = function()
	local original_lines = {
		"- This piece of legislation:",
		"  - Provides single clear test for assessing capacity",
		"    ([[2-stage_test_for_capacity]])",
		"  - Checklist for making best interest decisions",
		"  - Allows decision-maker to be assigned to person if they cannot make their",
		"    own decisions",
		"  - Defines deprivation of liberty",
		"  - Provides safeguards ([[Deprivation_of_Liberty_Safeguards]])",
		"- Types of decisions covered:",
		"  - Healthcare",
		"  - Place of residence",
		"  - Financial",
		"- Statutory framework to protect vulnerable people who may not be able to make",
		"  decisions for themselves",
		"- Historical context:",
		"  - The [[MHA]] was created to put safeguards into place for vulnerable people",
		"    with mental health disorders",
		"  - However [[MHA]] does not apply when patients do not have a mental health",
		"    disorder",
		"  - The MCA was created to cover this hole, and comes with legal framework to",
		"    safeguard people in general",
		"  - However as the [[MHA]] is a more powerful legal framework, it should be",
		"    used in preference",
		"- When determination of best interests relates to life-sustaining treatment,",
		"  decision maker must not be motivated by a desire to bring about the patient's",
		"  death",
	}
	child.api.nvim_buf_set_lines(0, 0, 0, true, original_lines)
	child.api.nvim_win_set_cursor(0, { 15, 0 })
	child.type_keys("A<CR>")

	local calls = child.lua_get("_G._set_lines_calls")

	eq(#calls, 1)
	eq(calls[1], {
		buf = 0,
		start = 15,
		end_ = 15,
		strict = true,
		lines = { "  - " },
	})
end

return T
