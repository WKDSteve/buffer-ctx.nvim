-- Live check: `:Copy location remote` builds the forge permalink of the line from the real git of a fresh repository
-- (origin on GitHub, one commit): the origin comes from .git/config, the tracked path, HEAD and whether the file
-- differs from HEAD from two git calls that run together in the background (`ls-files`, `status`), so the steps wait
-- for the clipboard. No network: the URL is only built, never opened.
return {
  id = "bctx.permalink",
  feature = "bctx.permalink",
  title = "buffer-ctx.nvim: :Copy location remote copies the GitHub permalink, warns when the file differs from HEAD",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({})
      _G.sandbox()
      _G.git = function(...)
        local out = vim.fn.system(vim.list_extend({
          "git", "-c", "user.name=sheet", "-c", "user.email=sheet@example.test", "-c", "commit.gpgsign=false",
        }, { ... }))
        assert(vim.v.shell_error == 0, out)
        return vim.trim(out)
      end
      _G.git("init", "-q", "-b", "main")
      _G.git("remote", "add", "origin", "https://github.com/owner/repo.git")
      vim.fn.mkdir(_G.root .. "/lua", "p")
      vim.fn.writefile({ "one", "two", "three" }, _G.root .. "/lua/a.lua")
      _G.git("add", "lua/a.lua")
      _G.git("commit", "-q", "-m", "first")
      _G.sha = _G.git("rev-parse", "HEAD")
      vim.cmd("edit! " .. vim.fn.fnameescape(_G.root .. "/lua/a.lua"))
      vim.api.nvim_win_set_cursor(0, { 2, 0 })]],
      note = "a committed file, origin on GitHub, the cursor on line 2",
    },
    { keys = ":Copy location remote<CR>" },
    {
      wait = [[_G.clip() == "https://github.com/owner/repo/blob/" .. _G.sha .. "/lua/a.lua#L2"]],
      note = "the permalink of the line at HEAD, once git answered in the background",
    },
    { expect = [[not _G.noted("differs from HEAD")]], note = "a clean file: no warning" },

    { lua = [[_G.forget()]] },
    { keys = "Goadded<Esc>:write<CR>", note = "a saved change: the file differs from HEAD" },
    { keys = "gg:Copy location remote<CR>" },
    {
      wait = [[(_G.clip() or ""):find("/lua/a.lua#L1", 1, true) ~= nil]],
      note = "still the permalink",
    },
    {
      expect = [[_G.noted("file differs from HEAD")]],
      note = "with the warning that the lines may have moved",
    },
  },
}
