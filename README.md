# simple-codex-subagent

A Claude Code plugin that hands one scoped task to the locally installed OpenAI Codex CLI and
reads back its final message: one skill, one shell wrapper, `codex exec` only, always sandboxed.

Read [`plugins/codex-subagent/README.md`](plugins/codex-subagent/README.md) for what it does, the
invocation forms, and a routing table to paste into a repo's `CLAUDE.md`.

Install once at user scope:

```
/plugin marketplace add Billliu1993/simple-codex-subagent
/plugin install codex-subagent@codex-subagent
```

Layout: `plugins/codex-subagent/` is the whole shipped plugin; `tests/` holds the Bash test suite
and its fake `codex`; `snapshots/` holds Codex CLI help output per version; and
`.claude/skills/check-codex-updates/` is a maintainer-only skill that checks a new Codex release
against those snapshots. Only the plugin subdirectory is installed.
