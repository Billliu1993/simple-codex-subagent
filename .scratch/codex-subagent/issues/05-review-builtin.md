# 05: Review through Codex's built-in command

**What to build:** `/codex-subagent review --model M --effort E [--uncommitted | --base <branch> | --commit <sha>] [focus]` runs Codex's built-in review and Claude presents the findings and stops. Without a scope flag the wrapper picks uncommitted on a dirty tree and base against the default branch on a clean one. Focus arrives on stdin and is passed as custom instructions. The review command takes no sandbox flag and edits nothing. When the user asks for an adversarial review, Claude prepends the skill's canned adversarial block to the focus.

**Blocked by:** 02 (Implementation and research runs return a final message)

**Status:** resolved

**Implementation:** delegate the build to an Agent-tool subagent with `model: "opus"`. The main session runs on Fable and only plans, reviews the subagent's diff, and checks the acceptance criteria.

- [x] `review` maps to the exec review form with model, effort, and last-message output; no sandbox flag is passed
- [x] `--uncommitted`, `--base`, `--commit` pass through; more than one is rejected
- [x] No scope flag: uncommitted on a dirty tree, base against the default branch on a clean tree
- [x] Focus on stdin reaches Codex as custom instructions
- [x] Review reuses the run directory and final message plumbing
- [x] Skill text has the adversarial instruction block and says when to use it
- [x] Skill text says: present findings, then stop; never apply a fix before the user chooses
- [x] Tests cover scope flags, mutual exclusion, the dirty and clean defaults, and absence of any sandbox flag
- [ ] One real review of uncommitted changes in a disposable repo returns findings and edits nothing

## Comments

- 2026-09-19: implemented on branch `feat/codex-subagent-plugin`, https://github.com/Billliu1993/simple-codex-subagent/pull/1. Checked items are covered by `tests/run-tests.sh` (fake codex) or by one real run during the build; unchecked items are left to the manual smoke checklist in `plugins/codex-subagent/README.md`.
