-- Live check: `:Insert mdlink` and `:Copy mdlink` without markdown.nvim (task
-- buffer-ctx.nvim/testblatt-bindings-checkliste; section 3a of ALL/manual-test-checklists/buffer-ctx.md).
return {
  id = "bctx.mdlink",
  feature = "bctx.mdlink",
  title = "buffer-ctx.nvim: :Insert mdlink, the literal fallback, the cursor in the link, the path modes",
  task = "buffer-ctx.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({})
      _G.sandbox()
      vim.env.REPOS_DIR = _G.root
      _G.open("docs/a.md", "before after")
      _G.cur = function()
        return vim.api.nvim_win_get_cursor(0)[2]
      end]],
    },
    {
      expect = [[not pcall(require, "markdown.commands.markdown_links")]],
      note = "no markdown.nvim",
    },

    { lua = [[vim.api.nvim_set_current_line("")]] },
    { input = ":Insert mdlink<CR>" },
    { wait = [[vim.fn.mode() == "i"]], note = "insert mode" },
    { expect = [[_G.eq(_G.text(), "[a.md](docs/a.md)")]], note = "the same text, no error" },
    { expect = [[_G.eq(#_G.notes, 0)]], note = "no warning" },
    {
      expect = [[_G.eq(_G.cur(), #"[a.md](docs/a.md")]],
      note = "the cursor at the end of the path",
    },
    { input = "x<Esc>", note = "typing continues the path" },
    { wait = [[vim.fn.mode() == "n"]] },
    { expect = [[_G.eq(_G.text(), "[a.md](docs/a.mdx)")]], note = "inside the parentheses" },

    { lua = [[vim.api.nvim_set_current_line("before after"); vim.fn.cursor(1, 8)]] },
    { input = ":Insert mdlink<CR>" },
    { wait = [[vim.fn.mode() == "i"]] },
    {
      expect = [[_G.eq(_G.text(), "before [a.md](docs/a.md)after")]],
      note = "the rest of the line stays",
    },
    {
      expect = [[_G.eq(_G.cur(), #"before [a.md](docs/a.md")]],
      note = "the cursor inside the link",
    },
    { input = "<Esc>" },
    { wait = [[vim.fn.mode() == "n"]] },

    { lua = [[vim.api.nvim_set_current_line("")]] },
    { input = ":Insert mdlink abs<CR>" },
    { wait = [[vim.fn.mode() == "i"]] },
    { expect = [[_G.eq(_G.text(), "[a.md](" .. _G.root .. "/docs/a.md)")]], note = "abs" },
    { input = "<Esc>" },
    { wait = [[vim.fn.mode() == "n"]] },
    { lua = [[vim.api.nvim_set_current_line("")]] },
    { input = ":Insert mdlink repos<CR>" },
    { wait = [[vim.fn.mode() == "i"]] },
    { expect = [[_G.eq(_G.text(), "[a.md](docs/a.md)")]], note = "repos" },
    { input = "<Esc>" },
    { wait = [[vim.fn.mode() == "n"]] },
    { lua = [[vim.api.nvim_set_current_line("")]] },
    { input = ":Insert mdlink env<CR>" },
    { wait = [[vim.fn.mode() == "i"]] },
    { expect = [[_G.eq(_G.text(), "[a.md]($REPOS_DIR/docs/a.md)")]], note = "env" },
    { input = "<Esc>" },
    { wait = [[vim.fn.mode() == "n"]] },
    { lua = [[vim.api.nvim_set_current_line("")]] },
    { input = ":Insert mdlink 0<CR>" },
    { wait = [[vim.fn.mode() == "i"]] },
    { expect = [[_G.eq(_G.text(), "[a.md](a.md)")]], note = "a depth" },
    { input = "<Esc>" },
    { wait = [[vim.fn.mode() == "n"]] },

    { lua = [[vim.api.nvim_set_current_line("kept"); vim.env.REPOS_DIR = ""]] },
    { keys = ":Insert mdlink repos<CR>" },
    { expect = [[_G.noted("$REPOS_DIR is not set")]], note = "repos unset: the error" },
    { expect = [[_G.eq(_G.text(), "kept")]], note = "inserts nothing" },
    { keys = ":Insert mdlink bogus<CR>" },
    { expect = [[_G.noted("[mdlink] unknown argument(s): bogus")]], note = "an unknown token" },
    { expect = [[_G.eq(_G.text(), "kept")]], note = "inserts nothing" },

    { lua = [[vim.fn.cursor(1, 2)]] },
    { keys = ":Copy mdlink<CR>" },
    { expect = [[_G.eq(_G.clip(), "[a.md](docs/a.md)")]], note = "the same link on the clipboard" },
    { expect = [[_G.noted("copied: [a.md](docs/a.md)")]], note = "it says so" },
    {
      expect = [[_G.eq(_G.text(), "kept") and _G.eq(_G.cur(), 1)]],
      note = "buffer, cursor untouched",
    },
    { expect = [[_G.eq(vim.fn.mode(), "n")]], note = "no insert mode" },
  },
}
