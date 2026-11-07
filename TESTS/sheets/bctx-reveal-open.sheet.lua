-- Live check: `:OpenInBrowser` on an unnamed buffer with the real open.nvim (task
-- buffer-ctx.nvim/testblatt-bindings-checkliste; section 8 of ALL/manual-test-checklists/buffer-ctx.md). open.nvim has no
-- ci-verified branch: a reported skip on the CI, it runs beside a sibling checkout. What could start a program records.
return {
  id = "bctx.reveal-open",
  title = "buffer-ctx.nvim: :OpenInBrowser on an unnamed buffer with open.nvim: a warning, no program, no traceback",
  task = "buffer-ctx.nvim/testblatt-bindings-checkliste",
  requires = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua").add_deps("open.nvim")]],
      reason = "open.nvim is not beside this repository",
    },
  },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.started = 0
      local function count()
        _G.started = _G.started + 1
      end
      vim.ui.open, vim.system, vim.fn.jobstart = count, count, count
      require("buffer_ctx").setup({})
      vim.cmd("enew!")]],
    },
    { expect = [[type(require("open").open) == "function"]], note = "the real open.nvim" },
    { keys = ":OpenInBrowser<CR>" },
    { expect = [[#_G.notes > 0]], note = "a warning" },
    { expect = [[not table.concat(_G.notes, "\n"):find("stack traceback", 1, true)]] },
    { expect = [[_G.eq(_G.started, 0)]], note = "no program" },
  },
}
