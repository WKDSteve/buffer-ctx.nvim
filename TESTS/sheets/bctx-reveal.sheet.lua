-- Live check: `:RevealInFm` and `:OpenInBrowser` up to the program they start (task
-- buffer-ctx.nvim/testblatt-bindings-checkliste; section 8 of ALL/manual-test-checklists/buffer-ctx.md). A file manager
-- and a browser are GUIs: lib.nvim's reveal_in_fm, vim.ui.open and open.nvim are stubs that record their arguments.
return {
  id = "bctx.reveal",
  title = "buffer-ctx.nvim: :RevealInFm, :OpenInBrowser, <leader>of, <leader>ob: what they hand over, unnamed buffers",
  task = "buffer-ctx.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.revealed = {}
      package.loaded["lib.nvim.cross.reveal_in_fm"] = function(path)
        _G.revealed[#_G.revealed + 1] = path
        return true
      end
      _G.opened = {}
      vim.ui.open = function(path)
        _G.opened[#_G.opened + 1] = path
        return {}
      end
      require("buffer_ctx").setup({})
      _G.sandbox()
      _G.open("page.html", "<p>x</p>")
      _G.page = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p")
      _G.same = function(path)
        return _G.eq(vim.fs.normalize(path), vim.fs.normalize(_G.page))
      end]],
    },
    { keys = ":RevealInFm<CR>" },
    { expect = [[_G.same(_G.revealed[1])]], note = "the file manager gets this file" },
    { keys = " of" },
    { expect = [[_G.same(_G.revealed[2])]], note = "<leader>of: the same" },

    { expect = [[not pcall(require, "open")]], note = "no open.nvim" },
    { keys = ":OpenInBrowser<CR>" },
    { expect = [[_G.same(_G.opened[1])]], note = "the fallback: vim.ui.open with the file" },
    { keys = " ob" },
    { expect = [[_G.same(_G.opened[2])]], note = "<leader>ob: the same" },
    { lua = [[_G.open("notes.md", "x")]], note = "not an HTML file" },
    { keys = ":OpenInBrowser<CR>" },
    { expect = [[_G.has(_G.opened[3], "notes.md")]], note = "the OS gets it all the same" },

    { keys = ":checkhealth buffer_ctx<CR>" },
    { wait = [[#_G.report("falls back to vim.ui.open") == 1]], note = "the report" },
    { expect = [[_G.has(_G.report("falls back to vim.ui.open")[1], "open.nvim not found")]] },
    { keys = ":bwipeout<CR>" },

    { lua = [[vim.cmd("enew!"); _G.forget(); _G.revealed = {}; _G.opened = {}]] },
    { keys = ":RevealInFm<CR>" },
    {
      expect = [[_G.noted("unnamed buffer") and _G.eq(#_G.revealed, 0)]],
      note = "a warning, no window",
    },
    { lua = [[_G.forget()]] },
    { keys = ":OpenInBrowser<CR>" },
    { expect = [[_G.noted("unnamed buffer") and _G.eq(#_G.opened, 0)]], note = "no program" },

    {
      lua = [[_G.calls = {}
      package.loaded["open"] = {
        open = function(target, scope)
          _G.calls[#_G.calls + 1] = { target, scope }
          return true
        end,
      }
      _G.open("page2.html", "x")]],
      note = "with open.nvim, stubbed",
    },
    { keys = ":OpenInBrowser<CR>" },
    { expect = [[_G.eq(_G.calls[1][1], "browser")]], note = "its browser handler" },
    { expect = [[_G.eq(_G.calls[1][2], "%")]], note = "the target is this buffer, so no picker" },
    { expect = [[_G.eq(#_G.opened, 0)]], note = "not the fallback" },
  },
  manual = {
    "The file manager opens with the folder, the file selected, and comes to the foreground (Windows)",
    "An .html file opens in the default browser; a .md or .png in the application the OS has for it",
    "With the real open.nvim: :OpenInBrowser opens the buffer, no target picker pops up",
  },
}
