# 02: Implementation and research runs return a final message

**What to build:** `/codex-subagent --model M --effort E [--read-only] <task>` runs Codex in the background and Claude gets the result. The wrapper's `run` subcommand builds the `codex exec` invocation: sandbox workspace-write by default or read-only with the flag, model and effort passed through, web search live and sandbox network on via config overrides, working directory the git toplevel, JSON events on stdout, final message written to a file. It creates a run directory under the system temp dir holding the progress log, the raw event stream, the final message, the pid, the thread id, and the exit code, and prints that directory as its first line. It exits with Codex's own status. The skill text tells Claude how to build the five-section prompt with files referenced by path, when to delegate versus propose, to dispatch in the background and announce run id and log path, to read only the final message on success or exit code and log tail on failure, and to inspect the diff and reported verification after an implementation run.

**Blocked by:** 01 (Plugin skeleton that installs and fails closed)

**Status:** ready-for-agent

**Implementation:** delegate the build to an Agent-tool subagent with `model: "opus"`. The main session runs on Fable and only plans, reviews the subagent's diff, and checks the acceptance criteria.

- [ ] `run` with `--read-only` passes the read-only sandbox; without it, workspace-write
- [ ] `run` passes model, effort, live web search, and sandbox network access; never the approval flag, the search flag, or ephemeral mode
- [ ] Prompt reaches Codex on stdin byte-for-byte
- [ ] Run directory contains progress log, event stream, final message, pid, thread id, and exit code
- [ ] Wrapper's first stdout line is the run directory path
- [ ] Wrapper exit code equals Codex's exit code
- [ ] Skill text has the five-section prompt template, the no-commit rule, and the by-path rule
- [ ] Skill text says: delegate when asked, propose and wait when the repo routing table matches, background dispatch, announce run id and log path
- [ ] Skill text says: read only the final message on success; on failure report exit code and log tail and never claim success
- [ ] Skill text says: after an implementation run, inspect the diff and confirm the verification Codex reports
- [ ] Tests cover sandbox mapping, overrides, stdin passthrough, run directory contents, exit status
- [ ] One real read-only run in a disposable repo returns a final message and changes nothing
