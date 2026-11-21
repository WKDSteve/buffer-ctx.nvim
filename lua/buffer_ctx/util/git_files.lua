---@module 'buffer_ctx.util.git_files'
--- Where HEAD points and which commit that is, read from the files in `.git`
--- without starting a `git` process (`:Copy git branch|hash`).
---
--- A `git` start costs 50-200 ms of a frozen editor on Windows. lib.nvim reads
--- the branch and the remote URL the same way (`lib.nvim.git.files`,
--- `git.current_ref_fast`, `git.remote_url_fast`); this module adds what the
--- commands need on top: a detached HEAD named as such (not git's short sha)
--- and the full commit of HEAD (the branch's loose ref or `packed-refs`).
--- Every function says `nil` when the files do not answer exactly the way git
--- would (reftable, `GIT_DIR` in the environment, a symbolic ref, ...); the
--- caller then asks git.

local M = {}

---@param path string
---@return string|nil
local function read(path)
  local fd = io.open(path, "rb")
  if not fd then
    return nil
  end
  local ok, text = pcall(fd.read, fd, "*a")
  fd:close()
  if ok and type(text) == "string" then
    return text
  end
  return nil
end

---@param s string
---@return string
local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

---@param s string|nil
---@return boolean
local function is_sha(s)
  return s ~= nil and (#s == 40 or #s == 64) and s:match("^%x+$") ~= nil
end

---The repository at or above `dir` (`lib.nvim.git.files.find`); nil when
---there is none, or when the environment points git elsewhere (`GIT_DIR`, ...).
---@param dir string
---@return Lib.Git.Files.Info|nil
function M.find(dir)
  local files = require("lib.nvim.git.files")
  if files.env_redirects() then
    return nil
  end
  return files.find(dir)
end

---Where HEAD points: `{ branch = "main", ref = "refs/heads/main" }`, or
---`{ detached = true, sha = "<sha>" }`; nil when the files cannot tell (no
---HEAD, a ref outside `refs/heads/`, reftable, per-worktree config).
---@param info Lib.Git.Files.Info
---@return { branch?: string, ref?: string, detached?: boolean, sha?: string }|nil
function M.head(info)
  local lower = (read(info.commondir .. "/config") or ""):lower()
  if lower:find("refstorage") or lower:find("worktreeconfig") then
    return nil
  end
  local head = read(info.gitdir .. "/HEAD")
  if not head then
    return nil
  end
  head = trim(head)
  if is_sha(head) then
    return { detached = true, sha = head }
  end
  local ref = head:match("^ref:%s*(refs/heads/.+)$")
  -- A reftable repository keeps a stub HEAD naming `.invalid`.
  if not ref or ref == "refs/heads/.invalid" or ref:find("[%s\\]") or ref:find("%.%.") then
    return nil
  end
  return { branch = ref:sub(#"refs/heads/" + 1), ref = ref }
end

---The commit a branch ref points at, from its loose file or `packed-refs`; nil
---when neither has it (an unborn branch, or something only git knows).
---@param info Lib.Git.Files.Info
---@param ref string e.g. "refs/heads/main"
---@return string|nil sha
function M.ref_sha(info, ref)
  local loose = read(info.commondir .. "/" .. ref)
  if loose then
    loose = trim(loose)
    return is_sha(loose) and loose or nil
  end
  local packed = read(info.commondir .. "/packed-refs")
  if packed then
    for line in packed:gmatch("[^\r\n]+") do
      local sha, name = line:match("^(%x+) (.+)$")
      if name == ref then
        return is_sha(sha) and sha or nil
      end
    end
  end
  return nil
end

---The commit HEAD points at, or nil when only git can say.
---@param info Lib.Git.Files.Info
---@return string|nil
function M.head_sha(info)
  local head = M.head(info)
  if not head then
    return nil
  end
  if head.sha then
    return head.sha
  end
  return M.ref_sha(info, head.ref)
end

return M
