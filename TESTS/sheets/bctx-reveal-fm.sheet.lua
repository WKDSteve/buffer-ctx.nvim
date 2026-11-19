-- Live check: `:RevealInFm` through the real lib.nvim `cross.reveal_in_fm` up to the program it starts. The file
-- managers are recording stand-ins (`fakes`): PowerShell and its win_reveal.ps1 on Windows (bare `powershell`, which a
-- `.cmd` stand-in catches), `open -R` on macOS, the first file manager with a selection on Linux (all of them are
-- stand-ins, so the one found first gets it). The sheet proves which program got which file, not that a window came
-- up; bctx-reveal.sheet.lua checks the commands and keys with lib.nvim stubbed.
return {
  id = "bctx.reveal-fm",
  feature = "bctx.reveal",
  title = "buffer-ctx.nvim: :RevealInFm starts the system file manager with the buffer's file selected",
  fakes = { "powershell", "open", "xdg-open", "nautilus", "nemo", "dolphin", "thunar", "caja" },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({})
      _G.sandbox()
      _G.open("page.html", "<p>x</p>")
      _G.calls = function()
        local fp = require("testing.fake_programs")
        local all = {}
        for _, p in ipairs({ "powershell", "open", "xdg-open", "nautilus", "nemo", "dolphin", "thunar", "caja" }) do
          for _, c in ipairs(fp.read(vim.env.TESTING_FAKES, p)) do
            all[#all + 1] = c
          end
        end
        return all
      end]],
      note = "a file in a fresh folder; every file manager is a stand-in",
    },
    { keys = ":RevealInFm<CR>" },
    { wait = [[#_G.calls() == 1]], note = "one file manager was started" },
    {
      expect = [[_G.has(table.concat(_G.calls()[1].argv, " "), "page.html")]],
      note = "it got this file (to select it)",
    },
    { expect = [[not _G.noted("stack traceback")]], note = "no error" },
  },
  manual = {
    "The file manager opens with the folder, the file selected, and comes to the foreground (Windows)",
  },
}
