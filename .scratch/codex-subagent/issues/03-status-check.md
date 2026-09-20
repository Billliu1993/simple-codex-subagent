# 03: Status check on a running run

**What to build:** While a run is live, Claude can answer "what is it doing?" from the run directory path it announced at dispatch: whether the pid is alive, how long since the progress log last moved, and its last few lines. The check never kills anything and carries no thresholds; killing is the user's call and any threshold lives in a repo's CLAUDE.md.

**Blocked by:** 02 (Implementation and research runs return a final message)

**Status:** resolved

**Implementation:** delegate the build to an Agent-tool subagent with `model: "opus"`. The main session runs on Fable and only plans, reviews the subagent's diff, and checks the acceptance criteria.

- [x] Skill text has the status check as one command Claude runs when asked or before waiting on a result
- [x] Output shows pid alive or exited, seconds since the log last moved, and the last lines of the log
- [x] Skill text states no automatic kill and no fixed thresholds
- [x] Test: with a fake `codex` that sleeps, the check mid-run reports alive and a recent log; after exit it reports exited

## Comments

- 2026-09-19: implemented on branch `feat/codex-subagent-plugin`, https://github.com/Billliu1993/simple-codex-subagent/pull/1. Checked items are covered by `tests/run-tests.sh` (fake codex) or by one real run during the build; unchecked items are left to the manual smoke checklist in `plugins/codex-subagent/README.md`.
