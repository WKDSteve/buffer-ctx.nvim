-- Live check: `keymaps = false` alone also takes the reveal keys (task buffer-ctx.nvim/testblatt-bindings-checkliste;
-- section 7 of ALL/manual-test-checklists/buffer-ctx.md).
return {
  id = "bctx.off-keymaps-all",
  title = "buffer-ctx.nvim: keymaps = false alone leaves <leader>of and <leader>ob unbound too",
  task = "buffer-ctx.nvim/manual-checklist-run",
  sizes = { { rows = 40, cols = 120 } },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({ keymaps = false })]],
    },
    { expect = [[not _G.bound(" of")]], note = "<leader>of is not bound" },
    { expect = [[not _G.bound(" ob")]], note = "<leader>ob is not bound" },
    { expect = [[not _G.bound("M")]], note = "<S-m> is not bound" },
    { expect = [[_G.eq(vim.fn.exists(":OpenInBrowser"), 2)]], note = "the command stays" },
    { keys = ":checkhealth buffer_ctx<CR>" },
    { wait = [[#_G.report("format subsystem enabled") == 1]], note = "format is not misreported" },
    { expect = [[#_G.report("mark subsystem enabled") == 1]], note = "mark neither" },
    { expect = [[#_G.report("reveal subsystem enabled") == 1]], note = "reveal neither" },
    { expect = [[_G.eq(#_G.report("ERROR"), 0)]], note = "no error line" },
  },
}
