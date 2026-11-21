---@module 'buffer_ctx.util.git_run'
--- One request's git runs: blocking or asynchronous through the same steps,
--- started together, answered once, stopped together.
---
--- The ops that ask git (`ops.location` permalink, `ops.git`) write their steps
--- once against a `job`; the blocking Lua API passes a job whose runs answer at
--- once (`lib.nvim.git.run`), the commands one whose runs answer later
--- (`lib.nvim.git.run_async`, callbacks on the main loop), so `:Copy location
--- remote` and `:Copy git` never freeze the editor while git starts.

local M = {}

---Kill a git run that hangs (a network filesystem, a credential prompt) after
---this long, so a request cannot wait forever.
M.TIMEOUT_MS = 15000

---@class BufferCtx.GitJob
---@field run fun(args: string[], cb: fun(result: Lib.Git.RunResult))  Start one `git <args>`; `cb` is never called once the job is stopped
---@field all fun(list: { [1]: string, [2]: string[] }[], cb: fun(results: table<string, Lib.Git.RunResult>))  Start every `{ key, args }` at once, answer once with all results by key
---@field stop fun()  Kill what still runs and drop every answer still to come
---@field stopped boolean

---@param async boolean  true: `lib.nvim.git.run_async`, false: the blocking `run`
---@param dir string     git runs as `git -C <dir>`
---@return BufferCtx.GitJob
function M.job(async, dir)
  local lib_git = require("lib.nvim.git")
  local opts = { dir = dir, read_only = true, timeout_ms = M.TIMEOUT_MS }
  local handles = {}
  local job = { stopped = false }

  function job.run(args, cb)
    if job.stopped then
      return
    end
    local function answer(result)
      if not job.stopped then
        cb(result)
      end
    end
    if not async then
      answer(lib_git.run(args, opts))
      return
    end
    local ok, handle = pcall(lib_git.run_async, args, opts, answer)
    if ok and type(handle) == "table" then
      handles[#handles + 1] = handle
      return
    end
    -- A start that throws still answers (on a later tick, like every async answer).
    local reason = ok and "git did not start" or tostring(handle)
    vim.schedule(function()
      answer({ ok = false, code = -1, stdout = "", stderr = reason })
    end)
  end

  function job.all(list, cb)
    local results = {}
    -- +1 until every run is started: an answer that comes at once must not finish early.
    local left = 1
    local function settle()
      left = left - 1
      if left == 0 then
        cb(results)
      end
    end
    for _, item in ipairs(list) do
      left = left + 1
      local key = item[1]
      job.run(item[2], function(result)
        results[key] = result
        settle()
      end)
    end
    settle()
  end

  function job.stop()
    job.stopped = true
    for _, handle in ipairs(handles) do
      pcall(handle.stop)
    end
    handles = {}
  end

  return job
end

return M
