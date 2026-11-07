-- Live check: `:Insert mdlink` with the real markdown.nvim (task buffer-ctx.nvim/testblatt-bindings-checkliste; section
-- 3a of ALL/manual-test-checklists/buffer-ctx.md). markdown.nvim has no ci-verified branch: a reported skip on the
-- CI, it runs beside a sibling checkout.
return {
  id = "bctx.mdlink-markdown",
  title = "buffer-ctx.nvim: :Insert mdlink with markdown.nvim gives the text of the fallback",
  task = "buffer-ctx.nvim/testblatt-bindings-checkliste",
  requires = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua").add_deps("markdown.nvim")]],
      reason = "markdown.nvim is not beside this repository",
    },
  },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({})
      _G.sandbox()
      _G.open("docs/a.md", "")]],
    },
    {
      expect = [[type(require("markdown.commands.markdown_links").for_paths) == "function"]],
      note = "the real builder",
    },
    { input = ":Insert mdlink<CR>" },
    { wait = [[vim.fn.mode() == "i"]], note = "insert mode" },
    {
      expect = [[_G.eq(_G.text(), "[a.md](docs/a.md)")]],
      note = "the filename, the relative path",
    },
    {
      expect = [[_G.eq(vim.fn.col("."), #"[a.md](docs/a.md" + 1)]],
      note = "the cursor in the link",
    },
    { input = "<Esc>" },
    { wait = [[vim.fn.mode() == "n"]] },
    { keys = ":checkhealth buffer_ctx<CR>" },
    { wait = [[#_G.report("markdown.nvim detected") == 1]], note = "the report says which case" },
  },
}
