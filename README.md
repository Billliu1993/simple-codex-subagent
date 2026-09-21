# simple-codex-subagent

A Claude Code plugin that hands one scoped task to the locally installed OpenAI Codex CLI and reads back its final message: two skills, one shell wrapper, `codex exec` only, always sandboxed.

Read [`plugins/codex-subagent/README.md`](plugins/codex-subagent/README.md) for what it does, the invocation forms, and the `## Codex delegation` section that `/codex-subagent:setup` writes into a repo's `CLAUDE.md`.

Install once at user scope:

```
/plugin marketplace add Billliu1993/simple-codex-subagent
/plugin install codex-subagent@codex-subagent
```

Layout: `plugins/codex-subagent/` is the whole shipped plugin; `tests/` holds the Bash test suite and its fake `codex`; `snapshots/` holds Codex CLI help output per version; and `.claude/skills/check-codex-updates/` is a maintainer-only skill that checks a new Codex release against those snapshots. Only the plugin subdirectory is installed.

## Versioning and releases

The plugin's version is the only release marker; there are no git tags. Two files carry it and must stay identical: `plugins/codex-subagent/.claude-plugin/plugin.json` (`version`) and the plugin entry in `.claude-plugin/marketplace.json`. On `/plugin update` Claude Code reads the plugin manifest's version first and the marketplace entry's only as a fallback; a stale manifest wins silently, so a bump that touches only the marketplace file ships nothing.

Release steps, for any change under `plugins/codex-subagent/`:

1. `bash tests/run-tests.sh`, then the manual smoke checklist in the plugin README.
2. Bump both manifests to the same semver: patch for a fix or doc change, minor for a new flag or behaviour, major for a change to the invocation forms.
3. Commit the bump on its own (`chore: bump the plugin to x.y.z`) and merge to `main`. Installs and updates read `main`, so nothing ships until the merge lands.

After a Codex CLI release, run `/check-codex-updates` first; a wrapper change it forces follows the same steps.
