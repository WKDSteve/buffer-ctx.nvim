---@module 'buffer_ctx.ops.git'
--- Current git revision info for the buffer's repository.
--- Modes: hash (full SHA), short (abbreviated SHA), branch (current branch),
--- tag (nearest tag via describe). Queries run in the buffer's own directory,
--- so the result is correct even when :cd points somewhere else.
---@see buffer_ctx.ops.location for the file-position counterpart

local git_run = require("buffer_ctx.util.git_run")

local M = {}
local api = vim.api
local fn = vim.fn

---@type table<string, boolean>
local MODES = { hash = true, short = true, branch = true, tag = true }

---@internal
---Directory to run git in: the buffer's own directory, else cwd.
---@return string
local function repo_dir()
  local name = api.nvim_buf_get_name(0)
  if name and name ~= "" then
    local dir = fn.fnamemodify(name, ":p:h")
    if fn.isdirectory(dir) == 1 then
      return dir
    end
  end
  return fn.getcwd()
end

local DETACHED = "detached HEAD — no current branch"

-- What each mode asks git when the `.git` files cannot answer.
---@type table<string, string[]>
local ARGS = {
  branch = { "symbolic-ref", "--short", "-q", "HEAD" },
  hash = { "rev-parse", "HEAD" },
  short = { "rev-parse", "--short", "HEAD" },
  tag = { "describe", "--tags", "--always" },
}

---@internal
---The steps of one mode against a blocking or an asynchronous git job.
---
--- `branch` and `hash` come from the `.git` files (HEAD, the branch's ref,
--- `packed-refs`) without a process; `short` (only git knows the
--- abbreviation length) and `tag` start one git, and so does whatever the
--- files cannot answer exactly.
---@param mode string  a valid mode
---@param dir string
---@param job BufferCtx.GitJob
---@param done fun(result: string|nil, err: string|nil)
local function steps(mode, dir, job, done)
  if mode == "branch" or mode == "hash" then
    local git_files = require("buffer_ctx.util.git_files")
    local info = git_files.find(dir)
    local head = info and git_files.head(info)
    if head and mode == "branch" then
      if head.branch then
        return done(head.branch, nil)
      end
      return done(nil, DETACHED)
    end
    local sha = head and info and git_files.head_sha(info)
    if sha then
      return done(sha, nil)
    end
  end

  job.run(ARGS[mode], function(res)
    local value = res.ok and vim.trim(res.stdout or "") or ""
    if value ~= "" then
      return done(value, nil)
    end
    -- `symbolic-ref -q` exits 1 (and prints nothing) on a detached HEAD;
    -- 128 is "not a repository". The case is worth naming.
    if mode == "branch" and res.code == 1 then
      return done(nil, DETACHED)
    end
    return done(nil, "git: could not resolve " .. mode)
  end)
end

---@internal
---@param mode? string
---@return string|nil mode, string|nil err
local function check(mode)
  mode = (mode or "short"):lower()
  if not MODES[mode] then
    return nil, "unknown git mode: " .. mode .. " (hash|short|branch|tag)"
  end
  if fn.executable("git") == 0 then
    return nil, "git executable not found in PATH"
  end
  return mode, nil
end

---Get git revision info for the current buffer's repository. Blocks while
---git runs (at most one start); the commands use `get_async`.
---@param mode? BufferCtx.GitMode  default "short"
---@return string|nil result, string|nil err
function M.get(mode)
  local m, err = check(mode)
  if not m then
    return nil, err
  end
  local dir = repo_dir()
  local result
  steps(m, dir, git_run.job(false, dir), function(r, e)
    result, err = r, e
  end)
  return result, err
end

---`get` without blocking: `on_done` answers on the main loop, exactly once
---unless the handle is stopped first. The repository is the one of the
---buffer current now.
---@param mode? BufferCtx.GitMode  default "short"
---@param on_done fun(result: string|nil, err: string|nil)
---@return { stop: fun() } handle  stop(): kill git, never answer
function M.get_async(mode, on_done)
  local job
  local m, err = check(mode)
  local dir = m and repo_dir() or ""
  job = git_run.job(true, dir)
  local function answer(r, e)
    -- The files answer at once; the caller still gets a later tick, always.
    vim.schedule(function()
      if not job.stopped then
        on_done(r, e)
      end
    end)
  end
  if not m then
    answer(nil, err)
  else
    steps(m, dir, job, answer)
  end
  return { stop = job.stop }
end

---Parse fargs for the git subcommand
---@param args string[]
---@return BufferCtx.GitMode
function M.parse_args(args)
  return ((args and args[1]) and args[1]:lower()) or "short"
end

return M
