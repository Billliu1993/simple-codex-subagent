---
name: check-codex-updates
description: Maintainer check that the codex-subagent wrapper still matches the installed Codex CLI.
disable-model-invocation: true
allowed-tools: Bash(bash .claude/skills/check-codex-updates/check.sh*)
---

Codex ships several releases a week. This skill is how the maintainer re-verifies, in one command, that `plugins/codex-subagent/scripts/codex-subagent.sh` still matches the CLI it drives.

Neither the script nor you edit the wrapper. The maintainer decides what changes; the report only says what moved.

## Run it

```
bash .claude/skills/check-codex-updates/check.sh
```

From the repo root. It takes no model call: every Codex invocation is `--help`.

Exit `0` means no drift and the installed version is the latest. Exit `1` means there is something to act on. Exit `2` is the script's own failure, and its one-line reason goes to stderr.

## Read the report

Four sections, in order:

- **Versions** — installed versus latest published (npm, falling back to the GitHub releases API). A gap here means upgrade Codex first: drift measured against a stale binary tells you nothing about the release you are about to run.
- **Help drift** — `diff -u` of the live `codex exec`, `codex exec resume`, and `codex exec review` help against the newest `snapshots/codex-*/`. "no drift" per command is the clean result.
- **Release notes** — non-prerelease releases published after the snapshot version, newest first.
- **Wrapper lines** — every long flag and config key appearing in the diff hunks, each with the `file:line` hits in the wrapper. This is the list of places a CLI change actually reaches the wrapper.

## Act on it

1. Read the diff and the release notes together: the diff says what moved, the notes say why.
2. Work through the wrapper lines the report named and decide, per line, whether the wrapper must change. Reasons it must: a flag the wrapper passes was renamed, removed, or changed meaning; a config key it sets moved; a subcommand gained a safer way to do what the wrapper does by hand. Reasons it must not: a new flag the wrapper has no use for, or a bypass or full-access option, which the wrapper never gains a path to.
3. Edit the wrapper by hand, and run `bash tests/run-tests.sh`.
4. Re-take the snapshots for the version you verified against:

   ```
   bash .claude/skills/check-codex-updates/check.sh --refresh
   ```

   This writes `snapshots/codex-<installed version>/{exec,exec-resume,exec-review}.txt` and `VERSION`, and nothing else.
5. Update the "Verified against codex-cli x.y.z" line under "What it needs" in `plugins/codex-subagent/README.md` to the same version the snapshots now carry. That line is the only place a plugin user can see which CLI the wrapper was checked against; the snapshots are not installed.
6. Bump `version` in both `plugins/codex-subagent/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, keeping them identical.

Refreshing the snapshots without step 3 hides the drift instead of resolving it: the next run reports clean against a wrapper nobody checked.
