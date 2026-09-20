# 07: Maintainer update check

**What to build:** In this repo only, `/check-codex-updates` reports whether the wrapper still matches the installed Codex CLI. It compares the installed version with the latest published version, diffs live help output for exec, resume, and review against snapshots stored in the repo with the version they were taken from, lists release notes for versions after the snapshot's, and names the wrapper lines that reference anything changed. On request it refreshes the snapshots. It never edits the wrapper.

**Blocked by:** 05 (Review through Codex's built-in command)

**Status:** resolved

**Implementation:** delegate the build to an Agent-tool subagent with `model: "opus"`. The main session runs on Fable and only plans, reviews the subagent's diff, and checks the acceptance criteria.

- [x] Skill lives under this repo's own skills directory, not in the plugin
- [x] Reports installed and latest versions and whether they differ
- [x] Snapshots for exec, resume, and review help output stored with version 0.155.1 (the CLI moved past 0.154.0 before the build started; take snapshots from the installed binary, never from the spec)
- [x] Diffs live help output against the snapshots and shows the changes
- [x] Lists release notes for versions newer than the snapshot version
- [x] Names wrapper lines that reference a changed flag or config key
- [x] Refreshes snapshots only when asked; never edits the wrapper
- [x] Running it with no CLI change reports "no drift"

## Comments

- 2026-09-19: implemented on branch `feat/codex-subagent-plugin`, https://github.com/Billliu1993/simple-codex-subagent/pull/1. Checked items are covered by `tests/run-tests.sh` (fake codex) or by one real run during the build; unchecked items are left to the manual smoke checklist in `plugins/codex-subagent/README.md`.
