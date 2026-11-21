-- Live check: `:Insert git` hash, short, tag and branch on a detached HEAD, with the real git on a fresh repository
-- with one commit and a tag (the branch on a branch is in bctx-context.sheet.lua). hash and branch are read from the
-- .git files; short and tag are one git call in the background each, so the steps wait for the answer.
return {
  id = "bctx.git-revision",
  feature = "bctx.context",
  title = "buffer-ctx.nvim: :Insert git hash, short and tag; :Insert git branch on a detached HEAD names it",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({})
      _G.sandbox()
      _G.git = function(...)
        local out = vim.fn.system(vim.list_extend({
          "git", "-c", "user.name=sheet", "-c", "user.email=sheet@example.test", "-c", "commit.gpgsign=false",
          "-c", "tag.gpgsign=false",
        }, { ... }))
        assert(vim.v.shell_error == 0, out)
        return vim.trim(out)
      end
      _G.git("init", "-q", "-b", "main")
      vim.fn.writefile({ "one" }, _G.root .. "/a.txt")
      _G.git("add", "a.txt")
      _G.git("commit", "-q", "-m", "first")
      _G.git("tag", "v1.2.3")
      _G.sha = _G.git("rev-parse", "HEAD")
      _G.short = _G.git("rev-parse", "--short", "HEAD")
      vim.cmd("edit! " .. vim.fn.fnameescape(_G.root .. "/a.txt"))
      _G.line = function()
        return vim.api.nvim_get_current_line()
      end]],
      note = "a repository with one commit, tagged v1.2.3",
    },
    { lua = [[_G.fresh("")]] },
    { keys = ":Insert git hash<CR>" },
    { wait = [[_G.line() == _G.sha]], note = ":Insert git hash: the full commit" },
    { lua = [[_G.fresh("")]] },
    { keys = ":Insert git<CR>", note = "no mode: short" },
    { wait = [[_G.line() == _G.short]], note = "the short hash" },
    { lua = [[_G.fresh("")]] },
    { keys = ":Insert git tag<CR>" },
    { wait = [[_G.line() == "v1.2.3"]], note = "the nearest tag" },
    { keys = ":Copy git short<CR>" },
    { wait = [[_G.clip() == _G.short]], note = ":Copy git short" },

    {
      lua = [[_G.git("checkout", "-q", "--detach"); _G.fresh(""); _G.forget()]],
      note = "a detached HEAD",
    },
    { keys = ":Insert git branch<CR>" },
    { wait = [[_G.noted("detached HEAD")]], note = "it says why there is no branch" },
    { expect = [[_G.eq(_G.text(), "")]], note = "nothing is inserted" },
  },
}
