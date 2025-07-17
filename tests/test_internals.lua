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
		"- Key claims:",
		"  - ICKG shows more interpretable and context-aware interaction pathways",
		"    between immune genes",
		"  - ICKG utility has been demonstrated using perturbation datasets",
		"  - ICKG is a scalable framework for mechanistic and functional hypothesis",
		"    generation",
		"- Introduction:",
		"  - Immune cell ecosystems are highly complex and heterogeneous",
		"  - Understanding their complexity is key for engineering therapeutics against",
		"    diseases like cancer",
		"  - Recently, single-cell and -omics studies have provided a lot of data on",
		"    said complexity which may help us untangle the complexity",
		"  - (64) However any insight gained remain scattered across numerous",
		"    publications and is hard to parse through to get a global understanding",
		"  - (72) Existing gene annotation databases lack the granularity and",
		"    context-specificity (see comments in [[#Thoughts]]) to fully explain",
		"    complex immune signatures",
		"  - (88) In contrast, biomedical literature contains studies that report",
		"    context-specific hypothesis-driven understanding of immune gene pathways:",
		"    - But mining global insight from these studies is labour intensive",
		"  - (105) To solve this issue the authors created ICKG:",
		"    - ICKG is produced in automated pipeline involving LLMs:",
		"      - However unlike previous attempts at using LLMs for literature",
		"        assimilation, ICKG is built to be transparent and scientifically",
		"        accountable",
		"    - There are multiple knowledge graphs, one for each major immune cell type",
		"    - Knowledge graphs have nodes representing entities like genes, and",
		"      directed relationships representing activation / inhibition:",
		"      - Each one of these relationships have reference studies from which the",
		"        knowledge was pulled",
		"    - ICKG provides richer and more granular understanding of immune gene",
		"      relationships compared to existing gene annotation databases",
		"    - KGR using perturbation studies validate the knowledge captured by the KG",
		"- Results:",
		"  - Construction of ICKG:",
		"    - KG for:",
		"      - [[T_cell]]",
		"      - [[B_cell]]",
		"      - NK cells",
		"      - [[macrophage]]",
		"    - Used LLMs to perform named entity recognition using paper abstracts",
		"    - The named entity extraction techniques the authors employed was validated",
		"      by comparing to existing resources like the immune cell atlas and KEGG",
		"      (see [[#Thoughts]] about this below)",
		"  - ICKGs enable biological reasoning about gene networks, immune cell types",
		"    and diseases:",
		"    - Took perturbation studies and compared the empirical results with",
		"      knowledge inferred from the ICKG graph:",
		"      - Studies:",
		"        - One scCRISPR study knocking out transcription factors",
		"        - One cytokine perturbation atlas",
		"      - Knowledge graph reasoning was performed using three methods:",
		"        - PageRank using ICKG",
		"        - Adjusted random walk using ICKG",
		"        - PageRank on randomised knowledge graph",
		"      - Comparison made between ground truth (from studies), knowledge from",
		"        ICKG, and knowledge from existing databases",
		"    - Analysis shows that:",
		"      - PageRank on ICKG shows significantly more concordant predictions to",
		"        ground truth compared to all other scenarios (including existing",
		"        Hallmark gene sets)",
		"      - Using the immune cell type-specific ICKG matters -- inferring on",
		"        mismatched graph yields significantly less concordant predictions of",
		"        differentially expressed genes",
		"      - Comparing inferences that are high- and low-performance reveal that",
		"        petubations that are harder to predict are usually for genes that are",
		"        not well studied, which means that there is a clear pathway to further",
		"        improvement of this resource -- further studying the under-studied",
		"        genes.",
	}
	child.api.nvim_buf_set_lines(0, 0, 0, true, original_lines)
	child.api.nvim_win_set_cursor(0, { 40, 0 })
	child.type_keys("A<CR>")

	local calls = child.lua_get("_G._set_lines_calls")

	eq(#calls, 1)
	eq(calls[1], {
		buf = 0,
		start = 40,
		end_ = 40,
		strict = true,
		lines = { "      - " },
	})
end

return T
