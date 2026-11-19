-- Live check: `:Insert snippet` over two VSCode-format files, one of them broken: the picker offers the snippets of
-- the good one, a dismissed picker inserts nothing, a body given as one string, an unknown name names the broken file.
-- Key, prefix and picker on one file are in bctx-annotation-snippet.sheet.lua. Snippets start no process.
return {
  id = "bctx.snippets",
  feature = "bctx.snippets",
  title = "buffer-ctx.nvim: :Insert snippet over two files, a dismissed picker, a string body, a broken file named",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.sandbox()
      local good = _G.root .. "/lua.json"
      vim.fn.writefile({ vim.json.encode({
        ["Require"] = { prefix = "req", body = "local M = require(\"m\")" },
        ["Module"] = { prefix = "mod", body = { "local M = {}", "", "return M" } },
      }) }, good)
      local broken = _G.root .. "/broken.json"
      vim.fn.writefile({ "{ not json" }, broken)
      require("buffer_ctx").setup({ snippets = { paths = { good, broken } } })
      _G.fresh("")]],
      note = "a good and a broken snippet file",
    },
    { lua = [[_G.pick(nil)]], note = "the picker will be dismissed" },
    { keys = ":Insert snippet<CR>" },
    {
      expect = [[_G.eq(#_G.offered >= 2, true)]],
      note = "the picker offered the snippets of the good file",
    },
    { expect = [[_G.eq(_G.text(), "")]], note = "dismissed: nothing inserted" },

    { keys = ":Insert snippet req<CR>", note = "by prefix, a body given as one string" },
    { expect = [[_G.has(_G.text(), 'local M = require("m")')]], note = "the string body" },

    { lua = [[_G.fresh(""); _G.forget()]] },
    { keys = ":Insert snippet mod<CR>" },
    {
      expect = [[_G.has(_G.text(), "local M = {}\n\nreturn M")]],
      note = "a body of lines, the empty one kept",
    },

    { lua = [[_G.fresh(""); _G.forget()]] },
    { keys = ":Insert snippet nosuch<CR>" },
    { expect = [[_G.noted("unknown snippet: nosuch")]], note = "the name is said" },
    { expect = [[_G.noted("broken.json")]], note = "with the file that did not load" },
    { expect = [[_G.eq(_G.text(), "")]], note = "nothing inserted" },
  },
}
