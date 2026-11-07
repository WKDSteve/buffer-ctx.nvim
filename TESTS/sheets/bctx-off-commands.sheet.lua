-- Live check: `commands = false` (task buffer-ctx.nvim/testblatt-bindings-checkliste; section 7 of
-- ALL/manual-test-checklists/buffer-ctx.md).
return {
  id = "bctx.off-commands",
  title = "buffer-ctx.nvim: commands = false removes :Insert and :Copy, the Lua API works, :Format and :Mark stay",
  task = "buffer-ctx.nvim/testblatt-bindings-checkliste",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({ commands = false })
      _G.fresh("")
      vim.env.BCTX_SHEET = "api"]],
    },
    { expect = [[_G.eq(vim.fn.exists(":Insert"), 0)]], note = ":Insert is not there" },
    { expect = [[_G.eq(vim.fn.exists(":Copy"), 0)]], note = ":Copy is not there" },
    { expect = [[_G.eq(vim.fn.exists(":CopyFilepathEnv"), 0)]], note = "the compat ones neither" },
    { expect = [[_G.eq(vim.fn.exists(":Format"), 2)]], note = ":Format has its own switch" },
    { expect = [[_G.eq(vim.fn.exists(":Mark"), 2)]], note = ":Mark has its own switch" },
    { lua = [[require("buffer_ctx").insert("env", { "BCTX_SHEET" })]] },
    { expect = [[_G.eq(_G.text(), "api")]], note = "the Lua API inserts" },
    { lua = [[require("buffer_ctx").copy("env", { "BCTX_SHEET" })]] },
    { expect = [[_G.eq(_G.clip(), "api")]], note = "the Lua API copies" },
  },
}
