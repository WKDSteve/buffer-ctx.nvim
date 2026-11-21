---@module 'buffer_ctx.ops.location'
--- Current buffer location as "path:line" or "path:L1-L2".
---@see buffer_ctx.ops.filepath for the same path modes without the :line suffix

local M = {}
local api = vim.api
local fn = vim.fn
local pu = require("buffer_ctx.util.path")

---Every accepted path mode, in completion order (also feeds commands.lua).
---@type string[]
M.MODES = { "cwd", "abs", "lua", "nvim", "repos", "env" }

-- Modes whose path part is exactly what `:Copy filepath <mode>` yields.
local FILEPATH_MODES = { nvim = true, repos = true, env = true }

---@internal
---Resolve the path part of a location, without the line suffix
---@param mode? BufferCtx.LocationMode
---@return string|nil filepath, string|nil err
local function resolve_path(mode)
  local bufnr = api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(bufnr) then
    return nil, "no valid buffer"
  end

  local name = api.nvim_buf_get_name(bufnr)
  if not name or name == "" then
    return nil, "unnamed buffer"
  end

  local abs = fn.fnamemodify(name, ":p")
  mode = (mode or "cwd"):lower()
  if mode == "abs" then
    return pu.normalize_sep(abs), nil
  elseif mode == "lua" then
    return pu.get_module_path(abs) or pu.relative_to_cwd(abs), nil
  elseif FILEPATH_MODES[mode] then
    -- Root lookup (and its errors, e.g. $REPOS_DIR unset) stays in one place.
    return require("buffer_ctx.ops.filepath").get_path({ mode = mode, format = "unix" })
  end
  return pu.relative_to_cwd(abs), nil
end

---Get the current buffer location as "path:line"
---@param mode? BufferCtx.LocationMode  default "cwd"
---@return string|nil result, string|nil err
function M.get(mode)
  local filepath, err = resolve_path(mode)
  if not filepath then
    return nil, err
  end

  local win = api.nvim_get_current_win()
  local line = api.nvim_win_is_valid(win) and api.nvim_win_get_cursor(win)[1] or 1
  return filepath .. ":" .. line, nil
end

---@internal
---Normalise an optional line range to an ordered pair
---@param line1? integer
---@param line2? integer
---@return integer line1, integer line2
local function resolve_lines(line1, line2)
  -- commands.lua passes nil/nil for "no range given"; a non-nil line1 ==
  -- line2 is an explicit single-line range from the caller and must not be
  -- overridden by a stale visual selection elsewhere in the buffer.
  if not line1 or not line2 then
    local vstart, vend = fn.line("'<"), fn.line("'>")
    if vstart and vend and vstart > 0 and vend > 0 and vstart ~= vend then
      line1, line2 = vstart, vend
    end
  end

  if not line1 or not line2 then
    local win = api.nvim_get_current_win()
    local cur = api.nvim_win_is_valid(win) and api.nvim_win_get_cursor(win)[1] or 1
    line1, line2 = cur, cur
  end

  if line1 > line2 then
    line1, line2 = line2, line1
  end
  return line1, line2
end

---Get a line-range location as "path:L1-L2"
---
--- Falls back to the last visual selection ('< / '>) when no explicit range is
--- given, so `:Copy location range` works straight out of visual mode — typing
--- `:` there leaves visual mode but leaves the marks behind.
---@param mode? BufferCtx.LocationMode  default "cwd"
---@param line1? integer  range start (1-based)
---@param line2? integer  range end (1-based)
---@return string|nil result, string|nil err
function M.get_range(mode, line1, line2)
  local filepath, err = resolve_path(mode)
  if not filepath then
    return nil, err
  end

  line1, line2 = resolve_lines(line1, line2)
  -- A single line has no range to express; "path:42" is the honest answer.
  if line1 == line2 then
    return filepath .. ":" .. line1, nil
  end
  return string.format("%s:L%d-L%d", filepath, line1, line2), nil
end

---@class BufferCtx.RemoteRequest
---@field abs string       the buffer's file
---@field dir string       where git runs
---@field line1 integer
---@field line2 integer
---@field modified boolean the buffer had unsaved changes when asked

---@internal
---Everything the permalink needs from the editor, read when it is asked for
---(the answer may come later, after the cursor or buffer changed).
---@param line1? integer
---@param line2? integer
---@return BufferCtx.RemoteRequest|nil req, string|nil err
local function remote_request(line1, line2)
  local name = api.nvim_buf_get_name(0)
  if not name or name == "" then
    return nil, "unnamed buffer"
  end
  if fn.executable("git") == 0 then
    return nil, "git executable not found in PATH"
  end
  local abs = fn.fnamemodify(name, ":p")
  local dir = fn.fnamemodify(abs, ":h")
  if fn.isdirectory(dir) == 0 then
    dir = fn.getcwd()
  end
  line1, line2 = resolve_lines(line1, line2)
  return { abs = abs, dir = dir, line1 = line1, line2 = line2, modified = vim.bo.modified }, nil
end

---@internal
---Whether `git status --porcelain=v2 -z` printed an entry (the file differs
---from HEAD in the index or the work tree), and the HEAD commit it names.
---@param out string
---@return string|nil sha, boolean differs
local function parse_status(out)
  local sha, differs = nil, false
  for field in out:gmatch("[^%z]+") do
    local oid = field:match("^# branch%.oid (%x+)$")
    if oid then
      sha = oid
    elseif field:sub(1, 1) ~= "#" then
      differs = true
    end
  end
  return sha, differs
end

