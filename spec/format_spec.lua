package.path = package.path .. ";./lua/?.lua"
local format = require("smark.format")

describe("format submodule", function()
	describe("format.fix", function()
		it("should fix numbering", function()
			local li_array = {
				{ is_ordered = true, index = 1, indent_spaces = 0 },
				{ is_ordered = true, index = 1, indent_spaces = 0 },
				{ is_ordered = true, index = 1, indent_spaces = 3 },
				{ is_ordered = true, index = 1, indent_spaces = 3 },
				{ is_ordered = false, index = 1, indent_spaces = 3 },
				{ is_ordered = true, index = 1, indent_spaces = 3 },
				{ is_ordered = true, index = 1, indent_spaces = 0 },
				{ is_ordered = true, index = 1, indent_spaces = 0 },
			}

			local ispec_array = format.fix(li_array)

			local expected_li_array = {
				{ is_ordered = true, index = 1, indent_spaces = 0 },
				{ is_ordered = true, index = 2, indent_spaces = 0 },
				{ is_ordered = true, index = 1, indent_spaces = 3 },
				{ is_ordered = true, index = 2, indent_spaces = 3 },
				{ is_ordered = false, index = 1, indent_spaces = 3 },
				{ is_ordered = true, index = 1, indent_spaces = 3 },
				{ is_ordered = true, index = 3, indent_spaces = 0 },
				{ is_ordered = true, index = 4, indent_spaces = 0 },
			}

			assert.are.same(li_array, expected_li_array)

			local exptected_ispec_array = {
				{ { is_ordered = true, indent_spaces = 0 } },
				{ { is_ordered = true, indent_spaces = 0 } },
				{ { is_ordered = true, indent_spaces = 0 }, { is_ordered = true, indent_spaces = 3 } },
				{ { is_ordered = true, indent_spaces = 0 }, { is_ordered = true, indent_spaces = 3 } },
				{ { is_ordered = true, indent_spaces = 0 }, { is_ordered = false, indent_spaces = 3 } },
				{ { is_ordered = true, indent_spaces = 0 }, { is_ordered = true, indent_spaces = 3 } },
				{ { is_ordered = true, indent_spaces = 0 } },
				{ { is_ordered = true, indent_spaces = 0 } },
			}

			assert.are.same(ispec_array, exptected_ispec_array)
		end)
	end)

	describe("format.fix_numbering", function()
		it("should fix numbering", function()
			local li_array = {
				{ is_ordered = true, index = 1, indent_spaces = 0 },
				{ is_ordered = true, index = 2, indent_spaces = 0 },
				{ is_ordered = true, index = 1, indent_spaces = 3 },
				{ is_ordered = true, index = 2, indent_spaces = 3 },
				{ is_ordered = false, index = 1, indent_spaces = 3 },
				{ is_ordered = true, index = 1, indent_spaces = 3 },
				{ is_ordered = true, index = 3, indent_spaces = 0 },
				{ is_ordered = true, index = 4, indent_spaces = 0 },
			}

			local ispec_array = {
				{ { is_ordered = true, indent_spaces = 0 } },
				{ { is_ordered = true, indent_spaces = 0 } },
				{ { is_ordered = true, indent_spaces = 0 }, { is_ordered = true, indent_spaces = 3 } },
				{ { is_ordered = true, indent_spaces = 0 }, { is_ordered = true, indent_spaces = 3 } },
				{ { is_ordered = true, indent_spaces = 0 }, { is_ordered = false, indent_spaces = 3 } },
				{ { is_ordered = true, indent_spaces = 0 }, { is_ordered = true, indent_spaces = 3 } },
				{ { is_ordered = true, indent_spaces = 0 } },
				{ { is_ordered = true, indent_spaces = 0 } },
			}

			format.fix_numbering(li_array, ispec_array)

			assert.are.same(li_array, li_array)
		end)
	end)
end)
