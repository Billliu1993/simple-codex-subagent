# 01: Plugin skeleton that installs and fails closed

**What to build:** The repo becomes a Claude Code marketplace with the `codex-subagent` plugin in its own subdirectory. Loading the plugin directory locally makes `/codex-subagent` resolve as the short form. The wrapper exists and refuses anything it does not understand: an unknown subcommand, a missing `--model`, a missing `--effort`, or a terminal on stdin, each with its own non-zero exit code and a one-line reason. The test harness exists: a plain Bash runner with a per-case setup and an assertion helper, and a fake `codex` executable placed first on PATH that records its argv and stdin and exits with a scripted code. Nothing calls the real Codex.

**Blocked by:** None (can start immediately)

**Status:** resolved

**Implementation:** delegate the build to an Agent-tool subagent with `model: "opus"`. The main session runs on Fable and only plans, reviews the subagent's diff, and checks the acceptance criteria.

- [x] Root marketplace manifest names the marketplace `codex-subagent` and points at the plugin subdirectory
- [x] Plugin manifest names the plugin `codex-subagent` with a version
- [x] One skill named `codex-subagent`; loading the plugin locally makes `/codex-subagent` resolve
- [x] Skill frontmatter allows model invocation and pre-approves only the bundled wrapper
- [x] Wrapper uses strict mode, takes `run` or `review` as its first argument, and rejects any other value
- [x] Missing `--model` or `--effort` fails with a distinct exit code and reason on stderr
- [x] A terminal on stdin fails with a distinct exit code
- [x] Wrapper contains no bypass or full-access option and no code path that could add one
- [x] Test runner and fake `codex` exist under the repo's tests directory, outside the plugin
- [x] Four cases pass: unknown subcommand, missing model, missing effort, terminal stdin
- [x] Executable bit committed on the wrapper; skill invokes it through an explicit shell anyway

## Comments

- 2026-09-19: implemented on branch `feat/codex-subagent-plugin`, https://github.com/Billliu1993/simple-codex-subagent/pull/1. Checked items are covered by `tests/run-tests.sh` (fake codex) or by one real run during the build; unchecked items are left to the manual smoke checklist in `plugins/codex-subagent/README.md`.
