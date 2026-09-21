# 01: Status subcommand on the wrapper

**What to build:** Claude checks on a run with one short line, `status <run dir>`, that falls inside the wrapper's existing pre-approval, so a look at a run never costs a paste or a permission prompt. The output says whether the pid is alive or exited with its exit code, seconds since the progress log last moved, the thread id when known, the review scope on a review, a flag quoting the reason when a resume fell back, then the last five lines of each non-empty progress log file under a header. It reads and prints, kills nothing, holds no threshold, and exits 0 when it read the run directory and 64 when the argument is missing, the directory cannot be read, or a flag is given.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

**Implementation:** delegate the build to an Agent-tool subagent with `model: "opus"`. The main session runs on Fable and only plans, reviews the subagent's diff, and checks the acceptance criteria. Spec: `.scratch/codex-delegation-setup/spec.md`. Governing decisions: ADR-0001, ADR-0002.

- [x] `status <run dir>` prints, in order: pid state with exit code when exited, seconds since the log moved, thread id when present, review scope when present, resume fallback line when present, five-line tails of each non-empty log file
- [x] Exit 0 on a readable run directory; 64 on a missing argument, an unreadable directory, or any flag
- [x] The pid and mtime logic matches the old snippet, including the GNU-then-BSD `stat` fallback
- [x] The ticket 03 test calls the subcommand instead of copying the skill snippet; cases cover alive mid-run, exited with the fake's code, thread id printed, review scope printed, resume fallback printed, missing directory, and a flag
- [x] The skill's status section is the one-line invocation with the same guidance on when to run it, and the closing pre-approval paragraph no longer lists the status check among the commands that go through the permission flow
- [x] README status section describes the subcommand and its output; the exit code table lists the new 64 cause
- [x] `allowed-tools` is unchanged

## Comments

- 2026-09-20: implemented on branch `feat/codex-delegation-setup`. The wrapper gained `parse_status_args`, `status_newest_mtime` and `print_status`; `main` short-circuits to `print_status` before `check_preconditions`, since a status check needs no model, effort, stdin, git repository or `codex` on PATH. The ticket 03 test section now calls `bash "$WRAPPER" status <run dir>` and `t3_status_check` is gone, so the skill's prose and the test can no longer drift. `bash tests/run-tests.sh` reports PASS: 311 FAIL: 0 (baseline was 291). Hand-checked against a fake-produced run directory (pid line, seconds line, thread id, both tails, exit 0) and against a missing directory, a flag, no argument and two arguments (exit 64 with one line on stderr each). Every criterion is ticked.
- 2026-09-20: two things the wrapper does that the spec did not name, both in degenerate states only: a run directory with no `pid` file prints `pid not recorded` rather than the snippet's `pid : exited, exit code not recorded`, and with neither log file present the seconds line reports the age of the epoch, exactly as the snippet did. The `Status:` line is left at `ready-for-agent` for the orchestrator to resolve after it reviews the diff.
- 2026-09-20 (fix pass): the two degenerate states above are resolved. A readable directory with no `pid` file, or a `pid` file holding something that is not a pid, now exits 64 as "not a run directory" — story 43's wrong path is an error, so `pid not recorded` is gone — and `exit-code` is read before `kill -0`, so a finished run reports its recorded exit code even when the OS has since handed that pid to another process. With no log file yet the seconds line says `no progress log yet` rather than aging the epoch, and the delivery line reads `review scope delivered as: <value>`. Four cases added to the ticket 03 test section; `bash tests/run-tests.sh` reports PASS: 325 FAIL: 0.
