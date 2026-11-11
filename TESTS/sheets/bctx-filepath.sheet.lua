-- Live check: `:Copy filepath` and its keys (task buffer-ctx.nvim/testblatt-bindings-checkliste; section 1 of
-- ALL/manual-test-checklists/buffer-ctx.md and the buffer-ctx lines of the bindings checklist).
return {
  id = "bctx.filepath",
  feature = "bctx.filepath",
  title = "buffer-ctx.nvim: :Copy filepath in all its forms, the compat commands and the <leader>cn keys",
  task = "buffer-ctx.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({})
      _G.sandbox()
      _G.open("lua/buffer_ctx/ops/filepath.lua", "local M = {}", "return M")
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      _G.rel = "lua/buffer_ctx/ops/filepath.lua"
      _G.abs = _G.root .. "/" .. _G.rel]],
    },
    { keys = ":Copy filepath<CR>" },
    { expect = [[_G.eq(_G.clip(), _G.rel)]], note = "cwd-relative with forward slashes on +" },
    { expect = [[_G.eq(vim.fn.getreg('"'), _G.rel)]], note = "and on the unnamed register" },
    { expect = [[_G.noted("copied: " .. _G.rel)]], note = "it says what it copied" },
    { keys = ":Copy filepath abs<CR>" },
    { expect = [[_G.eq(_G.clip(), _G.abs)]], note = "absolute" },
    { keys = ":Copy filepath lua<CR>" },
    { expect = [[_G.eq(_G.clip(), "buffer_ctx.ops.filepath")]], note = "the dotted module form" },

    { keys = ":Copy filepath 0<CR>" },
    { expect = [[_G.eq(_G.clip(), "filepath.lua")]], note = "depth 0: the file name" },
    { keys = ":Copy filepath 1<CR>" },
    { expect = [[_G.eq(_G.clip(), "ops/filepath.lua")]], note = "depth 1: the last two segments" },
    { keys = ":Copy filepath 2<CR>" },
    {
      expect = [[_G.eq(_G.clip(), "buffer_ctx/ops/filepath.lua")]],
      note = "depth 2: the last three",
    },
    { keys = ":Copy filepath 3<CR>" },
    {
      expect = [[_G.eq(_G.clip(), _G.rel)]],
      note = "depth 3: the last four, never the first ones",
    },

    { keys = ":Copy filepath bogus<CR>" },
    { expect = [[_G.noted("[filepath] unknown argument(s): bogus")]], note = "a typo is an error" },

    { keys = ":CopyFilepathAbsolute<CR>" },
    { expect = [[_G.eq(_G.clip(), _G.abs)]], note = "the compat command for absolute" },
    { keys = ":Copy filepath absolute<CR>" },
    { expect = [[_G.eq(_G.clip(), _G.abs)]], note = "the same as :Copy filepath absolute" },
    { keys = ":CopyFilepathRelative<CR>" },
    { expect = [[_G.eq(_G.clip(), _G.rel)]], note = "the compat command for relative" },
    { keys = ":Copy filepath relative<CR>" },
    { expect = [[_G.eq(_G.clip(), _G.rel)]], note = "the same as :Copy filepath relative" },

    { lua = [[vim.fn.setreg("+", "stale")]] },
    { keys = " cnf" },
    { expect = [[_G.eq(_G.clip(), _G.rel)]], note = "<leader>cnf: as bare :Copy filepath" },
    { keys = " cnl" },
    { expect = [[_G.eq(_G.clip(), _G.rel .. ":2")]], note = "<leader>cnl: path:line" },
    { keys = " cnm" },
    {
      expect = [[_G.eq(_G.clip(), "buffer_ctx.ops.filepath")]],
      note = "<leader>cnm: as :Copy module",
    },

    { keys = ":Copy filename<CR>" },
    { expect = [[_G.eq(_G.clip(), "filepath.lua")]], note = ":Copy filename" },
    { keys = ":Copy filename noext<CR>" },
    { expect = [[_G.eq(_G.clip(), "filepath")]], note = ":Copy filename noext" },

    { lua = [[vim.cmd("edit! " .. vim.fn.fnameescape(_G.config_dir() .. "/lua/plugins/x.lua"))]] },
    { keys = ":Copy filepath nvim<CR>" },
    { expect = [[_G.eq(_G.clip(), "lua/plugins/x.lua")]], note = "relative to stdpath('config')" },
    { lua = [[vim.cmd("edit! " .. vim.fn.fnameescape(_G.abs))]] },
    { keys = ":Copy filepath nvim<CR>" },
    { expect = [[_G.eq(_G.clip(), _G.rel)]], note = "outside the config: the cwd-relative path" },

    { lua = [[vim.cmd("enew!")]] },
    { keys = ":Copy filepath<CR>" },
    { expect = [[_G.noted("unnamed buffer")]], note = "an unnamed buffer is a readable error" },
  },
}
