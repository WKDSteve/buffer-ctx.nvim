-- Live check: `:Insert annotation` with its prompts and `:Insert snippet` from a real VSCode-format file (task
-- buffer-ctx.nvim/testblatt-bindings-checkliste; section 3 of ALL/manual-test-checklists/buffer-ctx.md).
return {
  id = "bctx.annotation-snippet",
  title = "buffer-ctx.nvim: annotations, prompted and given, multi-word arguments; snippets by key, prefix and picker",
  task = "buffer-ctx.nvim/testblatt-bindings-checkliste",
  sizes = { { rows = 30, cols = 100 } },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.sandbox()
      local path = _G.root .. "/snippets.json"
      vim.fn.writefile({ vim.json.encode({
        ["For loop"] = { prefix = "fori", body = { "for ${1:i} = 1, ${2:n} do", "  $0", "end" }, description = "a loop" },
      }) }, path)
      require("buffer_ctx").setup({ snippets = { paths = { path } } })
      _G.open("lua/foo/bar.lua", "")
      _G.line = function()
        return vim.api.nvim_get_current_line()
      end]],
    },
    { keys = ":Insert annotation module<CR>" },
    { expect = [[_G.eq(_G.line(), "---@module 'foo.bar'")]], note = "module takes no prompt" },
    { lua = [[_G.fresh("")]] },
    { keys = ":Insert annotation class Foo<CR>" },
    { expect = [[_G.eq(_G.line(), "---@class Foo")]], note = "class, given" },
    { lua = [[_G.fresh(""); _G.answer("Prompted")]] },
    { keys = ":Insert annotation class<CR>", note = "the argument omitted" },
    { expect = [[_G.eq(_G.line(), "---@class Prompted")]], note = "class: asked with input()" },
    { expect = [[_G.eq(_G.asked[#_G.asked], "Class name: ")]], note = "it asked" },
    { lua = [[_G.fresh(""); _G.answer("name", "string")]] },
    { keys = ":Insert annotation param<CR>" },
    { expect = [[_G.eq(_G.line(), "---@param name string")]], note = "param: both asked" },
    { lua = [[_G.fresh(""); _G.answer("integer")]] },
    { keys = ":Insert annotation param name<CR>" },
    { expect = [[_G.eq(_G.line(), "---@param name integer")]], note = "param: the type asked" },
    { lua = [[_G.fresh(""); _G.answer("boolean")]] },
    { keys = ":Insert annotation return<CR>" },
    { expect = [[_G.eq(_G.line(), "---@return boolean")]], note = "return: asked" },

    { lua = [[_G.fresh(""); _G.answer("Adds two", "a", "number", "b", "string", "", "boolean")]] },
    { keys = ":Insert annotation function<CR>", note = "the dialog" },
    {
      expect = [[_G.eq(_G.text(), "---Adds two\n---@param a number\n---@param b string\n---@return boolean\n")]],
      note = "one block out of one motion",
    },

    { lua = [[_G.fresh("")]] },
    { keys = ":Insert annotation overload fun(a: string): bool<CR>" },
    {
      expect = [[_G.eq(_G.line(), "---@overload fun(a: string): bool")]],
      note = "overload is not cut at the first space",
    },
    { lua = [[_G.fresh("")]] },
    { keys = ":Insert annotation deprecated use M.new instead<CR>" },
    {
      expect = [[_G.eq(_G.line(), "---@deprecated use M.new instead")]],
      note = "deprecated neither",
    },
    { keys = ":Copy annotation class Copied<CR>" },
    { expect = [[_G.eq(_G.clip(), "---@class Copied")]], note = ":Copy annotation" },

    { lua = [[_G.fresh(""); _G.pick(1)]] },
    { keys = ":Insert snippet<CR>", note = "the picker" },
    {
      expect = [[_G.eq(_G.text(), "for i = 1, n do\n  \nend\n")]],
      note = "placeholders are plain text",
    },
    { lua = [[_G.fresh("")]] },
    { keys = ":Insert snippet For loop<CR>", note = "by its display key" },
    { expect = [[_G.has(_G.text(), "for i = 1, n do")]], note = "resolved by key" },
    { lua = [[_G.fresh("")]] },
    { keys = ":Insert snippet fori<CR>", note = "by its prefix" },
    { expect = [[_G.has(_G.text(), "for i = 1, n do")]], note = "resolved by prefix" },
    { keys = ":Copy snippet fori<CR>" },
    { expect = [[_G.eq(_G.clip(), "for i = 1, n do\n  \nend")]], note = ":Copy snippet" },
  },
}
