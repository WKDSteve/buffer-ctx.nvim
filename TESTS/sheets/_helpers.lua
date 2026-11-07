-- TESTS/sheets/_helpers.lua -- what the buffer-ctx.nvim test sheets need in their child editor. Not a sheet
-- (`testing.sheet` only reads *.sheet.lua); a sheet's first step runs it with `dofile`, the child's cwd is the
-- project root. The directory is in the spec's @cache-inputs, so a change here re-runs the sheets.

local M = {}

vim.opt.shortmess:append("I")
vim.o.swapfile = false
vim.o.hidden = true
-- As in the real config: a leader the checklist's keys can be read with.
vim.g.mapleader = " "

-- The clipboard leaves the machine: a provider that keeps the text in this editor. The commands go through the real
-- "+" register and lib.nvim's verified round trip all the same.
_G.clipboard = {}
local function copy(reg)
  return function(lines, regtype)
    _G.clipboard[reg] = { lines, regtype }
  end
end
local function paste(reg)
  return function()
    return _G.clipboard[reg] or { {}, "v" }
  end
end
vim.g.clipboard = {
  name = "sheet",
  copy = { ["+"] = copy("+"), ["*"] = copy("*") },
  paste = { ["+"] = paste("+"), ["*"] = paste("*") },
  cache_enabled = 0,
}

-- Every notification, for the steps that look at the wording.
_G.notes = {}
vim.notify = function(msg)
  _G.notes[#_G.notes + 1] = tostring(msg)
end

---Whether a notification so far holds `text` (plain).
---@param text string
---@return boolean
function _G.noted(text)
  return table.concat(_G.notes, "\n"):find(text, 1, true) ~= nil
end

-- A child editor answers every real prompt with "cancelled" (nothing can press inputlist() or input() there): what
-- the plugin asks is recorded and answered from a queue. The code around the prompt is the plugin's own.
_G.asked = {}
_G.answers = {}
vim.fn.input = function(prompt)
  local opts = type(prompt) == "table" and prompt or { prompt = prompt }
  _G.asked[#_G.asked + 1] = opts.prompt
  return table.remove(_G.answers, 1) or ""
end

---Queue the answers of the next `input()` prompts.
---@param ... string
function _G.answer(...)
  _G.answers = { ... }
end

---Make `vim.ui.select` record its items and pick entry `index` (nil = dismissed).
---@param index integer|nil
function _G.pick(index)
  vim.ui.select = function(items, _, on_choice)
    _G.offered = items
    on_choice(index and items[index] or nil, index)
  end
end

---Forget the notifications so far.
function _G.forget()
  _G.notes = {}
end

---`got == want`, or an error that says what came instead (the failure line of the sheet shows it).
---@param got any
---@param want any
---@return boolean
function _G.eq(got, want)
  if got ~= want then
    error(("got %s, wanted %s"):format(vim.inspect(got), vim.inspect(want)), 0)
  end
  return true
end

---`text` holds `part` (plain), or an error that shows the text.
---@param text string
---@param part string
---@return boolean
function _G.has(text, part)
  if not tostring(text):find(part, 1, true) then
    error(("no %s in %s"):format(vim.inspect(part), vim.inspect(text)), 0)
  end
  return true
end

---What is on the clipboard, as one string.
---@return string
function _G.clip()
  return vim.fn.getreg("+")
end

---The current buffer as one string, lines joined by a newline.
---@return string
function _G.text()
  return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
end

---A new unnamed buffer holding the given lines, the cursor on the first one.
---@param ... string
function _G.fresh(...)
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { ... })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

---A temp dir (its real path: a runner's temp may be a short name or a link) as the child's cwd, in `_G.root`.
function _G.sandbox()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  _G.root = vim.fs.normalize(vim.uv.fs_realpath(dir))
  vim.fn.chdir(_G.root)
end

---Write `rel` below the sandbox and edit it.
---@param rel string
---@param ... string  the lines of the file
function _G.open(rel, ...)
  local path = _G.root .. "/" .. rel
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile({ ... }, path)
  vim.cmd("edit! " .. vim.fn.fnameescape(path))
end

---The config directory of this editor, normalized (a config buffer needs no file on disk).
---@return string
function _G.config_dir()
  return vim.fs.normalize(vim.fn.stdpath("config"))
end

---The current window is a float (a form or a picker of the kit).
---@return boolean
function _G.in_float()
  return vim.api.nvim_win_get_config(0).relative ~= ""
end

---The marks of the current buffer as a string of "<line>:<sign>" entries, by line.
---@return string
function _G.marks()
  local out = {}
  local ns = vim.api.nvim_get_namespaces()
  for name, id in pairs(ns) do
    if name:find("BufferCtx", 1, true) then
      for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, id, 0, -1, { details = true })) do
        if m[4].sign_text or m[4].virt_text then
          local sign = m[4].sign_text or m[4].virt_text[1][1]
          out[#out + 1] = { m[2] + 1, vim.trim(sign), m[4].sign_hl_group or m[4].hl_group or "" }
        end
      end
    end
  end
  table.sort(out, function(a, b)
    return a[1] < b[1]
  end)
  return table.concat(
    vim.tbl_map(function(m)
      return m[1] .. ":" .. m[2]
    end, out),
    " "
  )
end

---A normal-mode mapping exists for `lhs` (`maparg()` without a dict is "" for a Lua callback, bound or not).
---@param lhs string
---@return boolean
function _G.bound(lhs)
  return vim.fn.maparg(lhs, "n", false, true).lhs ~= nil
end

---The lines of `:checkhealth buffer_ctx` of the current buffer that hold `text`.
---@param text string
---@return string[]
function _G.report(text)
  return vim.tbl_filter(function(l)
    return l:find(text, 1, true) ~= nil
  end, vim.api.nvim_buf_get_lines(0, 0, -1, false))
end

---Put the named sibling plugins on the runtimepath; false when one is not to be found. For `requires`.
---@param ... string
---@return boolean
function M.add_deps(...)
  for _, name in ipairs({ ... }) do
    local env = vim.env[(name:upper():gsub("[^%w]", "_")) .. "_DIR"]
    local hit
    local data = vim.env.LOCALAPPDATA and (vim.env.LOCALAPPDATA .. "/nvim-data")
      or "~/.local/share/nvim"
    for _, dir in ipairs({
      env or "",
      ".deps/" .. name,
      "../" .. name,
      vim.fn.expand(data) .. "/lazy/" .. name,
    }) do
      if dir ~= "" and vim.fn.isdirectory(dir .. "/lua") == 1 then
        hit = vim.fs.normalize(vim.fn.fnamemodify(dir, ":p"))
        break
      end
    end
    if not hit then
      return false
    end
    vim.opt.rtp:append(hit)
  end
  return true
end

return M
