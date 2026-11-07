-- Live check: `opts.mark.categories` (task buffer-ctx.nvim/testblatt-bindings-checkliste; section 4 of
-- ALL/manual-test-checklists/buffer-ctx.md).
return {
  id = "bctx.mark-categories",
  title = "buffer-ctx.nvim: named mark categories: yank and clear filter, a toggle replaces another category",
  task = "buffer-ctx.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({ mark = { categories = {
        { name = "todo", text = "T", hl = "WarningMsg" },
        { name = "done", text = "D", hl = "DiagnosticOk" },
      } } })
      _G.sandbox()
      _G.open("marked.txt", "l1", "l2", "l3", "l4")]],
    },
    { keys = ":Mark toggle todo<CR>j:Mark toggle done<CR>j:Mark toggle todo<CR>" },
    { expect = [[_G.eq(_G.marks(), "1:T 2:D 3:T")]], note = "each with its own sign" },
    { keys = ":Mark yank todo<CR>" },
    { expect = [[_G.eq(_G.clip(), "l1\nl3")]], note = "only the todo lines" },
    { keys = ":Mark yank done<CR>" },
    { expect = [[_G.eq(_G.clip(), "l2")]], note = "only the done line" },
    { keys = "k:Mark toggle todo<CR>", note = "a todo toggle on a done line" },
    { expect = [[_G.eq(_G.marks(), "1:T 2:T 3:T")]], note = "replaces the category, not unmarks" },
    { keys = ":Mark toggle done<CR>", note = "back to done" },
    { keys = ":Mark clear todo<CR>" },
    { expect = [[_G.eq(_G.marks(), "2:D")]], note = "only that category" },
    { keys = ":Mark clear<CR>" },
    { expect = [[_G.eq(_G.marks(), "")]], note = "all of them" },
    { lua = [[_G.forget()]] },
    { keys = ":Mark toggle nope<CR>", ignore_errmsg = true },
    { expect = [[_G.noted("nope")]], note = "an unknown category is refused" },
    { expect = [[_G.eq(_G.marks(), "")]], note = "and marks nothing" },
  },
}
