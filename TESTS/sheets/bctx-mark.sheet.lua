-- Live check: `:Mark`, its compat commands and its keys (task buffer-ctx.nvim/testblatt-bindings-checkliste; section 4
-- of ALL/manual-test-checklists/buffer-ctx.md and the mark lines of the bindings checklist).
return {
  id = "bctx.mark",
  title = "buffer-ctx.nvim: <S-m> with a count, a range marks the whole range, <C-p> yanks in order, :Mark clear",
  task = "buffer-ctx.nvim/testblatt-bindings-checkliste",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({})
      _G.sandbox()
      _G.open("marked.txt", "l1", "l2", "l3", "l4", "l5", "l6", "l7")]],
    },
    { keys = "<S-m>" },
    { expect = [[_G.eq(_G.marks(), "1:●")]], note = "a sign on the line" },
    { keys = "<S-m>" },
    { expect = [[_G.eq(_G.marks(), "")]], note = "again: gone" },

    { keys = "3<S-m>" },
    {
      expect = [[_G.eq(_G.marks(), "1:● 2:● 3:●")]],
      note = "the cursor line and the two below",
    },
    { keys = ":Mark clear<CR>" },
    { expect = [[_G.eq(_G.marks(), "")]], note = ":Mark clear" },
    { keys = "G3<S-m>" },
    { expect = [[_G.eq(_G.marks(), "7:●")]], note = "clamped at the end of the buffer" },
    { keys = ":Mark clear<CR>gg" },

    { keys = "jj<S-m>j<S-m>", note = "lines 3 and 4 marked" },
    { keys = "ggVjjjj:Mark toggle<CR>", note = "a visual range of 5 with two marked" },
    {
      expect = [[_G.eq(_G.marks(), "1:● 2:● 3:● 4:● 5:●")]],
      note = "the whole range, no checkerboard",
    },
    { keys = "<Esc>ggVjjjj:Mark toggle<CR>", note = "every line of the range is marked" },
    { expect = [[_G.eq(_G.marks(), "")]], note = "only then the range unmarks" },

    { lua = [[vim.fn.cursor(5, 1)]] },
    { keys = "<S-m>ggj<S-m>", note = "line 5 first, then line 2" },
    { keys = "<C-p>" },
    { expect = [[_G.eq(_G.clip(), "l2\nl5")]], note = "by buffer position, newline-joined" },
    { lua = [[vim.fn.setreg("+", "stale")]] },
    { keys = ":Mark yank<CR>" },
    { expect = [[_G.eq(_G.clip(), "l2\nl5")]], note = ":Mark yank" },
    { lua = [[vim.fn.setreg("+", "stale")]] },
    { keys = ":MarkLinesYank<CR>" },
    { expect = [[_G.eq(_G.clip(), "l2\nl5")]], note = ":MarkLinesYank" },
    { keys = ":Mark clear<CR>" },
    { keys = ":MarkLineToggle<CR>" },
    { expect = [[_G.eq(_G.marks(), "2:●")]], note = ":MarkLineToggle" },

    { keys = "dd", note = "the marked line deleted (this Neovim is 0.10+)" },
    {
      expect = [[vim.fn.has("nvim-0.10") == 1 and _G.eq(_G.marks(), "")]],
      note = "the mark is gone with it",
    },

    { keys = "<S-m>" },
    { lua = [[_G.name = vim.api.nvim_buf_get_name(0)]] },
    { keys = ":bwipeout!<CR>" },
    { lua = [[vim.cmd("edit " .. vim.fn.fnameescape(_G.name))]], note = "reopened" },
    { expect = [[_G.eq(_G.marks(), "")]], note = "the marks are gone" },
    { keys = "<S-m>" },
    { lua = [[vim.cmd("enew")]] },
    { keys = ":bdelete! #<CR>" },
    { lua = [[vim.cmd("edit " .. vim.fn.fnameescape(_G.name))]] },
    { expect = [[_G.eq(_G.marks(), "")]], note = "the same after :bd" },
    {
      expect = [[#vim.api.nvim_get_autocmds({ group = "BufferCtxMarkCleanup" }) > 0]],
      note = "the autocmd",
    },
    { keys = ":Mark clear<CR>" },
    { expect = [[_G.noted("No marks to clear")]], note = "nothing to clear is said" },
  },
  manual = {
    "On Neovim 0.9, if there is one: a mark is a virtual-text overlay, and it slides on when its line is deleted",
  },
}
