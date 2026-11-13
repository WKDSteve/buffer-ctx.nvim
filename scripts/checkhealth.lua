-- scripts/checkhealth.lua -- the "checkhealth loads" gate of CI: a plain install (this plugin and
-- lib.nvim, no runner, no user config) runs `setup({})` and `:checkhealth buffer_ctx` cleanly.
--
--   nvim -n -i NONE -u NONE -l scripts/checkhealth.lua
--
-- lib.nvim is taken from $LIB_NVIM_DIR, else the sibling checkout ../lib.nvim (what CI checks out).
-- Exit code 0: setup() returned and the report has a buffer_ctx section without an ERROR line.
-- Exit code 1: setup() raised, the report could not be produced, or it holds an ERROR. A
-- `-c "lua ..." -c checkhealth` command line cannot be that gate: nvim reports a failing `-c`
-- and still exits 0.

local root = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(vim.fn.fnamemodify(arg[0], ":p"))))
local lib = vim.env.LIB_NVIM_DIR
if not lib or lib == "" then
  lib = vim.fs.dirname(root) .. "/lib.nvim"
end
vim.opt.runtimepath:append(root)
vim.opt.runtimepath:append(lib)

---@param msg string
local function fail(msg)
  io.stdout:write("checkhealth: FAIL " .. msg .. "\n")
  os.exit(1)
end

local ok_setup, err_setup = pcall(function()
  require("buffer_ctx").setup({})
end)
if not ok_setup then
  fail("require('buffer_ctx').setup({}) raised: " .. tostring(err_setup))
end

local ok_health, err_health = pcall(vim.cmd.checkhealth, "buffer_ctx")
if not ok_health then
  fail(":checkhealth buffer_ctx raised: " .. tostring(err_health))
end

local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
io.stdout:write(table.concat(lines, "\n") .. "\n")

local has_section, errors = false, {}
for _, line in ipairs(lines) do
  if line:find("^buffer_ctx") then
    has_section = true
  end
  if line:find("ERROR", 1, true) then
    errors[#errors + 1] = line
  end
end
if not has_section then
  fail("the report has no buffer_ctx section")
end
if #errors > 0 then
  fail(#errors .. " ERROR line(s) in the report:\n" .. table.concat(errors, "\n"))
end

io.stdout:write("checkhealth: ok (setup() returned, no ERROR in :checkhealth buffer_ctx)\n")
os.exit(0)
