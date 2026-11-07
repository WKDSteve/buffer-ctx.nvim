-- Live check: the line operations of `:Format` (task buffer-ctx.nvim/testblatt-bindings-checkliste; section 5 of
-- ALL/manual-test-checklists/buffer-ctx.md and the :Format lines of the bindings checklist).
return {
  id = "bctx.format-lines",
  title = "buffer-ctx.nvim: :Format trim, filter, squeeze, sort, unique, case, indent, cite, clear",
  task = "buffer-ctx.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({})
      _G.fresh("a  ", "b\t", "c")]],
    },
    { keys = ":Format trim<CR>" },
    { expect = [[_G.eq(_G.text(), "a\nb\nc")]], note = "trailing whitespace on every line" },

    { lua = [[_G.fresh("TODO a", "b", "TODO c"); _G.forget()]] },
    { keys = ":Format filter TODO<CR>" },
    { expect = [[_G.eq(_G.text(), "TODO a\nTODO c")]], note = "keeps the matching lines" },
    { expect = [[_G.noted("3 → 2 lines")]], note = "before and after reported" },
    { lua = [[_G.fresh("TODO a", "b", "TODO c"); _G.forget()]] },
    { keys = ":Format filter --remove TODO<CR>" },
    { expect = [[_G.eq(_G.text(), "b")]], note = "drops them" },
    { expect = [[_G.noted("3 → 1 lines")]], note = "reported too" },

    { lua = [[_G.fresh("a", "", "", "", "b", "", "", "c", "", "", "d")]] },
    { keys = ":Format squeeze<CR>" },
    { expect = [[_G.eq(_G.text(), "a\n\nb\n\nc\n\nd")]], note = "each run to one blank line" },
    { lua = [[_G.fresh("a", "", "", "b", "", "", "c")]] },
    { keys = ":1,4Format squeeze<CR>" },
    { expect = [[_G.eq(_G.text(), "a\n\nb\n\n\nc")]], note = "with a range: only there" },

    { lua = [[_G.fresh("b", "A", "c")]] },
    { keys = ":Format sort -r -i<CR>" },
    { expect = [[_G.eq(_G.text(), "c\nb\nA")]], note = "sort, reverse, ignoring case" },
    { lua = [[_G.fresh("a", "A", "b", "a")]] },
    { keys = ":Format unique -i<CR>" },
    { expect = [[_G.eq(_G.text(), "a\nb")]], note = "unique, ignoring case" },
    { lua = [[_G.fresh("hello big world")]] },
    { keys = ":Format case title<CR>" },
    { expect = [[_G.eq(_G.text(), "Hello Big World")]], note = "case title" },
    { lua = [[_G.fresh("one two. three! four? five", "six")]] },
    { keys = ":Format case sentence<CR>" },
    { expect = [[_G.has(_G.text(), "One two. Three! Four? Five")]], note = "every sentence" },

    {
      lua = [[_G.fresh("if x then", "\ty", "end"); vim.bo.expandtab = true; vim.bo.shiftwidth = 2
      vim.bo.tabstop = 2]],
    },
    { keys = ":Format indent --spaces 2<CR>" },
    { expect = [[_G.eq(_G.text(), "if x then\n  y\nend")]], note = "indent to spaces" },

    { lua = [[_G.fresh("a [cite: 1] b")]] },
    { keys = ":Format cite<CR>" },
    { expect = [[not _G.text():find("cite", 1, true)]], note = "the [cite: N] markers go" },
    { lua = [[_G.fresh("a", "b")]] },
    { keys = ":Format clear<CR>" },
    { expect = [[_G.eq(_G.text(), "")]], note = "clear" },
  },
}
