-- Live check: `keymaps = false` alone also takes the reveal keys (task buffer-ctx.nvim/testblatt-bindings-checkliste;
-- section 7 of ALL/manual-test-checklists/buffer-ctx.md).
return {
  id = "bctx.off-keymaps-all",
  title = "buffer-ctx.nvim: keymaps = false alone leaves <leader>of and <leader>ob unbound too",
  task = "buffer-ctx.nvim/testblatt-bindings-checkliste",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({ keymaps = false })]],
    },
    { expect = [[not _G.bound(" of")]], note = "<leader>of is not bound" },
    { expect = [[not _G.bound(" ob")]], note = "<leader>ob is not bound" },
    { expect = [[not _G.bound("M")]], note = "<S-m> is not bound" },
    { expect = [[_G.eq(vim.fn.exists(":OpenInBrowser"), 2)]], note = "the command stays" },
  },
}
