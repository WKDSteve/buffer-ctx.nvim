-- TESTS/git_async_spec.lua -- `:Copy location remote` and `:Copy git` never wait for git.
--
-- `vim.system` is replaced by a stand-in that records every start and whose `wait()` throws: a blocking git call
-- fails the case. The spec answers the recorded starts by hand, so it also sees that the command returned before
-- git answered, how many starts it took, and that a newer request drops the older one's answer. The repository is
-- plain files (`.git/HEAD`, `config`, a loose ref): the branch, the full hash and the origin URL come from them
-- without any start at all. No real git runs here.

return function(H)
  local commands = require("buffer_ctx.commands")
  local sha = string.rep("c", 40)

  -- A repository made of files only: HEAD on main, origin on GitHub, one loose ref.
  local root = vim.fn.tempname():gsub("\\", "/")
  vim.fn.mkdir(root .. "/.git/refs/heads", "p")
  vim.fn.mkdir(root .. "/lua", "p")
  vim.fn.writefile({ "ref: refs/heads/main" }, root .. "/.git/HEAD")
  vim.fn.writefile({
    "[core]",
    "\trepositoryformatversion = 0",
    '[remote "origin"]',
    "\turl = https://github.com/owner/repo.git",
    "\tfetch = +refs/heads/*:refs/remotes/origin/*",
  }, root .. "/.git/config")
  vim.fn.writefile({ sha }, root .. "/.git/refs/heads/main")
  vim.fn.writefile({ "one", "two", "three" }, root .. "/lua/a.lua")

  vim.cmd("edit! " .. vim.fn.fnameescape(root .. "/lua/a.lua"))
  local buf = vim.api.nvim_get_current_buf()

  -- The stand-in: records, never runs, never lets anybody wait.
  local real_system = vim.system
  local starts, waited = {}, {}
  vim.system = function(cmd, _, on_exit)
    local start = { cmd = cmd, on_exit = on_exit }
    starts[#starts + 1] = start
    return {
      wait = function()
        waited[#waited + 1] = table.concat(cmd, " ")
        error("blocking wait on " .. table.concat(cmd, " "))
      end,
      kill = function() end,
      is_closing = function()
        return false
      end,
    }
  end

  local function verb(start)
    for i, a in ipairs(start.cmd) do
      if a == "-C" then
        local v = start.cmd[i + 2]
        return v == "--no-optional-locks" and start.cmd[i + 3] or v
      end
    end
    return start.cmd[2] == "--no-optional-locks" and start.cmd[3] or start.cmd[2]
  end

  ---Answer every recorded start like git would for the file repository above.
  local function answer_all(list)
    for _, start in ipairs(list) do
      local v, out = verb(start), ""
      if v == "ls-files" then
        out = "lua/a.lua\0"
      elseif v == "status" then
        out = "# branch.oid " .. sha .. "\0# branch.head main\0"
      elseif v == "rev-parse" then
        out = "ccccccc\n"
      end
      start.on_exit({ code = 0, signal = 0, stdout = out, stderr = "" })
    end
  end

  local function settled()
    return vim.wait(2000, function()
      return commands.pending() == 0
    end, 5)
  end

  local function fresh()
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "two", "three" })
    vim.bo[buf].modified = false
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    starts, waited = {}, {}
  end

  local link = "https://github.com/owner/repo/blob/" .. sha .. "/lua/a.lua#L2"

  -- :Insert location remote returns before git answers, with at most two starts.
  fresh()
  local ok, err = pcall(commands._dispatch, "location", { "remote" }, "cursor")
  H.ok(ok, "location remote: the command does not wait for git (" .. tostring(err) .. ")")
  H.eq(table.concat(waited, " | "), "", "location remote: no blocking wait")
  H.ok(#starts >= 1 and #starts <= 2, "location remote: at most two git starts, got " .. #starts)
  H.eq(commands.pending(), 1, "location remote: the request waits for git")
  H.eq(
    vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1],
    "two",
    "nothing is inserted before git answers"
  )
  local verbs = {}
  for _, s in ipairs(starts) do
    verbs[#verbs + 1] = verb(s)
  end
  table.sort(verbs)
  H.eq(
    table.concat(verbs, ","),
    "ls-files,status",
    "location remote: the origin URL comes from .git/config"
  )
  answer_all(starts)
  H.ok(settled(), "location remote: the request settles once git answered")
  H.match(
    vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1] or "",
    vim.pesc(link),
    "location remote: the permalink is inserted from the callback"
  )

  -- A newer request drops the older one's answer: one link, the newer one's.
  fresh()
  commands._dispatch("location", { "remote" }, "cursor")
  local first = starts
  starts = {}
  vim.api.nvim_win_set_cursor(0, { 3, 0 })
  commands._dispatch("location", { "remote" }, "cursor")
  local second = starts
  H.eq(commands.pending(), 1, "location remote: only the newest request is pending")
  answer_all(first)
  vim.wait(50, function()
    return false
  end)
  H.eq(
    table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"),
    "one\ntwo\nthree",
    "location remote: the superseded answer inserts nothing"
  )
  answer_all(second)
  H.ok(settled(), "location remote: the newer request settles")
  local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
  H.match(text, vim.pesc("/lua/a.lua#L3"), "location remote: the newer request's line is linked")
  H.ok(not text:find("#L2", 1, true), "location remote: the older request's link never lands")

  -- :Insert git branch and hash: answered from .git without a start.
  fresh()
  commands._dispatch("git", { "branch" }, "cursor")
  H.eq(#starts, 0, "git branch: no git start, HEAD names the branch")
  H.ok(settled(), "git branch: settles")
  H.match(vim.api.nvim_get_current_line(), "main", "git branch: inserted from .git/HEAD")
  fresh()
  commands._dispatch("git", { "hash" }, "cursor")
  H.eq(#starts, 0, "git hash: no git start, the loose ref has the commit")
  H.ok(settled(), "git hash: settles")
  H.match(vim.api.nvim_get_current_line(), sha, "git hash: inserted from the ref file")

  -- :Insert git short still asks git (only git knows the abbreviation), without waiting.
  fresh()
  ok, err = pcall(commands._dispatch, "git", { "short" }, "cursor")
  H.ok(ok, "git short: the command does not wait for git (" .. tostring(err) .. ")")
  H.eq(#starts, 1, "git short: one start")
  H.eq(table.concat(waited, " | "), "", "git short: no blocking wait")
  answer_all(starts)
  H.ok(settled(), "git short: settles")
  H.match(vim.api.nvim_get_current_line(), "ccccccc", "git short: inserted from the callback")

  -- A detached HEAD is named from the file, no start either.
  vim.fn.writefile({ sha }, root .. "/.git/HEAD")
  fresh()
  local notify = require("buffer_ctx.util.notify")
  local original_error, errs = notify.error, {}
  notify.error = function(msg)
    errs[#errs + 1] = msg
  end
  commands._dispatch("git", { "branch" }, "cursor")
  settled()
  notify.error = original_error
  H.eq(#starts, 0, "git branch on a detached HEAD: no git start")
  H.match(errs[1] or "", "detached HEAD", "git branch on a detached HEAD: says so")

  vim.system = real_system
  vim.cmd("bwipeout! " .. buf)
  vim.fn.delete(root, "rf")
end
