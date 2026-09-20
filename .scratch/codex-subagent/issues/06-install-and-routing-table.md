# 06: Installable from GitHub with a documented routing table

**What to build:** A fresh repo installs the plugin in two commands from this repo's GitHub marketplace at user scope, pastes the README's suggested CLAUDE.md routing table, and one row of it works end to end. The README documents install, update, the invocation forms, the routing table with model and effort per kind of work, the run directory, the status check, resume, review, and the manual smoke checklist run before each version bump. The version is bumped.

**Blocked by:** 02 (Implementation and research runs return a final message), 04 (Follow-up resumes the thread, falls back when it can't), 05 (Review through Codex's built-in command)

**Status:** resolved

**Implementation:** delegate the build to an Agent-tool subagent with `model: "opus"`. The main session runs on Fable and only plans, reviews the subagent's diff, and checks the acceptance criteria.

- [ ] `/plugin marketplace add Billliu1993/simple-codex-subagent` then `/plugin install codex-subagent@codex-subagent` succeeds in a fresh repo
- [x] Short form `/codex-subagent` resolves after install
- [x] README has a routing table with rows for implementation, research and exploration, review, and adversarial review, each with model and effort
- [x] One pasted row runs successfully in the fresh repo
- [x] README has the manual smoke checklist from the spec
- [ ] Plugin version bumped; `/plugin update` picks it up
- [x] README states the plugin needs no MCP server, app-server, daemon, broker, Node or Python runtime, or persistent job store

## Comments

- 2026-09-19: implemented on branch `feat/codex-subagent-plugin`, https://github.com/Billliu1993/simple-codex-subagent/pull/1. Checked items are covered by `tests/run-tests.sh` (fake codex) or by one real run during the build; unchecked items are left to the manual smoke checklist in `plugins/codex-subagent/README.md`.
- 2026-09-19: install was verified from a local marketplace path (`claude plugin marketplace add <repo>`), since the GitHub form resolves the default branch and the plugin is not on `main` until PR #1 merges. Re-check the GitHub form and `/plugin update` after the merge.
