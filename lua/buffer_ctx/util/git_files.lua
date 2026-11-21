---@module 'buffer_ctx.util.git_files'
--- What the files in `.git` answer without starting a `git` process: where the
--- repository is, the current branch, the commit HEAD points at and the URL of
--- a remote.
---
--- A `git` start costs 50-200 ms of a frozen editor on Windows, and the
--- permalink and `:Copy git` used to start up to five of them in a row. These
--- answers sit in small plain files (`HEAD`, `refs/heads/*`, `packed-refs`,
--- `config`), so they are read directly. Every function says `nil` when the
--- files do not answer exactly the way git would (reftable, includes, URL
--- rewrites, a symbolic ref, ...); the caller then asks git.
---
--- Same approach as docmap.nvim's `core/git_files.lua`; lib.nvim is getting a
--- shared form (`git.remote_url_fast`, `git.current_ref_fast`) that can replace
--- this module once it is on lib.nvim's `ci-verified`.

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

---@param p string
---@return boolean
local function is_absolute(p)
  return p:sub(1, 1) == "/" or p:match("^%a:[/\\]") ~= nil
end

---@param base string
---@param p string
---@return string
local function resolve(base, p)
  p = p:gsub("\\", "/")
  if is_absolute(p) then
    return p
  end
  return base .. "/" .. p
end

---@param s string|nil
---@return boolean
local function is_sha(s)
  return s ~= nil and (#s == 40 or #s == 64) and s:match("^%x+$") ~= nil
end

---@class BufferCtx.GitFiles
---@field gitdir string     The repository's own directory (a linked worktree's private one)
---@field commondir string  Where refs and config live (the main `.git` for a linked worktree)
---@field top string        The work tree the `.git` was found in

---The nearest repository at or above `dir`, found by its `.git` (directory, or
---the `gitdir:` file of a linked worktree or submodule).
---@param dir string
---@return BufferCtx.GitFiles|nil
function M.find(dir)
  local cur = dir:gsub("\\", "/"):gsub("/+$", "")
  while cur ~= "" do
    local gitdir
    if read(cur .. "/.git/HEAD") then
      gitdir = cur .. "/.git"
    else
      local text = read(cur .. "/.git")
      local target = text and text:match("^gitdir:%s*(.-)%s*$")
      if target and target ~= "" then
        gitdir = resolve(cur, target)
      end
    end
    if gitdir then
      local common = read(gitdir .. "/commondir")
      local commondir = common and trim(common) ~= "" and resolve(gitdir, trim(common)) or gitdir
      return { gitdir = gitdir, commondir = commondir, top = cur }
    end
    local parent = cur:match("^(.*)/[^/]*$")
    if not parent or parent == cur then
      break
    end
    cur = parent
  end
  return nil
end

---The repository's config text ("" when unreadable), and whether it uses
---something this reader does not follow for refs (reftable, per-worktree config).
---@param info BufferCtx.GitFiles
---@return string text
---@return boolean exotic
local function config_text(info)
  local text = read(info.commondir .. "/config") or ""
  local lower = text:lower()
  return text, lower:find("refstorage") ~= nil or lower:find("worktreeconfig") ~= nil
end

---Where HEAD points: `{ branch = "main", ref = "refs/heads/main" }`, or
---`{ detached = true, sha = "<sha>" }`; nil when the files cannot tell (no
---HEAD, a ref outside `refs/heads/`, reftable).
---@param info BufferCtx.GitFiles
---@return { branch?: string, ref?: string, detached?: boolean, sha?: string }|nil
function M.head(info)
  local _, exotic = config_text(info)
  if exotic then
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
  if not ref or ref:find("[%s\\]") or ref:find("%.%.") then
    return nil
  end
  return { branch = ref:sub(#"refs/heads/" + 1), ref = ref }
end

---The commit a branch ref points at, from its loose file or `packed-refs`; nil
---when neither has it (an unborn branch, or something only git knows).
---@param info BufferCtx.GitFiles
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
---@param info BufferCtx.GitFiles
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

---The `url` of `[remote "<name>"]`, the first one like `git remote get-url`.
---`unsure` when the config could change the answer in a way this reader does
---not follow (includes, URL rewrites, quoting, the old `[remote.x]` spelling):
---ask git then. `nil, false` means: no such remote.
---@param info BufferCtx.GitFiles
---@param name string
---@return string|nil url
---@return boolean unsure
function M.remote_url(info, name)
  local text = config_text(info)
  return M.config_url(text, name)
end

---`remote_url` on a config text (pure; for tests).
---@param text string
---@param name string
---@return string|nil url
---@return boolean unsure
function M.config_url(text, name)
  local lower = text:lower()
  if lower:find("%[%s*include") or lower:find("insteadof") then
    return nil, true
  end
  local in_section = false
  for line in text:gmatch("[^\r\n]+") do
    local header = line:match("^%s*%[(.-)%]")
    if header then
      local kind, sub = header:match('^%s*(%S+)%s+"(.*)"%s*$')
      in_section = kind ~= nil and kind:lower() == "remote" and sub == name
      if not kind and header:lower():match("^%s*remote%.") then
        return nil, true
      end
    elseif in_section then
      local key, value = line:match("^%s*([%w%-]+)%s*=%s*(.-)%s*$")
      if key and key:lower() == "url" then
        if value == "" or value:find('["\\]') or value:find("%s[#;]") then
          return nil, true
        end
        return value, false
      end
    end
  end
  return nil, false
end

return M
