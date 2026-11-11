-- Live check: `reveal = false` (task buffer-ctx.nvim/testblatt-bindings-checkliste; section 7 of
-- ALL/manual-test-checklists/buffer-ctx.md).
return {
  id = "bctx.off-reveal",
  feature = "bctx.switches",
  title = "buffer-ctx.nvim: reveal = false removes both commands and keys, the report says disabled",
  task = "buffer-ctx.nvim/manual-checklist-run",
  sizes = { { rows = 40, cols = 120 } },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({ reveal = false })]],
    },
    { expect = [[_G.eq(vim.fn.exists(":RevealInFm"), 0)]], note = ":RevealInFm is not there" },
    { expect = [[_G.eq(vim.fn.exists(":OpenInBrowser"), 0)]], note = ":OpenInBrowser neither" },
    { expect = [[not _G.bound(" of")]], note = "<leader>of is not bound" },
    { expect = [[not _G.bound(" ob")]], note = "<leader>ob is not bound" },
    { keys = ":checkhealth buffer_ctx<CR>" },
    { wait = [[#_G.report("reveal subsystem disabled") == 1]], note = "disabled" },
    {
      expect = [[#_G.report("format subsystem enabled") == 1]],
      note = "format is not misreported",
    },
    { expect = [[#_G.report("mark subsystem enabled") == 1]], note = "mark neither" },
    { expect = [[_G.eq(#_G.report("ERROR"), 0)]], note = "no error line" },
  },
}
