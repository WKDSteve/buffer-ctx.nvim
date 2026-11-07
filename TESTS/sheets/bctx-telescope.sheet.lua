-- Live check: the Telescope boilerplate picker with the real telescope.nvim (task
-- buffer-ctx.nvim/testblatt-bindings-checkliste; section 6 of ALL/manual-test-checklists/buffer-ctx.md). CI checks
-- telescope and plenary out beside this repository, pinned as in emojis.nvim and cmdlog.nvim.
return {
  id = "bctx.telescope",
  title = "buffer-ctx.nvim: :Telescope buffer_ctx lists the templates, previews lines, guard-clause does not prompt",
  task = "buffer-ctx.nvim/testblatt-bindings-checkliste",
  sizes = { { rows = 40, cols = 120 } },
  requires = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua").add_deps("telescope.nvim", "plenary.nvim")]],
      reason = "telescope.nvim and plenary.nvim are not beside this repository",
    },
  },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("buffer_ctx").setup({})
      vim.cmd.runtime("plugin/telescope.lua")
      -- <C-u> clears the prompt below; telescope's default scrolls the preview.
      require("telescope").setup({ defaults = { mappings = { i = { ["<C-u>"] = false } } } })
      require("telescope").load_extension("buffer_ctx")
      local state = require("telescope.actions.state")
      _G.picker = function()
        local buf = vim.api.nvim_get_current_buf()
        return vim.bo[buf].filetype == "TelescopePrompt" and state.get_current_picker(buf) or nil
      end
      _G.results = function()
        local p = _G.picker()
        return p and p.manager and p.manager:num_results() or 0
      end
      _G.selected = function()
        local entry = _G.picker() and state.get_selected_entry()
        return entry and entry.value
      end
      _G.preview = function()
        local p = _G.picker()
        local win = p and p.preview_win
        if not win or not vim.api.nvim_win_is_valid(win) then
          return ""
        end
        return table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false), "\n")
      end
      _G.fresh("")]],
    },
    { input = ":Telescope buffer_ctx boilerplate<CR>" },
    { wait = [[_G.results() == 18]], note = "the same 18 templates" },
    { input = "lua-class" },
    { wait = [[_G.selected() == "lua-class"]], note = "found by name" },
    {
      wait = [[_G.preview():find("---@class", 1, true)]],
      note = "the preview shows the exact lines",
    },
    {
      expect = [[_G.eq(_G.text and vim.bo.filetype, "TelescopePrompt")]],
      note = "nothing committed yet",
    },

    { input = "<C-u>guard-clause" },
    { wait = [[_G.selected() == "guard-clause"]], note = "the interactive template" },
    {
      wait = [[_G.preview():find("interactive template", 1, true)]],
      note = "a static placeholder",
    },
    {
      expect = [[_G.eq(vim.bo.filetype, "TelescopePrompt")]],
      note = "no form from being highlighted",
    },

    { input = "<C-u>nvim-keymap" },
    { wait = [[_G.selected() == "nvim-keymap"]] },
    { input = "<CR>" },
    {
      wait = [[_G.picker() == nil and _G.text():find("vim.keymap.set", 1, true)]],
      note = "inserted",
    },

    { input = ":Telescope buffer_ctx<CR>", note = "the bare form" },
    { wait = [[_G.results() == 18]], note = "the same picker" },
    { input = "<C-c>" },
    { wait = [[_G.picker() == nil]], note = "cancelled" },
  },
}
