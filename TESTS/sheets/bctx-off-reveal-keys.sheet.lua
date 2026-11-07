-- Live check: `reveal = { keymaps = false }` (task buffer-ctx.nvim/testblatt-bindings-checkliste; section 7 of
-- ALL/manual-test-checklists/buffer-ctx.md).
return {
  id = "bctx.off-reveal-keys",
  title = "buffer-ctx.nvim: reveal = { keymaps = false } unbinds only the two keys, both commands stay",
  task = "buffer-ctx.nvim/testblatt-bindings-checkliste",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({ reveal = { keymaps = false } })]],
    },
    { expect = [[not _G.bound(" of")]], note = "<leader>of is not bound" },
    { expect = [[not _G.bound(" ob")]], note = "<leader>ob is not bound" },
    { expect = [[_G.eq(vim.fn.exists(":RevealInFm"), 2)]], note = ":RevealInFm stays" },
    { expect = [[_G.eq(vim.fn.exists(":OpenInBrowser"), 2)]], note = ":OpenInBrowser stays" },
    { expect = [[_G.bound(" cnf")]], note = "the core keys stay" },
    { expect = [[_G.bound("M")]], note = "the mark keys stay" },
  },
}
