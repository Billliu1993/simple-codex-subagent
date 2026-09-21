# 02: Delegating skill carries mechanics only

**What to build:** The delegating skill says how a delegation is done and nothing about when it happens or how Claude behaves around it. The "When to delegate" section is replaced by one line pointing at the repo's `## Codex delegation` section. The review section keeps "a review edits nothing" and drops the instruction to present the findings and stop. The frontmatter description, the model and effort rules, the prompt template, the mandatory constraints, resume, review mechanics, the report branches, and the verification step after an implementation run all stay. A delegation run against the trimmed skill still works end to end.

**Blocked by:** 01 (Status subcommand on the wrapper)

**Status:** ready-for-agent

**Implementation:** delegate the build to an Agent-tool subagent with `model: "opus"`. The main session runs on Fable and only plans, reviews the subagent's diff, and checks the acceptance criteria. Spec: `.scratch/codex-delegation-setup/spec.md`. Governing decision: ADR-0002. Edit the skill with the `writing-for-agents` skill loaded.

- [x] "When to delegate" is gone; one line in its place says the repo's `## Codex delegation` section decides whether and when work goes to Codex and how Claude behaves around a delegation
- [x] The frontmatter description is unchanged
- [x] The review section states that a review edits nothing and no longer tells Claude to present the findings and stop
- [x] The verification step after an implementation run is unchanged
- [x] The skill text names no pause rule, no stop rule, and no threshold anywhere
- [x] Existing tests pass unchanged
- [x] One real delegation run through the trimmed skill returns a final message

## Comments

- 2026-09-20: implemented on branch `feat/codex-delegation-setup`. "When to delegate" is gone; the pointer line sits where it was, and the model/effort/sandbox paragraph is re-homed under `## Model and sandbox`. The status-check paragraph now points at this repo's `## Codex delegation` section instead of bare CLAUDE.md, for consistency with the pointer. The frontmatter is untouched (the diff shows no change above line 10). `bash tests/run-tests.sh` reports PASS: 311 FAIL: 0, unchanged from ticket 01's baseline. Grepped the skill for `propose`, `go-ahead`, `wait for`, `stop there`, `present the findings`, `minute`, `pause`: no hits.
- 2026-09-20: the real delegation run went through the trimmed skill's mechanics against the real Codex from the repo root: `printf 'Reply with the single word OK.\n' | bash plugins/codex-subagent/scripts/codex-subagent.sh run --model <config default> --effort low --read-only`, exit 0, run directory `/var/folders/f8/rxr5rt517xj0ffgj45w23ncm0000gn/T/codex-subagent/20260920-213810-8234-ngnhof`. `final-message.md` holds `OK`, and `codex-subagent.sh status <run dir>` on it printed the pid as exited with exit code 0, the seconds line, the thread id and the `events.jsonl` tail, exiting 0. Every criterion is ticked. The `Status:` line is left at `ready-for-agent` for the orchestrator to resolve after it reviews the diff.
