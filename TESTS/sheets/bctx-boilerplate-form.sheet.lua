-- Live check: `:Insert boilerplate guard-clause` through the real form of lib.nvim's kit, typed field by field (task
-- buffer-ctx.nvim/testblatt-bindings-checkliste; section 2 of ALL/manual-test-checklists/buffer-ctx.md).
return {
  id = "bctx.boilerplate-form",
  title = "buffer-ctx.nvim: guard-clause asks in a form, the answers are in the clause, a dismissed form inserts nothing",
  task = "buffer-ctx.nvim/testblatt-bindings-checkliste",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({})
      _G.field = function(default)
        return _G.in_float()
          and vim.fn.mode() == "i"
          and vim.trim(vim.api.nvim_get_current_line()) == default
      end
      _G.fresh("")]],
    },
    { input = ":Insert boilerplate guard-clause<CR>" },
    { wait = [[_G.field("condition")]], note = "the first field, no error on a missing argument" },
    { input = "<C-u>ready<CR>" },
    { wait = [[_G.field("n")]], note = "the second field" },
    { input = "<C-u>y<CR>" },
    { wait = [[not _G.in_float()]], note = "the form is answered" },
    { expect = [[_G.has(_G.text(), "if not ready then")]], note = "the answers are in the clause" },

    { lua = [[_G.fresh("")]] },
    { input = ":Insert boilerplate guard-clause<CR>" },
    { wait = [[_G.field("condition")]] },
    { input = "<Esc>" },
    { wait = [[not _G.in_float()]], note = "dismissed" },
    { expect = [[_G.eq(_G.text(), "")]], note = "a dismissed form inserts nothing" },
  },
}
