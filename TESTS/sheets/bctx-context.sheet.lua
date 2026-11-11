-- Live check: location, module, timestamp, date, uuid, env, git, linecount, bufnr through :Insert and :Copy (task
-- buffer-ctx.nvim/testblatt-bindings-checkliste; section 3 of ALL/manual-test-checklists/buffer-ctx.md).
return {
  id = "bctx.context",
  feature = "bctx.context",
  title = "buffer-ctx.nvim: location with a range, module, timestamp, date, uuid, env, git, linecount, bufnr",
  task = "buffer-ctx.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({})
      _G.sandbox()
      vim.fn.system({ "git", "init", "-q", "-b", "sheet-branch" })
      _G.open("lua/foo/bar.lua", "one", "two", "three", "four", "five", "six")
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      _G.line = function()
        return vim.api.nvim_get_current_line()
      end
      _G.note = "lua/foo/bar.lua"]],
    },
    { keys = ":Copy location<CR>" },
    { expect = [[_G.eq(_G.clip(), _G.note .. ":3")]], note = "path:line" },
    { keys = "Vj<Esc>:'<,'>Copy location range<CR>", note = "a real visual range" },
    { expect = [[_G.eq(_G.clip(), _G.note .. ":L3-L4")]], note = "path:L1-L2" },
    { keys = "<Esc>V<Esc>:'<,'>Copy location range<CR>", note = "a single line" },
    { expect = [[_G.eq(_G.clip(), _G.note .. ":4")]], note = "collapses to plain path:line" },

    { keys = ":Copy module<CR>" },
    { expect = [[_G.eq(_G.clip(), 'require("foo.bar")')]], note = "the require form" },
    { keys = ":Copy module lua_ls<CR>" },
    { expect = [[_G.eq(_G.clip(), "---@module 'foo.bar'")]], note = "the @module line" },

    { lua = [[vim.api.nvim_set_current_line("")]] },
    { keys = ":Insert module<CR>" },
    { expect = [[_G.eq(_G.line(), 'require("foo.bar")')]], note = "inserted at the cursor" },

    { lua = [[_G.fresh("x"); _G.forget(); vim.api.nvim_buf_set_name(0, _G.root .. "/notes.md")]] },
    { keys = ":Insert module<CR>", note = "a buffer outside /lua/" },
    { expect = [[_G.noted("not inside a /lua/ directory")]], note = "a readable notification" },
    { expect = [[_G.eq(_G.text(), "x")]], note = "nothing inserted" },

    { lua = [[_G.fresh("")]] },
    { keys = ":Insert timestamp<CR>" },
    {
      expect = [[_G.line():match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d")]],
      note = "the default is iso",
    },
    { lua = [[_G.fresh("")]] },
    { keys = ":Insert timestamp short --utc<CR>" },
    {
      expect = [[_G.eq(_G.line(), os.date("!%d.%m.%Y"))]],
      note = "short in UTC",
    },
    { keys = ":Copy timestamp unix<CR>" },
    {
      expect = [[_G.clip():match("^%d+$") and math.abs(tonumber(_G.clip()) - os.time()) < 60]],
      note = "unix: now, in seconds",
    },
    { keys = ":Copy timestamp filename<CR>" },
    {
      expect = [[_G.clip():match("^[%w_-]+$")]],
      note = "filename: nothing a file name cannot hold",
    },
    { keys = ":Copy timestamp human<CR>" },
    { expect = [[_G.clip():match("%d") and _G.clip():match(":")]], note = "human" },
    { keys = ":Copy timestamp rfc2822<CR>" },
    {
      expect = [[_G.clip():match("^%a%a%a, %d%d %a%a%a %d%d%d%d %d%d:%d%d:%d%d")]],
      note = "rfc2822",
    },
    { keys = ":Copy timestamp nonsense<CR>" },
    { expect = [[_G.noted("nonsense")]], note = "an unknown format is an error" },
    { lua = [[_G.fresh("")]] },
    { keys = ":Insert date<CR>" },
    { expect = [[_G.line():match("^%d%d%d%d%-%d%d%-%d%d$")]], note = ":Insert date" },
    { keys = ":Copy date<CR>" },
    { expect = [[_G.clip():match("^%d%d%d%d%-%d%d%-%d%d$")]], note = ":Copy date" },

    { lua = [[_G.fresh("")]] },
    { keys = ":Insert uuid<CR>" },
    {
      expect = [[_G.line():match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-[89ab]%x%x%x%-%x+$")]],
      note = "standard",
    },
    { keys = ":Copy uuid standard<CR>" },
    {
      expect = [[#_G.clip() == 36 and _G.clip() == _G.clip():lower()]],
      note = "standard: lower case, with hyphens",
    },
    { keys = ":Copy uuid compact<CR>" },
    { expect = [[_G.clip():match("^%x+$") and #_G.clip() == 32]], note = "compact" },
    { keys = ":Copy uuid upper<CR>" },
    { expect = [[#_G.clip() == 36 and _G.clip() == _G.clip():upper()]], note = "upper" },
    { keys = ":Copy uuid braced<CR>" },
    { expect = [[_G.clip():match("^{%x+%-.+}$") and #_G.clip() == 38]], note = "braced" },

    { lua = [[_G.fresh(""); vim.env.BCTX_SHEET = "a value"]] },
    { keys = ":Insert env BCTX_SHEET<CR>" },
    { expect = [[_G.eq(_G.line(), "a value")]], note = "the value of a real variable" },
    { keys = ":Copy env BCTX_SHEET<CR>" },
    { expect = [[_G.eq(_G.clip(), "a value")]], note = ":Copy env" },

    { lua = [[_G.fresh("")]] },
    { keys = ":Insert git branch<CR>" },
    { expect = [[_G.eq(_G.line(), "sheet-branch")]], note = "the branch of a real repository" },
    { keys = ":Copy git branch<CR>" },
    { expect = [[_G.eq(_G.clip(), "sheet-branch")]], note = ":Copy git branch" },

    {
      lua = [[_G.fresh("a", "b", "c"); vim.fn.setreg("+", ""); vim.api.nvim_win_set_cursor(0, { 3, 0 }); vim.cmd("normal! $")]],
    },
    { keys = ":Insert linecount<CR>" },
    { expect = [[_G.has(_G.text(), "3")]], note = ":Insert linecount" },
    { keys = ":Copy linecount<CR>" },
    { expect = [[_G.eq(_G.clip(), "3")]], note = ":Copy linecount" },
    { lua = [[_G.fresh("")]] },
    { keys = ":Insert bufnr<CR>" },
    {
      expect = [[_G.eq(_G.line(), tostring(vim.api.nvim_get_current_buf()))]],
      note = ":Insert bufnr",
    },
    { keys = ":Copy bufnr<CR>" },
    {
      expect = [[_G.eq(_G.clip(), tostring(vim.api.nvim_get_current_buf()))]],
      note = ":Copy bufnr",
    },

    { lua = [[_G.fresh(""); vim.api.nvim_buf_set_name(0, _G.root .. "/lua/x/y.lua")]] },
    { keys = ":Insert filepath<CR>" },
    { expect = [[_G.eq(_G.line(), "lua/x/y.lua")]], note = ":Insert filepath" },
    { lua = [[_G.fresh(""); vim.api.nvim_buf_set_name(0, _G.root .. "/lua/x/z.lua")]] },
    { keys = ":Insert filename<CR>" },
    { expect = [[_G.eq(_G.line(), "z.lua")]], note = ":Insert filename" },
    { lua = [[_G.fresh(""); vim.api.nvim_buf_set_name(0, _G.root .. "/lua/x/w.lua")]] },
    { keys = ":Insert location<CR>" },
    { expect = [[_G.eq(_G.line(), "lua/x/w.lua:1")]], note = ":Insert location" },
  },
}
