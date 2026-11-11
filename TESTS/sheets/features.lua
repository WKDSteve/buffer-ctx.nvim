-- TESTS/sheets/features.lua -- the functionalities of buffer-ctx.nvim as its user meets them; `testing sheets report`
-- says which ones have a feature sheet (`feature = "<id>"`) and in which state, and K16 warns about a sheet that names
-- an id not listed here. Data: read with an empty environment like a sheet (testing.nvim docs/SHEETS.md).
-- The list follows docs/FEATURES/ (README.md and its seven pages) and ALL/manual-test-checklists/buffer-ctx.md.
return {
  {
    id = "bctx.filepath",
    title = ":Copy filepath puts the path of the buffer on the clipboard, absolute, relative or below a named root",
    surface = { "command:Copy filepath", "command:Insert filepath", "binding:<leader>cn" },
    docs = "docs/FEATURES/CONTEXT.md",
  },
  {
    id = "bctx.context",
    title = "The module name, a location, a timestamp, a UUID, an env value, the git revision or buffer info at the cursor",
    surface = { "command:Insert", "command:Copy" },
    docs = "docs/FEATURES/CONTEXT.md",
  },
  {
    id = "bctx.annotations",
    title = "LuaCATS annotation lines are inserted, prompted or given, and a function gets its annotations by dialog",
    surface = { "command:Insert annotation" },
    docs = "docs/FEATURES/ANNOTATIONS.md",
  },
  {
    id = "bctx.snippets",
    title = "VSCode-format snippets are inserted by key, by prefix or from a picker",
    surface = { "command:Insert snippet" },
    docs = "docs/FEATURES/TEMPLATES.md",
  },
  {
    id = "bctx.boilerplate",
    title = "A boilerplate template is inserted by name or from a picker, asking in a form for what it needs",
    surface = { "command:Insert boilerplate", "command:Copy boilerplate" },
    docs = "docs/FEATURES/TEMPLATES.md",
  },
  {
    id = "bctx.telescope",
    title = ":Telescope buffer_ctx lists the boilerplate templates with a preview of their lines",
    surface = { "command:Telescope buffer_ctx" },
    docs = "docs/FEATURES/TEMPLATES.md",
  },
  {
    id = "bctx.format-layout",
    title = ":Format aligns columns, formats a Markdown table, reflows to a text width and enumerates lines",
    surface = {
      "command:Format table",
      "command:Format column",
      "command:Format textwidth",
      "command:Format enum",
    },
    docs = "docs/FEATURES/FORMAT.md",
  },
  {
    id = "bctx.format-lines",
    title = ":Format trims, filters, squeezes, sorts, dedups, changes case, indents and cites lines",
    surface = { "command:Format" },
    docs = "docs/FEATURES/FORMAT.md",
  },
  {
    id = "bctx.mark",
    title = "<S-m> marks lines that keep their mark through edits, <C-p> yanks the marked lines in order",
    surface = { "binding:<S-m>", "binding:<C-p>", "command:Mark" },
    docs = "docs/FEATURES/MARK.md",
  },
  {
    id = "bctx.mark-categories",
    title = "Marks belong to named categories that yank and clear on their own",
    surface = { "command:Mark" },
    docs = "docs/FEATURES/MARK.md",
  },
  {
    id = "bctx.mdlink",
    title = ":Insert mdlink writes a Markdown link to the buffer, through markdown.nvim when it is there",
    surface = { "command:Insert mdlink", "command:Copy mdlink" },
    docs = "docs/FEATURES/CROSS_PLUGIN.md",
  },
  {
    id = "bctx.imagepaste",
    title = ":Insert imagepaste pastes the clipboard image through images.nvim",
    surface = { "command:Insert imagepaste" },
    docs = "docs/FEATURES/CROSS_PLUGIN.md",
  },
  {
    id = "bctx.reveal",
    title = ":RevealInFm and :OpenInBrowser hand the buffer's file to the file manager or the browser",
    surface = {
      "command:RevealInFm",
      "command:OpenInBrowser",
      "binding:<leader>of",
      "binding:<leader>ob",
    },
    docs = "docs/FEATURES/REVEAL.md",
  },
  {
    id = "bctx.switches",
    title = "Commands, keymaps, :Format, :Mark and the reveal commands switch off on their own, the rest stays",
    surface = {
      "config:commands",
      "config:keymaps",
      "config:format",
      "config:mark",
      "config:reveal",
    },
    docs = "docs/configuration.md",
  },
}
