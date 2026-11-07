-- Live check: `:Insert imagepaste` without images.nvim and up to its door with one (task
-- buffer-ctx.nvim/testblatt-bindings-checkliste; section 3b of ALL/manual-test-checklists/buffer-ctx.md). A real image
-- on a real clipboard is for a person: the stub stands in for images.nvim, which reads the OS clipboard.
return {
  id = "bctx.imagepaste",
  title = "buffer-ctx.nvim: :Insert imagepaste hands name and path mode over, no :Copy, an error without images.nvim",
  task = "buffer-ctx.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({})
      _G.fresh("kept")]],
    },
    { expect = [[not pcall(require, "images")]], note = "no images.nvim" },
    { keys = ":Insert imagepaste<CR>" },
    {
      expect = [[_G.noted("images.nvim not found (required for imagepaste)")]],
      note = "the error",
    },
    { expect = [[_G.eq(_G.text(), "kept")]], note = "the buffer unchanged" },

    { lua = [[_G.forget()]] },
    { keys = ":Copy imagepaste<CR>", ignore_errmsg = true, note = "not a subcommand of :Copy" },
    {
      expect = [[_G.has(table.concat(_G.notes, "\n"), "imagepaste")]],
      note = "the composer says so",
    },
    { expect = [[not _G.noted("images.nvim not found")]], note = "it never got to images.nvim" },

    {
      lua = [[_G.forget()
      package.loaded["images"] = {
        paste = function(name, force_ask, path_mode)
          _G.pasted = { name = name, force_ask = force_ask, path_mode = path_mode }
        end,
      }]],
      note = "images.nvim, stubbed: it reads the OS clipboard",
    },
    { keys = ":Insert imagepaste<CR>" },
    {
      expect = [[_G.pasted and _G.eq(_G.pasted.name, nil)]],
      note = "no name: images.nvim prompts",
    },
    { keys = ":Insert imagepaste shot-01<CR>" },
    { expect = [[_G.eq(_G.pasted.name, "shot-01")]], note = "the given name" },
    { expect = [[_G.eq(_G.pasted.force_ask, nil)]], note = "no prompt forced" },
    { keys = ":Insert imagepaste path=absolute<CR>" },
    { expect = [[_G.eq(_G.pasted.path_mode, "absolute")]], note = "absolute" },
    { keys = ":Insert imagepaste path=relative<CR>" },
    { expect = [[_G.eq(_G.pasted.path_mode, "relative")]], note = "relative" },
    { keys = ":Insert imagepaste path=repos<CR>" },
    { expect = [[_G.eq(_G.pasted.path_mode, "repos")]], note = "repos" },
    { expect = [[_G.eq(#_G.notes, 0)]], note = "buffer-ctx adds no message of its own" },
    {
      expect = [[#vim.tbl_filter(function(c) return c:find("^path=") ~= nil end, vim.fn.getcompletion("Insert imagepaste path=", "cmdline")) == 3]],
      note = "<Tab> after path= completes the three values",
    },
  },
  manual = {
    "With images.nvim and an image in the OS clipboard: :Insert imagepaste writes the file, its link appears at the cursor",
    "The same with a name (:Insert imagepaste shot-01, no prompt) and with path=absolute|relative|repos: the link follows",
    "With images.nvim and no image in the clipboard: images.nvim reports that itself, buffer-ctx adds nothing",
  },
}
