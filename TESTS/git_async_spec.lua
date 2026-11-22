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

  -- A clipboard provider that loses every copy, set before anything copies: Neovim keeps the provider it found
  -- first (on Windows that can be win32yank.exe, the machine's real clipboard). lib.nvim then goes to the OS tool,
  -- which the stand-in below records and never runs.
  local saved_clipboard = vim.g.clipboard
  vim.g.clipboard = {
    name = "lost",
    copy = {
      ["+"] = function() end,
      ["*"] = function() end,
    },
    paste = {
      ["+"] = function()
        return { {}, "v" }
      end,
      ["*"] = function()
        return { {}, "v" }
      end,
    },
    cache_enabled = 0,
  }

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

  -- The global git config is the machine's: `remote_url_fast` would ask git if it rewrote URLs. Point it here.
  local saved_env = {
    HOME = vim.env.HOME,
    USERPROFILE = vim.env.USERPROFILE,
    XDG_CONFIG_HOME = vim.env.XDG_CONFIG_HOME,
  }
  vim.env.HOME, vim.env.USERPROFILE, vim.env.XDG_CONFIG_HOME = root, root, root

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
        out = "abc1234\n"
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

  -- A packed ref answers without a start too (no loose file for main).
  local packed_sha = string.rep("d", 40)
  vim.fn.rename(root .. "/.git/refs/heads/main", root .. "/.git/main.loose")
  vim.fn.writefile(
    { "# pack-refs with: peeled fully-peeled sorted", packed_sha .. " refs/heads/main" },
    root .. "/.git/packed-refs"
  )
  fresh()
  commands._dispatch("git", { "hash" }, "cursor")
  H.eq(#starts, 0, "git hash: no git start, packed-refs has the commit")
  H.ok(settled(), "git hash (packed): settles")
  H.match(vim.api.nvim_get_current_line(), packed_sha, "git hash: inserted from packed-refs")
  vim.fn.delete(root .. "/.git/packed-refs")
  vim.fn.rename(root .. "/.git/main.loose", root .. "/.git/refs/heads/main")

  -- A reftable repository: the files cannot answer the way git would, so git is asked, in the background.
  vim.fn.mkdir(root .. "/.git/reftable", "p")
  vim.fn.writefile(
    { "0x000000000001-0x000000000001-00000000.ref" },
    root .. "/.git/reftable/tables.list"
  )
  fresh()
  ok, err = pcall(commands._dispatch, "git", { "hash" }, "cursor")
  H.ok(ok, "git hash (reftable): the command does not wait for git (" .. tostring(err) .. ")")
  H.eq(#starts, 1, "git hash (reftable): one git start")
  H.eq(verb(starts[1] or { cmd = {} }), "rev-parse", "git hash (reftable): git rev-parse")
  H.eq(table.concat(waited, " | "), "", "git hash (reftable): no blocking wait")
  answer_all(starts)
  H.ok(settled(), "git hash (reftable): settles")
  H.match(
    vim.api.nvim_get_current_line(),
    "abc1234",
    "git hash (reftable): inserted from git's answer"
  )
  vim.fn.delete(root .. "/.git/reftable", "rf")

  -- :Insert git short still asks git (only git knows the abbreviation), without waiting.
  fresh()
  ok, err = pcall(commands._dispatch, "git", { "short" }, "cursor")
  H.ok(ok, "git short: the command does not wait for git (" .. tostring(err) .. ")")
  H.eq(#starts, 1, "git short: one start")
  H.eq(table.concat(waited, " | "), "", "git short: no blocking wait")
  answer_all(starts)
  H.ok(settled(), "git short: settles")
  H.match(vim.api.nvim_get_current_line(), "abc1234", "git short: inserted from the callback")

  -- Two different inserts while git is busy: both land (pending per command and mode).
  fresh()
  commands._dispatch("git", { "short" }, "cursor")
  commands._dispatch("git", { "hash" }, "cursor")
  answer_all(starts)
  H.ok(settled(), "git short + hash: both settle")
  local both = vim.api.nvim_get_current_line()
  H.match(both, "abc1234", "git short + hash: the short hash lands")
  H.match(both, sha, "git short + hash: the full hash lands too")

  -- The clipboard ends with what was asked last: a copy made now drops the one still waiting for git.
  local clip = require("buffer_ctx.util.clip")
  local real_copy, copied = clip.copy, {}
  clip.copy = function(s, cb)
    copied[#copied + 1] = s
    if cb then
      cb(true, nil, s)
      return nil
    end
    return true, nil, s
  end
  fresh()
  commands._dispatch("git", { "short" }, "clip")
  commands._dispatch("git", { "hash" }, "clip")
  answer_all(starts)
  H.ok(settled(), "copy git short, then hash: settles")
  H.eq(table.concat(copied, ","), sha, "copy git short, then hash: only the hash is copied")
  copied = {}
  fresh()
  commands._dispatch("git", { "short" }, "clip")
  commands._dispatch("bufnr", {}, "clip")
  H.eq(commands.pending(), 0, "a synchronous copy drops the pending one")
  answer_all(starts)
  vim.wait(50, function()
    return false
  end)
  H.eq(
    table.concat(copied, ","),
    tostring(buf),
    "the late git answer does not overwrite the clipboard"
  )
  clip.copy = real_copy

  -- A copy that does not go through the command (a keymap, :Mark yank) also wins over a pending git answer.
  fresh()
  commands._dispatch("git", { "short" }, "clip")
  clip.copy("yanked elsewhere", function() end)
  answer_all(starts)
  H.ok(settled(), "copy git short, then a yank: settles")
  vim.wait(50, function()
    return false
  end)
  H.eq(vim.fn.getreg('"'), "yanked elsewhere", "the late git answer does not overwrite a yank")

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

  -- :Copy without a clipboard provider: the OS tool (PowerShell on Windows) runs in the background. The command
  -- returns at once, nothing waits on it, and the report comes from the callback.
  local said = {}
  local original_info, original_warn = notify.info, notify.warn
  notify.info = function(msg)
    said[#said + 1] = msg
  end
  notify.warn = function(msg)
    said[#said + 1] = msg
  end
  fresh()
  ok, err = pcall(commands._dispatch, "bufnr", {}, "clip")
  H.ok(ok, "copy: the command does not wait for the clipboard tool (" .. tostring(err) .. ")")
  H.eq(table.concat(waited, " | "), "", "copy: no blocking wait")
  H.eq(table.concat(said, " | "), "", "copy: nothing reported before the copy is done")
  H.eq(vim.fn.getreg('"'), tostring(buf), "copy: the unnamed register holds the text at once")
  if vim.fn.has("win32") == 1 then
    H.eq(#starts, 1, "copy: one clipboard tool started on Windows")
    H.match(
      table.concat(starts[1] and starts[1].cmd or {}, " "),
      "powershell",
      "copy: it is PowerShell"
    )
  end
  for _, s in ipairs(starts) do
    if s.on_exit then -- a blocking start has none (and already failed its wait above)
      s.on_exit({ code = 0, signal = 0, stdout = "", stderr = "" })
    end
  end
  vim.wait(2000, function()
    return #said > 0
  end, 5)
  H.eq(#said, 1, "copy: one report from the callback")
  notify.info, notify.warn = original_info, original_warn
  vim.g.clipboard = saved_clipboard

  vim.system = real_system
  vim.env.HOME, vim.env.USERPROFILE, vim.env.XDG_CONFIG_HOME =
    saved_env.HOME, saved_env.USERPROFILE, saved_env.XDG_CONFIG_HOME
  vim.cmd("bwipeout! " .. buf)
  vim.fn.delete(root, "rf")
end
