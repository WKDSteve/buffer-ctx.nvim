-- Live check: `format = false` (task buffer-ctx.nvim/testblatt-bindings-checkliste; section 7 of
-- ALL/manual-test-checklists/buffer-ctx.md).
return {
  id = "bctx.off-format",
  feature = "bctx.switches",
  title = "buffer-ctx.nvim: format = false removes :Format, the report says disabled, the others stay enabled",
  task = "buffer-ctx.nvim/manual-checklist-run",
  sizes = { { rows = 40, cols = 120 } },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({ format = false })]],
    },
    { expect = [[_G.eq(vim.fn.exists(":Format"), 0)]], note = ":Format is not there" },
    { expect = [[_G.eq(vim.fn.exists(":Mark"), 2)]], note = ":Mark is" },
    { keys = ":checkhealth buffer_ctx<CR>" },
    { wait = [[#_G.report("format subsystem disabled") == 1]], note = "disabled" },
    { expect = [[_G.eq(#_G.report(":Format command not found"), 0)]], note = "no missing-command" },
    { expect = [[#_G.report("mark subsystem enabled") == 1]], note = "mark is not misreported" },
    { expect = [[#_G.report("reveal subsystem enabled") == 1]], note = "reveal neither" },
    { expect = [[#_G.report("command layer available") == 1]], note = "the core neither" },
    { expect = [[_G.eq(#_G.report("ERROR"), 0)]], note = "no error line" },
  },
}
