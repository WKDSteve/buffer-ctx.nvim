-- Live check: without a working clipboard provider (a "+" write that does not come back, as over SSH or in a bare
-- container) `:Copy filepath` still reaches the system clipboard: lib.nvim's `cross.copy_to_clipboard` hands the text
-- to the OS tool (`powershell Set-Clipboard` on Windows, `pbcopy` on macOS, `wl-copy`/`xclip`/`xsel` on Linux). The
-- tools are recording stand-ins (`fakes`), so the real clipboard of the machine is never touched.
-- On Windows the `.cmd` stand-in splits an argument at a `|` and runs the rest as a command (testing.nvim task
-- fake-programs-der-windows-stand-in-fuehrt-die-teile-eines-ar), so a `lua` step escapes the `|` of the PowerShell
-- command for cmd.exe before lib.nvim spawns it; the start itself stays lib.nvim's own.
return {
  id = "bctx.clipboard-fallback",
  feature = "bctx.clipboard-fallback",
  title = "buffer-ctx.nvim: :Copy filepath without a clipboard provider goes through the OS clipboard tool",
  fakes = { "powershell", "pbcopy", "wl-copy", "xclip", "xsel" },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      vim.g.clipboard = {
        name = "lost",
        copy = { ["+"] = function() end, ["*"] = function() end },
        paste = {
          ["+"] = function() return { {}, "v" } end,
          ["*"] = function() return { {}, "v" } end,
        },
        cache_enabled = 0,
      }
      if vim.fn.has("win32") == 1 then
        local run = require("lib.nvim.cross.run")
        local argv = run.argv
        run.argv = function(cmd)
          return argv((cmd:gsub("|", "^|")))
        end
      end
      require("buffer_ctx").setup({})
      _G.sandbox()
      _G.open("lua/x/y.lua", "x")
      _G.calls = function()
        local fp = require("testing.fake_programs")
        local all = {}
        for _, p in ipairs({ "powershell", "pbcopy", "wl-copy", "xclip", "xsel" }) do
          for _, c in ipairs(fp.read(vim.env.TESTING_FAKES, p)) do
            all[#all + 1] = c
          end
        end
        return all
      end]],
      note = "a provider that loses every copy; the OS clipboard tools are stand-ins",
    },
    { keys = ":Copy filepath<CR>" },
    { wait = [[#_G.calls() == 1]], note = "one OS clipboard tool was started" },
    {
      expect = [[not _G.noted("no clipboard provider")]],
      note = "reported as copied, not as a loss",
    },
    {
      expect = [[_G.has(vim.fn.getreg('"'), "y.lua")]],
      note = "the unnamed register holds the path too",
    },
  },
  manual = {
    "Once over SSH or without a clipboard tool of Neovim: :Copy filepath, then paste outside Neovim",
  },
}
