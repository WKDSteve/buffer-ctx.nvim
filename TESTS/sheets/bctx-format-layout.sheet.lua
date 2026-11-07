-- Live check: the layout operations of `:Format` (task buffer-ctx.nvim/testblatt-bindings-checkliste; section 5 of
-- ALL/manual-test-checklists/buffer-ctx.md and the :Format lines of the bindings checklist).
return {
  id = "bctx.format-layout",
  title = "buffer-ctx.nvim: :Format table, column (and its refusal), textwidth, enum on real selections",
  task = "buffer-ctx.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({})
      _G.table_lines = { "| a | bbb |", "|-|-|", "| cccc | d |" }
      _G.fresh(unpack(_G.table_lines))
      _G.pipes = function(l)
        local out = {}
        for pos in vim.api.nvim_buf_get_lines(0, l - 1, l, false)[1]:gmatch("()|") do
          out[#out + 1] = pos
        end
        return table.concat(out, ",")
      end]],
    },
    { keys = "Vjj:Format table<CR>", note = "a hand-misaligned table" },
    {
      expect = [[_G.eq(_G.pipes(1), _G.pipes(3)) and _G.eq(_G.pipes(1), _G.pipes(2))]],
      note = "aligned",
    },
    { expect = [[_G.has(_G.text(), "| cccc |")]], note = "the widest cell sets the column" },
    { lua = [[_G.fresh(unpack(_G.table_lines))]] },
    { keys = "<Esc>Vjj:Format table header=center cell=left<CR>" },
    { expect = [[_G.eq(_G.pipes(1), _G.pipes(3))]], note = "aligned with the options" },
    { expect = [[_G.has(vim.fn.getline(3), "| d   |")]], note = "cell=left: the option took" },
    { expect = [[_G.has(vim.fn.getline(1), "|  a   |")]], note = "header=center too" },

    { lua = [[_G.fresh("a = 1", "bb = 2", "ccc = 3"); vim.fn.cursor(1, 3)]] },
    { keys = "<Esc>v<Esc>:'<,'>Format column 10<CR>", note = "a charwise selection on the =" },
    {
      expect = [[_G.eq(vim.fn.getline(1):find("=", 1, true), 10)]],
      note = "the character at column 10",
    },
    { lua = [[_G.fresh("a = 1", "bb = 2"); vim.fn.cursor(1, 3)]] },
    { keys = "<C-v>j<Esc>:'<,'>Format column 10<CR>", note = "a blockwise selection" },
    { expect = [[_G.eq(vim.fn.getline(1):find("=", 1, true), 10)]], note = "blockwise too" },
    { lua = [[_G.fresh("a = 1", "bb = 2", "ccc = 3"); _G.forget()]] },
    { keys = "Vjj:Format column 40<CR>", note = "a linewise selection" },
    { expect = [[_G.has(table.concat(_G.notes, "\n"), "linewise")]], note = "a real error" },
    { expect = [[_G.eq(_G.text(), "a = 1\nbb = 2\nccc = 3")]], note = "no silent misalignment" },

    { lua = [[_G.fresh(("word "):rep(40)); vim.wo.wrap = false]] },
    { keys = "<Esc>:Format textwidth 80<CR>" },
    { expect = [[_G.eq(vim.bo.textwidth, 80)]], note = "sets textwidth" },
    {
      expect = [[vim.api.nvim_buf_line_count(0) > 1 and #vim.fn.getline(1) <= 80]],
      note = "and reflows",
    },
    { lua = [[_G.fresh(("word "):rep(40))]] },
    { keys = ":Format textwidth max<CR>" },
    {
      expect = [[_G.eq(vim.bo.textwidth, vim.api.nvim_win_get_width(0))]],
      note = "max: the window",
    },
    { expect = [[vim.api.nvim_buf_line_count(0) > 1]], note = "reflowed in the same step" },

    { lua = [[_G.fresh("foo", "bar", "baz")]] },
    { keys = [[Vjj:Format enum roman sep=") "<CR>]], note = "a visual selection of tokens" },
    { expect = [[_G.has(_G.text(), "i) foo")]], note = "roman, with the separator" },
    { expect = [[_G.has(_G.text(), "iii) baz")]], note = "the third one" },
  },
}