---@internal
---The permalink steps, against a blocking or an asynchronous git job.
---
--- At most two git starts, together: `ls-files --full-name` (tracked? the
--- repo-relative path; fails outside a repository) and `status --porcelain=v2
--- --branch` on the file (HEAD's commit, and whether the file differs from it).
--- The origin URL comes from `.git/config`; only a config this reader cannot
--- follow (includes, insteadOf) asks `git remote get-url` afterwards.
---@param req BufferCtx.RemoteRequest
---@param job BufferCtx.GitJob
---@param done fun(url: string|nil, err: string|nil, warn: string|nil)
local function remote_steps(req, job, done)
  local git_files = require("buffer_ctx.util.git_files")
  local remote_mod = require("lib.nvim.git.remote")
  local info = git_files.find(req.dir)
  local remote_url, unsure
  if info then
    remote_url, unsure = git_files.remote_url(info, "origin")
  end

  local function finish(res)
    local ls, st = res.ls, res.st
    if not (ls and ls.ok) and not (st and st.ok) then
      return done(nil, "not inside a git repository")
    end
    if not remote_url then
      return done(nil, "git: no 'origin' remote")
    end
    local remote = remote_mod.parse_remote(remote_url)
    if not remote then
      return done(nil, "cannot parse the origin remote url: " .. remote_url)
    end
    local kind = remote_mod.host_kind(remote.host)
    if not kind then
      return done(
        nil,
        string.format(
          "unknown git host '%s' (built in: github, gitlab, codeberg; see lib.nvim.git.remote.host_kind)",
          remote.host
        )
      )
    end
    local rel = ls and ls.ok and (ls.stdout or ""):match("^[^%z\r\n]+") or nil
    if not rel or rel == "" then
      return done(nil, "file is not tracked by git: no permalink possible")
    end
    local sha, differs = nil, false
    if st and st.ok then
      sha, differs = parse_status(st.stdout or "")
    end
    if not sha then
      return done(nil, "git: could not resolve HEAD (no commits yet?)")
    end

    local url = remote_mod.build(kind, remote, sha, rel, req.line1, req.line2)
    local warn
    if req.modified then
      warn = "buffer has unsaved changes: line numbers may differ from the commit"
    elseif differs then
      warn = "file differs from HEAD: line numbers may differ from the commit"
    end
    return done(url, nil, warn)
  end

  job.all({
    { "ls", { "ls-files", "--full-name", "-z", "--", req.abs } },
    {
      "st",
      { "status", "--porcelain=v2", "--branch", "-z", "--untracked-files=no", "--", req.abs },
    },
  }, function(res)
    local in_repo = (res.ls and res.ls.ok) or (res.st and res.st.ok)
    if in_repo and (not info or unsure) then
      -- Only a config the file reader cannot follow costs a third start.
      job.run({ "remote", "get-url", "--", "origin" }, function(r)
        remote_url = r.ok and vim.trim(r.stdout or "") or nil
        if remote_url == "" then
          remote_url = nil
        end
        finish(res)
      end)
      return
    end
    finish(res)
  end)
end

---Get a permalink to the cursor line or line range on the git forge.
---
--- Links the current commit (not the branch), so the link keeps pointing at
--- the same lines. Works for the hosts `lib.nvim.git.remote` knows (GitHub,
--- GitLab, Codeberg). Blocks while git runs (up to two starts); the command
--- uses `get_remote_async`.
---@param line1? integer  range start (1-based), nil = visual marks / cursor
---@param line2? integer  range end (1-based)
---@return string|nil url, string|nil err, string|nil warn  warn: the link was built but may be off
function M.get_remote(line1, line2)
  local req, err = remote_request(line1, line2)
  if not req then
    return nil, err
  end
  local url, warn
  remote_steps(req, require("buffer_ctx.util.git_run").job(false, req.dir), function(u, e, w)
    url, err, warn = u, e, w
  end)
  return url, err, warn
end

---`get_remote` without blocking: git runs in the background and `on_done`
---answers on the main loop, exactly once unless the handle is stopped first.
---What the link points at (file, lines, unsaved state) is read now.
---@param line1? integer
---@param line2? integer
---@param on_done fun(url: string|nil, err: string|nil, warn: string|nil)
---@return { stop: fun() } handle  stop(): kill git, never answer
function M.get_remote_async(line1, line2, on_done)
  local req, err = remote_request(line1, line2)
  if not req then
    local stopped = false
    vim.schedule(function()
      if not stopped then
        on_done(nil, err)
      end
    end)
    return {
      stop = function()
        stopped = true
      end,
    }
  end
  local job = require("buffer_ctx.util.git_run").job(true, req.dir)
  remote_steps(req, job, on_done)
  return { stop = job.stop }
end

---Parse fargs for location subcommand
---@param args string[]
---@return BufferCtx.LocationMode mode, boolean range, string|nil err, boolean remote
--- err is set when a token is neither "range", "remote" nor one of M.MODES (a
--- typo must not silently behave like "no argument given"). `remote` asks for
--- a forge permalink instead of a path:line (the path mode is then unused).
function M.parse_args(args)
  local mode = "cwd"
  local range = false
  local remote = false
  local mode_given = false
  local unknown = {}
  for _, a in ipairs(args or {}) do
    local lo = a:lower()
    if lo == "range" then
      range = true
    elseif lo == "remote" then
      remote = true
    elseif vim.tbl_contains(M.MODES, lo) then
      mode = lo
      mode_given = true
    else
      unknown[#unknown + 1] = a
    end
  end
  if #unknown > 0 then
    return mode,
      range,
      string.format(
        "unknown argument(s): %s (valid: %s, range, remote)",
        table.concat(unknown, ", "),
        table.concat(M.MODES, ", ")
      ),
      remote
  end
  if remote and mode_given then
    return mode, range, "remote takes no path mode (the link is repo-relative)", remote
  end
  return mode, range, nil, remote
end

return M
