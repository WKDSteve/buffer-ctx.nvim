---@module 'buffer_ctx.ops.timestamp'
--- Formats the current time as one of several timestamp styles.

local M = {}

-- Formatting is lib.nvim's `lib.lua.time.format` (12h, weekday, long and rfc2822 with fixed
-- English names, since %p vanishes on Windows and %A/%B follow the locale). These are the
-- `os.date` patterns where this plugin's spelling differs from lib's.
local PATTERNS = {
  human = "%B %d, %Y %H:%M",
  short = "%d.%m.%Y",
  log = "%Y-%m-%d %H:%M:%S",
}

---Every accepted format name, in completion order. The single source for the
---argument check below and for the tab-completion in commands.lua.
---@type string[]
M.FORMAT_NAMES = {
  "iso",
  "iso-date",
  "iso-time",
  "unix",
  "human",
  "short",
  "log",
  "filename",
  "long",
  "weekday",
  "time",
  "12h",
  "rfc2822",
}

local VALID = {}
for _, name in ipairs(M.FORMAT_NAMES) do
  VALID[name] = true
end

---Format the current time
---@param fmt BufferCtx.TimestampFormat
---@param utc? boolean
---@return string
function M.format_timestamp(fmt, utc)
  fmt = (fmt or "iso"):lower()
  return require("lib.lua.time.format").format_timestamp(
    os.time(),
    VALID[fmt] and fmt or "iso",
    { utc = utc == true, patterns = PATTERNS }
  )
end

---@param args string[]
---@param default_fmt BufferCtx.TimestampFormat
---@return BufferCtx.TimestampFormat fmt, boolean utc, string|nil err
local function parse_common(args, default_fmt)
  local fmt = default_fmt
  local utc = false
  local unknown = {}
  for _, a in ipairs(args or {}) do
    local lo = a:lower()
    if lo == "--utc" then
      utc = true
    elseif VALID[lo] then
      fmt = lo
    else
      unknown[#unknown + 1] = a
    end
  end
  if #unknown > 0 then
    return fmt,
      utc,
      string.format(
        "unknown argument(s): %s (valid: %s, --utc)",
        table.concat(unknown, ", "),
        table.concat(M.FORMAT_NAMES, ", ")
      )
  end
  return fmt, utc, nil
end

---Parse fargs for timestamp subcommand
---@param args string[]
---@return BufferCtx.TimestampFormat fmt, boolean utc, string|nil err
function M.parse_args(args)
  return parse_common(args, "iso")
end

---Parse fargs for the `date` subcommand (same grammar, defaults to iso-date)
---@param args string[]
---@return BufferCtx.TimestampFormat fmt, boolean utc, string|nil err
function M.parse_date_args(args)
  return parse_common(args, "iso-date")
end

return M
