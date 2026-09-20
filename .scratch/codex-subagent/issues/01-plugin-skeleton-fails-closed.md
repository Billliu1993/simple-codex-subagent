# 01: Plugin skeleton that installs and fails closed

**What to build:** The repo becomes a Claude Code marketplace with the `codex-subagent` plugin in its own subdirectory. Loading the plugin directory locally makes `/codex-subagent` resolve as the short form. The wrapper exists and refuses anything it does not understand: an unknown subcommand, a missing `--model`, a missing `--effort`, or a terminal on stdin, each with its own non-zero exit code and a one-line reason. The test harness exists: a plain Bash runner with a per-case setup and an assertion helper, and a fake `codex` executable placed first on PATH that records its argv and stdin and exits with a scripted code. Nothing calls the real Codex.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

**Implementation:** delegate the build to an Agent-tool subagent with `model: "opus"`. The main session runs on Fable and only plans, reviews the subagent's diff, and checks the acceptance criteria.

- [ ] Root marketplace manifest names the marketplace `codex-subagent` and points at the plugin subdirectory
- [ ] Plugin manifest names the plugin `codex-subagent` with a version
- [ ] One skill named `codex-subagent`; loading the plugin locally makes `/codex-subagent` resolve
- [ ] Skill frontmatter allows model invocation and pre-approves only the bundled wrapper
- [ ] Wrapper uses strict mode, takes `run` or `review` as its first argument, and rejects any other value
- [ ] Missing `--model` or `--effort` fails with a distinct exit code and reason on stderr
- [ ] A terminal on stdin fails with a distinct exit code
- [ ] Wrapper contains no bypass or full-access option and no code path that could add one
- [ ] Test runner and fake `codex` exist under the repo's tests directory, outside the plugin
- [ ] Four cases pass: unknown subcommand, missing model, missing effort, terminal stdin
- [ ] Executable bit committed on the wrapper; skill invokes it through an explicit shell anyway
