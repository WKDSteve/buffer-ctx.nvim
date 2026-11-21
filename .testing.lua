-- .testing.lua -- configuration of testing.nvim for this project.
-- Written by `testing migrate`; edit freely (it is never overwritten). Every key is optional; the
-- keys are documented in testing.nvim's docs/CONFIG.md. Loading this file executes it (same trust
-- as running the specs).
return {
  -- Lua module root of the project.
  plugin = "buffer_ctx",
  -- How the spec files are run: "auto" = sniffed per file, "h" = on the project's own TESTS/harness.lua,
  -- "script" = a self-running script in its own process.
  dialect = { ["TESTS/sheets_spec.lua"] = "busted", ["*"] = "h" },
  -- Dependencies (directory names) put on the runtimepath: $<NAME>_DIR, .deps/<name>, ../<name>,
  -- stdpath('data')/lazy/<name>.
  deps = { "lib.nvim" },
  -- "none" = all specs in one nvim, "file" = one nvim per spec file
  -- (nothing leaks from one file into the next). "file" also resolves the state guard: the specs
  -- call setup() (user commands, keymaps, autocmds) and open buffers, which would otherwise leak
  -- from one file into the next.
  isolated = "file",
  -- All test sheets run in one spec file, one child editor each: the defaults of 10 s per case and 60 s per
  -- file are reached under load (fileops, 2026-11-07).
  timeouts = { case_ms = 30000, file_ms = 300000 },
  -- Environment variables the specs read; a child editor inherits an allowlist only (never secrets).
  env_allow = { "LIB_NVIM_PATH" },
  -- Guards (docs/GUARDS.md): safety nets around every spec; all clean on this suite.
  guards = {
    fs = "error",
    state = "error",
    scheduled_error = "error",
    deprecation = "error",
    process_net = "error",
    prompt = "error",
  },
  -- What the guards let through on purpose.
  guard_allow = {
    -- The specs create throwaway git repositories (git init/commit/rev-parse/checkout) to test
    -- the repo-root detection and repos-relative paths.
    -- sheets_spec.lua: every test sheet (TESTS/sheets/) runs in a child editor.
    spawn = { "git", "nvim" },
  },
  -- The runner counts which commands, keymaps and autocommands the specs exercise (docs/SURFACE.md of testing.nvim);
  -- `scripts/test.sh surface` compares that with surface.baseline.json (a regression gate, not a percentage).
  surface = { track = true },
  -- gated: a failed conformance check makes `scripts/test.sh conformance` exit 1 (docs/CONFORMANCE.md of testing.nvim)
  conformance = {
    gate = true,
    waivers = {
      {
        check = "K13",
        level = "warn",
        text = ":Copy is a prefix",
        reason = "the :CopyFilepath* family is deliberate and public (one command per path flavour); :Copy itself is the bare verb of the family, not a separate command to disambiguate",
        expires = "2027-04-14",
      },
      {
        check = "K13",
        level = "warn",
        text = ":Mark is a prefix",
        reason = "the :Mark* family (:MarkLineToggle, :MarkLinesYank) is deliberate and public; renaming would break users' mappings and muscle memory",
        expires = "2027-04-14",
      },
      {
        check = "K13",
        level = "warn",
        text = ":Open is a prefix",
        reason = "bare :Open is open.nvim's command, not this plugin's; :OpenInBrowser is a deliberate public name and renaming it would break users",
        expires = "2027-04-14",
      },
    },
  },
  ci = {
    -- The GitHub workflow, generated: `testing init . --workflow=public --force` writes .github/workflows/ci.yml from
    -- this (testing.nvim docs/WORKFLOW-CI.md); the step workflow-in-sync keeps the two together.
    workflow = {
      name = "buffer-ctx.nvim",
      layout = "hosted",
      -- the steps that depend on the platform: the windows and macOS legs run only these
      platform = { "suite", "conformance" },
      -- `testing ci land`: a check branch ci/** runs the hosted legs, main moves only once it is green there (CI-05)
      land = true,
      -- more checkouts below .deps/, not on the runtimepath of the specs: only test sheets put them there
      checkouts = {
        {
          repo = "nvim-telescope/telescope.nvim",
          ref = "40aedd8a68c78a656a10a8d62d80c54af59420fb",
          why = "only the test sheet bctx-telescope puts it on its runtimepath (the SHA of emojis.nvim; bump deliberately)",
        },
        {
          repo = "nvim-lua/plenary.nvim",
          ref = "74b06c6c75e4eeb3108ec01852001636d85a932b",
          why = "telescope.nvim needs it for the test sheet bctx-telescope",
        },
        {
          repo = "WKDSteve/markdown.nvim",
          ref = "88864df894a44e5f82a94cdcda27aad91e10b15f",
          why = "only the test sheet bctx-mdlink-markdown loads it; markdown.nvim publishes no ci-verified yet",
        },
        {
          repo = "WKDSteve/open.nvim",
          ref = "ci-verified",
          why = "only the test sheet bctx-reveal-open loads it",
        },
      },
    },
    steps = {
      ["workflow-in-sync"] = { preset = "workflow-in-sync" },
      -- the job `health` of the hand-written workflow: setup() and :checkhealth buffer_ctx load cleanly
      health = {
        run = { "nvim", "-n", "-i", "NONE", "-u", "NONE", "-l", "scripts/checkhealth.lua" },
        env = { LIB_NVIM_DIR = "${deps.lib.nvim}" },
      },
    },
  },
}
