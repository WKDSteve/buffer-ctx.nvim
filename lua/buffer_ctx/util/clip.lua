---@module 'buffer_ctx.util.clip'
--- Copies text to the system clipboard, with an unnamed-register fallback.
--- Pure sink: returns status only, never notifies — callers decide whether
--- and how to report success/failure.
---@see buffer_ctx.util.notify for the sibling soft-dependency pattern
---@see buffer_ctx.util.cursor for the insert-at-cursor sink counterpart

local M = {}

-- Soft dependency, matching util/notify.lua's convention: prefer lib.nvim's
-- clipboard helper (macOS/Linux/Windows/WSL OS-level fallback chain when a
-- plain register write fails) when installed, fall back to setreg-only.
local ok_lib_clipboard, lib_copy_to_clipboard = pcall(require, "lib.nvim.cross.copy_to_clipboard")

---@internal
---@param text string
---@return string
local function preview_of(text)
  return #text > 60 and (text:sub(1, 57) .. "...") or text
end

---@internal
---The answer for a finished copy.
---@param clipboard_ok boolean
---@param preview string
---@return boolean ok, string|nil err, string preview
local function answer(clipboard_ok, preview)
  if not clipboard_ok then
    return false,
      "no clipboard provider — copied to the unnamed register only: " .. preview,
      preview
  end
  return true, nil, preview
end

---@internal
---Without lib.nvim: the same round-trip check it does internally, since a
---bare `setreg` succeeding proves nothing without a provider either.
---@param text string
---@return boolean
local function register_only(text)
  if pcall(vim.fn.setreg, "+", text) then
    local get_ok, got = pcall(vim.fn.getreg, "+")
    return get_ok and got == text
  end
  return false
end

---Copy text to the system clipboard (+ register). Does not notify; the
---caller decides whether/how to report `ok`/`err` to the user.
---
--- Without `on_done` it blocks until the copy is done (on Windows without a
--- clipboard provider that is a PowerShell start) and returns the answer.
--- With `on_done` it never waits: the unnamed register and, when a provider
--- takes it, the `+` register are set at once, an OS tool (lib.nvim's
--- fallback chain) runs in the background, and `on_done(ok, err, preview)`
--- comes on a later tick. lib.nvim keeps background copies in order, so the
--- clipboard ends with the last text.
---@param text string
---@param on_done? fun(ok: boolean, err: string|nil, preview: string)
---@return boolean|nil ok  false when nothing was copied or no clipboard provider
--- accepted the text (the unnamed register is still set in the latter case);
--- nil with `on_done`
---@return string|nil err  human-readable reason when `ok` is false
---@return string|nil preview  first ~60 chars of `text`, for caller-side messages
function M.copy(text, on_done)
  if type(text) ~= "string" or text == "" then
    if on_done then
      vim.schedule(function()
        on_done(false, "nothing to copy", "")
      end)
      return nil
    end
    return false, "nothing to copy", ""
  end
  local preview = preview_of(text)

  -- Guarded: without a clipboard provider (headless CI, minimal containers,
  -- no xclip/wl-copy) a "+" write is at best a silent no-op and at worst
  -- raises. Neither should cost the user the copy — the unnamed register
  -- below still carries the text.
  --
  -- `pcall(lib_copy_to_clipboard, text)` used to be the whole check here,
  -- which is wrong regardless of what lib.nvim's own function does:
  -- `pcall(f, ...)` returns whether the CALL raised, as its first value,
  -- with `f`'s own result only in the (discarded) second one. Since
  -- `lib_copy_to_clipboard` never raises, that pcall was always `true` --
  -- silently defeating the verified round-trip lib.nvim's fix added,
  -- from the one caller still checking the wrong return slot.
  if on_done then
    local answered = false
    local function finish(clipboard_ok)
      if answered then
        return
      end
      answered = true
      on_done(answer(clipboard_ok == true, preview))
    end
    if ok_lib_clipboard then
      -- The register part runs now, an OS tool in the background.
      -- A start that throws still answers (as a failed copy, on a later tick).
      if not pcall(lib_copy_to_clipboard, text, finish) then
        vim.schedule(function()
          finish(false)
        end)
      end
    else
      local clipboard_ok = register_only(text)
      vim.schedule(function()
        finish(clipboard_ok)
      end)
    end
    -- The unnamed register is always set directly: it's Vim's own register
    -- state, not something a clipboard helper (lib.nvim's or otherwise) owns.
    vim.fn.setreg('"', text)
    return nil
  end

  local clipboard_ok
  if ok_lib_clipboard then
    clipboard_ok = lib_copy_to_clipboard(text) == true
  else
    clipboard_ok = register_only(text)
  end
  vim.fn.setreg('"', text)
  return answer(clipboard_ok, preview)
end

return M
