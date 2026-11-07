-- Live check: `:Insert boilerplate` and `:Copy boilerplate`, through vim.ui.select (the child cannot press its
-- inputlist) and the real form of lib.nvim's kit (task buffer-ctx.nvim/testblatt-bindings-checkliste; section 2 of
-- ALL/manual-test-checklists/buffer-ctx.md). ui.nvim is not on this runtimepath; the kit.select branch is a spec.
return {
  id = "bctx.boilerplate",
  title = "buffer-ctx.nvim: the boilerplate picker, a named template, the guard-clause form, :Copy boilerplate",
  task = "buffer-ctx.nvim/testblatt-bindings-checkliste",
  sizes = { { rows = 40, cols = 120 } },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({})
      _G.sandbox()
      _G.open("lua/foo/bar.lua", "")
      _G.pick(1)]],
    },
    { keys = ":Insert boilerplate<CR>", note = "the picker, the first entry: lua-module" },
    { expect = [[_G.eq(#_G.offered, 18)]], note = "all 18 templates" },
    {
      expect = [[#vim.tbl_filter(function(l) return l:match("^[%w-]+%s+%S") ~= nil end, _G.offered) == 18]],
      note = "each with a description",
    },
    { expect = [[_G.has(_G.offered[1], "lua-module")]], note = "lua-module is the one picked" },
    {
      expect = [[_G.has(_G.text(), "---@module 'foo.bar'")]],
      note = "a skeleton with the module of this buffer",
    },

    { lua = [[_G.fresh(""); _G.pick(nil)]] },
    { keys = ":Insert boilerplate<CR>", note = "the picker dismissed" },
    { expect = [[_G.eq(_G.text(), "")]], note = "inserts nothing" },

    { keys = ":Insert boilerplate lua-class MyService<CR>", note = "no picker" },
    {
      expect = [[_G.has(_G.text(), "---@class MyService")]],
      note = "a class skeleton of that name",
    },

    { lua = [[_G.fresh("")]] },
    { input = ":Insert boilerplate guard-clause<CR>" },
    {
      wait = [[_G.in_float()]],
      note = "guard-clause asks in a form, no error on a missing argument",
    },
    { input = "<C-u>ready<CR>" },
    { settle = 50 },
    { input = "<C-u>y<CR>" },
    { wait = [[not _G.in_float()]], note = "the form is answered" },
    { expect = [[_G.has(_G.text(), "if not ready then")]], note = "the answers are in the clause" },

    { lua = [[_G.fresh("")]] },
    { input = ":Insert boilerplate guard-clause<CR>" },
    { wait = [[_G.in_float()]] },
    { input = "<Esc>" },
    { settle = 50 },
    { input = "<Esc>" },
    { wait = [[not _G.in_float()]], note = "dismissed" },
    { expect = [[_G.eq(_G.text(), "")]], note = "a dismissed form inserts nothing" },

    { lua = [[_G.fresh("")]] },
    { keys = ":Insert boilerplate html-figure<CR>" },
    { expect = [[_G.has(_G.text(), "<figure")]], note = "an HTML fragment" },
    { lua = [[_G.fresh("")]] },
    { keys = ":Insert boilerplate html-table<CR>" },
    { expect = [[_G.has(_G.text(), "<table")]], note = "another of the nine" },
    { lua = [[_G.fresh("")]] },
    { keys = ":Insert boilerplate nvim-autocmd<CR>" },
    {
      expect = [[_G.has(_G.text(), "nvim_create_autocmd")]],
      note = "the nvim_create_autocmd block",
    },
    { lua = [[_G.fresh("")]] },
    { keys = ":Insert boilerplate nvim-keymap<CR>" },
    { expect = [[_G.has(_G.text(), "vim.keymap.set")]], note = "the vim.keymap.set stub" },
    {
      expect = [[#vim.tbl_filter(function(k) return k:find("^html%-") ~= nil end, require("buffer_ctx.ops.boilerplate").list_keys()) == 9]],
      note = "nine HTML fragments",
    },

    {
      lua = [[_G.fresh("kept"); _G.want = table.concat(require("buffer_ctx.ops.boilerplate").get("html-figure"), "\n")]],
    },
    { keys = ":Copy boilerplate html-figure<CR>" },
    {
      expect = [[_G.eq(_G.clip(), _G.want)]],
      note = "the same text on the clipboard, one block joined with newlines",
    },
    { expect = [[_G.has(_G.clip(), "\n")]], note = "several lines" },
    { expect = [[_G.eq(_G.text(), "kept")]], note = "the buffer untouched" },
  },
}
