-- Live check: `:Copy filepath repos|env` with $REPOS_DIR set and unset (task
-- buffer-ctx.nvim/testblatt-bindings-checkliste; section 1a of ALL/manual-test-checklists/buffer-ctx.md).
return {
  id = "bctx.filepath-roots",
  title = "buffer-ctx.nvim: :Copy filepath repos and env, inside and outside the roots, with $REPOS_DIR unset",
  task = "buffer-ctx.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({})
      _G.sandbox()
      vim.env.REPOS_DIR = _G.root .. "/repos"
      _G.open("outside.txt", "x")
      _G.outside = vim.api.nvim_get_current_buf()
      _G.open("repos/buffer-ctx.nvim/lua/a.lua", "x")
      _G.repo = vim.api.nvim_get_current_buf()
      vim.cmd("edit! " .. vim.fn.fnameescape(_G.config_dir() .. "/lua/b.lua"))
      _G.config = vim.api.nvim_get_current_buf()
      vim.api.nvim_set_current_buf(_G.repo)
      _G.rel = "repos/buffer-ctx.nvim/lua/a.lua"]],
    },

    { keys = ":Copy filepath repos<CR>" },
    {
      expect = [[_G.eq(_G.clip(), "buffer-ctx.nvim/lua/a.lua")]],
      note = "relative to $REPOS_DIR, forward slashes",
    },
    { lua = [[vim.fn.setreg("+", "stale")]] },
    { keys = ":CopyFilepathRepos<CR>" },
    {
      expect = [[_G.eq(_G.clip(), "buffer-ctx.nvim/lua/a.lua")]],
      note = "the compat command agrees",
    },
    { keys = ":Copy filepath env<CR>" },
    {
      expect = [[_G.eq(_G.clip(), "$REPOS_DIR/buffer-ctx.nvim/lua/a.lua")]],
      note = "the literal prefix",
    },
    { lua = [[vim.fn.setreg("+", "stale")]] },
    { keys = ":CopyFilepathEnv<CR>" },
    {
      expect = [[_G.eq(_G.clip(), "$REPOS_DIR/buffer-ctx.nvim/lua/a.lua")]],
      note = "the compat command agrees",
    },
    { keys = ":Copy filepath env lua<CR>" },
    {
      expect = [[_G.eq(_G.clip(), "$REPOS_DIR/buffer-ctx.nvim/lua/a.lua")]],
      note = "env turns lua back into a slash path",
    },

    { lua = [[vim.api.nvim_set_current_buf(_G.outside)]], note = "outside $REPOS_DIR" },
    { keys = ":Copy filepath repos<CR>" },
    { expect = [[_G.eq(_G.clip(), "outside.txt")]], note = "the cwd-relative path, no error" },
    { lua = [[vim.fn.setreg("+", "stale")]] },
    { keys = ":CopyFilepathRepos<CR>" },
    { expect = [[_G.eq(_G.clip(), "outside.txt")]], note = "the compat command agrees" },
    { expect = [[not _G.noted("not set")]], note = "no error so far" },

    { lua = [[vim.api.nvim_set_current_buf(_G.config)]], note = "a config buffer" },
    { keys = ":Copy filepath env<CR>" },
    {
      expect = [[_G.eq(_G.clip(), "$NVIM_CONFIG_DIR/lua/b.lua")]],
      note = "that root comes from stdpath('config')",
    },

    { keys = ":let $REPOS_DIR = ''<CR>", note = "an empty value counts as unset" },
    { lua = [[vim.fn.setreg("+", "kept"); _G.forget()]] },
    { keys = ":Copy filepath repos<CR>" },
    { expect = [[_G.noted("$REPOS_DIR is not set")]], note = "repos: the error" },
    { expect = [[_G.eq(_G.clip(), "kept")]], note = "the clipboard unchanged" },
    { lua = [[_G.forget()]] },
    { keys = ":CopyFilepathRepos<CR>" },
    {
      expect = [[_G.noted("$REPOS_DIR is not set") and _G.eq(_G.clip(), "kept")]],
      note = "the compat command agrees",
    },

    { lua = [[_G.forget()]] },
    { keys = ":Copy filepath env<CR>" },
    {
      expect = [[_G.eq(_G.clip(), "$NVIM_CONFIG_DIR/lua/b.lua")]],
      note = "unset: a config buffer still folds",
    },
    { lua = [[vim.api.nvim_set_current_buf(_G.repo)]] },
    { keys = ":Copy filepath env<CR>" },
    {
      expect = [[_G.eq(_G.clip(), _G.rel)]],
      note = "unset: a repo buffer falls back to the cwd-relative path",
    },
    { expect = [[not _G.noted("not set")]], note = "no error, unlike repos mode" },
  },
}
