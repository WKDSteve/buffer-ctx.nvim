-- Live check: `mark = false` (task buffer-ctx.nvim/testblatt-bindings-checkliste; section 7 of
-- ALL/manual-test-checklists/buffer-ctx.md).
return {
  id = "bctx.off-mark",
  title = "buffer-ctx.nvim: mark = false removes :Mark, its keys and its autocmd group, the report says disabled",
  task = "buffer-ctx.nvim/testblatt-bindings-checkliste",
  sizes = { { rows = 40, cols = 120 } },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({ mark = false })]],
    },
    { expect = [[_G.eq(vim.fn.exists(":Mark"), 0)]], note = ":Mark is not there" },
    {
      expect = [[_G.eq(vim.fn.exists(":MarkLineToggle"), 0)]],
      note = "its compat command neither",
    },
    { expect = [[not _G.bound("M")]], note = "<S-m> is not bound" },
    { expect = [[not _G.bound("<C-p>")]], note = "<C-p> is not bound" },
    { expect = [[_G.eq(vim.fn.exists("#BufferCtxMarkCleanup"), 0)]], note = "no autocmd group" },
    { keys = ":checkhealth buffer_ctx<CR>" },
    { wait = [[#_G.report("mark subsystem disabled") == 1]], note = "disabled" },
    {
      expect = [[#_G.report("format subsystem enabled") == 1]],
      note = "format is not misreported",
    },
    { expect = [[#_G.report("reveal subsystem enabled") == 1]], note = "reveal neither" },
    { expect = [[_G.eq(#_G.report("ERROR"), 0)]], note = "no error line" },
  },
}
