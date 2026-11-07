-- Live check: `keymaps = false`, the one switch for every key (task buffer-ctx.nvim/testblatt-bindings-checkliste;
-- section 7 of ALL/manual-test-checklists/buffer-ctx.md).
return {
  id = "bctx.off-keymaps",
  title = "buffer-ctx.nvim: keymaps = false unbinds every key, commands stay, an explicit mark.keymaps wins",
  task = "buffer-ctx.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({ keymaps = false, reveal = { keymaps = { fm = "<leader>xf" } } })]],
    },
    { expect = [[not _G.bound(" cnf")]], note = "<leader>cnf is not bound" },
    { expect = [[not _G.bound(" cnl")]], note = "<leader>cnl is not bound" },
    { expect = [[not _G.bound(" cnm")]], note = "<leader>cnm is not bound" },
    { expect = [[not _G.bound("M")]], note = "<S-m> is not bound" },
    { expect = [[not _G.bound("<C-p>")]], note = "<C-p> is not bound" },
    { expect = [[_G.bound(" xf")]], note = "an explicit reveal.keymaps table wins" },
    { expect = [[_G.eq(vim.fn.exists(":Copy"), 2)]], note = "commands are unaffected" },
    { expect = [[_G.eq(vim.fn.exists(":Mark"), 2)]], note = ":Mark too" },
    { expect = [[_G.eq(vim.fn.exists(":RevealInFm"), 2)]], note = ":RevealInFm too" },
  },
}
