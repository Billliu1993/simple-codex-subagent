# 04: Follow-up resumes the thread, falls back when it can't

**What to build:** `/codex-subagent --model M --effort E --resume <thread-id> <delta>` continues the same Codex thread so a follow-up like "now fix items 2 and 4" costs one short prompt. The wrapper maps this to the exec resume form with the same model, effort, and output options. The resume form has no sandbox flag (verified on codex-cli 0.155.1), so the wrapper passes the sandbox as a `sandbox_mode` config override on every resume: read-only with `--read-only`, workspace-write otherwise. A resumed run never inherits its sandbox from the thread or from the user's config. If resume fails before a thread-started event, the wrapper starts a fresh run with the same prompt, notes the abandoned resume on stderr and in the run directory, and the fresh run's thread id is recorded. The skill text tells Claude to offer resume for follow-ups on a known thread and to send only the delta.

**Blocked by:** 02 (Implementation and research runs return a final message)

**Status:** resolved

**Implementation:** delegate the build to an Agent-tool subagent with `model: "opus"`. The main session runs on Fable and only plans, reviews the subagent's diff, and checks the acceptance criteria.

- [x] Thread id captured from the first JSON event of a run and stored in the run directory
- [x] `--resume <id>` invokes the exec resume form with the id, model, effort, and last-message output
- [x] Every resume invocation carries `-c sandbox_mode="read-only"` or `-c sandbox_mode="workspace-write"` matching the `--read-only` flag; never the `--sandbox` flag, which resume does not accept
- [x] Resume failure before a thread-started event triggers a fresh run with the same prompt
- [x] Fallback is reported on stderr and recorded in the run directory
- [x] Skill text tells Claude when to resume and to send only the delta
- [x] Tests cover thread id capture, resume argv, and the fallback path
- [x] Tests assert the `sandbox_mode` override is present on resume for both sandboxes and that the fallback fresh run uses the same sandbox
- [x] Smoke: a read-only run resumed with `--read-only` cannot write a file; the same thread resumed without `--read-only` can

## Comments

- 2026-09-19: implemented on branch `feat/codex-subagent-plugin`, https://github.com/Billliu1993/simple-codex-subagent/pull/1. Checked items are covered by `tests/run-tests.sh` (fake codex) or by one real run during the build; unchecked items are left to the manual smoke checklist in `plugins/codex-subagent/README.md`.
- 2026-09-19: smoke item verified live on codex-cli 0.155.1 through a project-level copy of the skill: the thread resumed with `--read-only` and `--strict-config` had its write rejected by the sandbox ("writing is blocked by read-only sandbox"); the same thread resumed without `--read-only` wrote the file. No fallback fired in either resume.
