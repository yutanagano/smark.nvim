local format = require("smark.format")

local M = {}

function M.main()
	M.test_fix()
	M.test_fix_numbering()
end

function M.test_fix()
	print("Running test_fix...")

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

	M.assert_tables_eq(li_array, expected_li_array)

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

	M.assert_tables_eq(ispec_array, exptected_ispec_array)
end

function M.test_fix_numbering()
	print("Running test_fix_numbering...")

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

	M.assert_tables_eq(li_array, li_array)
end

function M.assert_tables_eq(left, right, index_array)
	if left == right then
		return
	end

	if index_array == nil then
		index_array = {}
	end

	if type(left) ~= "table" or type(right) ~= "table" then
		if left ~= right then
			M.print_tab_eq_err("inequality", index_array, left, right)
			return
		end
	end

	local left_size = 0
	for _ in pairs(left) do
		left_size = left_size + 1
	end
	local right_size = 0
	for _ in pairs(right) do
		right_size = right_size + 1
	end

	if left_size ~= right_size then
		M.print_tab_eq_err("different size", index_array, left_size, right_size)
		return
	end

	for k, v1 in pairs(left) do
		local v2 = right[k]
		local new_index_array = M.copy_index_array(index_array)
		table.insert(new_index_array, k)
		M.assert_tables_eq(v1, v2, new_index_array)
	end
end

function M.print_tab_eq_err(err_desc, index_array, left_value, right_value)
	local error_string = "  " .. err_desc .. " at:"
	for _, idx in ipairs(index_array) do
		error_string = error_string .. " " .. tostring(idx) .. ","
	end
	error_string = error_string .. "\n  LHS: " .. tostring(left_value) .. "\n  RHS: " .. tostring(right_value)
	print(error_string)
end

function M.copy_index_array(index_array)
	local new = {}
	for i, idx in ipairs(index_array) do
		new[i] = idx
	end
	return new
end

M.main()
