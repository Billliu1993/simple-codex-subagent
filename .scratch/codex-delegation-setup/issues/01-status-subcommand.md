# 01: Status subcommand on the wrapper

**What to build:** Claude checks on a run with one short line, `status <run dir>`, that falls inside the wrapper's existing pre-approval, so a look at a run never costs a paste or a permission prompt. The output says whether the pid is alive or exited with its exit code, seconds since the progress log last moved, the thread id when known, the review scope on a review, a flag quoting the reason when a resume fell back, then the last five lines of each non-empty progress log file under a header. It reads and prints, kills nothing, holds no threshold, and exits 0 when it read the run directory and 64 when the argument is missing, the directory cannot be read, or a flag is given.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

**Implementation:** delegate the build to an Agent-tool subagent with `model: "opus"`. The main session runs on Fable and only plans, reviews the subagent's diff, and checks the acceptance criteria. Spec: `.scratch/codex-delegation-setup/spec.md`. Governing decisions: ADR-0001, ADR-0002.

- [ ] `status <run dir>` prints, in order: pid state with exit code when exited, seconds since the log moved, thread id when present, review scope when present, resume fallback line when present, five-line tails of each non-empty log file
- [ ] Exit 0 on a readable run directory; 64 on a missing argument, an unreadable directory, or any flag
- [ ] The pid and mtime logic matches the old snippet, including the GNU-then-BSD `stat` fallback
- [ ] The ticket 03 test calls the subcommand instead of copying the skill snippet; cases cover alive mid-run, exited with the fake's code, thread id printed, review scope printed, resume fallback printed, missing directory, and a flag
- [ ] The skill's status section is the one-line invocation with the same guidance on when to run it, and the closing pre-approval paragraph no longer lists the status check among the commands that go through the permission flow
- [ ] README status section describes the subcommand and its output; the exit code table lists the new 64 cause
- [ ] `allowed-tools` is unchanged
