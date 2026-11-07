-- Live check: `:checkhealth buffer_ctx` with the defaults (task buffer-ctx.nvim/testblatt-bindings-checkliste; the setup
-- section of ALL/manual-test-checklists/buffer-ctx.md).
return {
  id = "bctx.health",
  title = "buffer-ctx.nvim: :checkhealth names lib.nvim, the compat commands, the soft deps, each subsystem",
  task = "buffer-ctx.nvim/testblatt-bindings-checkliste",
  sizes = { { rows = 40, cols = 120 } },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({})]],
    },
    { keys = ":checkhealth buffer_ctx<CR>" },
    { wait = [[#_G.report("command layer available") == 1]], note = "lib.nvim, a hard dependency" },
    { expect = [[#_G.report(":CopyFilepathAbsolute compat command registered") == 1]] },
    { expect = [[#_G.report(":CopyFilepathRelative compat command registered") == 1]] },
    { expect = [[#_G.report(":CopyFilepathRepos compat command registered") == 1]] },
    { expect = [[#_G.report(":CopyFilepathEnv compat command registered") == 1]] },
    { expect = [[#_G.report("markdown.nvim not found") == 1]], note = "a soft dep: info" },
    { expect = [[#_G.report("images.nvim not found") == 1]], note = "a soft dep: info" },
    { expect = [[#_G.report("format subsystem enabled") == 1]] },
    { expect = [[#_G.report("mark subsystem enabled") == 1]] },
    { expect = [[#_G.report("reveal subsystem enabled") == 1]] },
    { expect = [[#_G.report("reveal_in_fm detected") == 1]], note = "the dispatcher" },
    { expect = [[#_G.report("falls back to vim.ui.open") == 1]], note = "no open.nvim here" },
    { expect = [[_G.eq(#_G.report("ERROR"), 0)]], note = "no error line" },
    { expect = [[#_G.report("no unknown or invalid options") == 1]], note = "the config is clean" },
  },
}
