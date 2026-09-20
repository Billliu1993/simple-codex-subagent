# codex-subagent

A Claude Code plugin that hands one scoped task to the locally installed OpenAI Codex CLI and
reads back its final message. Claude plans and verifies; Codex works.

The whole plugin is one skill and one shell wrapper. Every run goes through `codex exec` — the
supported non-interactive interface — and every run is sandboxed by Codex as `read-only` or
`workspace-write`. The wrapper offers no bypass and no full-access option, and has no code path
that could add one.

## What it needs

- The Codex CLI on `PATH`, signed in. Verified against codex-cli 0.155.1.
- `git`. Codex refuses to run outside a repository, and so does the wrapper.
- Bash and coreutils.

## What it does not need

No MCP server, no app-server protocol, no daemon, no background broker, no hooks, no Node or
Python runtime, no third-party package, and no persistent job store. Run state is a directory
under the system temp directory that the OS cleans up. The entire runtime is the wrapper script,
so re-auditing it after a Codex release takes minutes.

## Install

Install once at user scope; each repo's `CLAUDE.md` then decides when work goes to Codex.

```
/plugin marketplace add Billliu1993/simple-codex-subagent
/plugin install codex-subagent@codex-subagent
```

Update with `/plugin update`. The version in the plugin manifest is bumped on every change to the
plugin directory, so an update always has something to pick up.

## Invoke

```
/codex-subagent --model <m> --effort <e> [--read-only] [--resume <thread-id>] <task>
/codex-subagent review --model <m> --effort <e> [--uncommitted | --base <branch> | --commit <sha>] [focus]
```

`--model` and `--effort` are required on both forms; a call missing either one fails rather than
falling back to a Codex default. Effort values pass straight through to Codex, so the wrapper never
goes stale on that list. `--read-only` picks the read-only sandbox; without it the run gets
`workspace-write`, which can edit the repository and reach the network but nothing outside the
repository.

No file in the plugin names a model. Choosing a model is a `CLAUDE.md` edit, never a plugin
release, so the plugin never goes stale on a model that ships or retires.

## Suggested CLAUDE.md routing table

Paste this into a repo's `CLAUDE.md` and replace every `<model>` with the Codex model you want that
row to run on. The efforts are suggestions; edit them for the repo.

```markdown
## Codex routing

Delegate to the `codex-subagent` skill by the table below. The models and efforts here are this
repo's choices; the plugin has no defaults. How the delegation behaves — when to propose it, how a
run is watched, what is reported back — is the skill's business, not this table's.

| Work | Model | Effort | Invocation |
| --- | --- | --- | --- |
| Implementation — a scoped change against a plan already agreed | `<model>` | `high` | `/codex-subagent --model <model> --effort high <task>` |
| Research and exploration — how something works, where it lives, what the docs say | `<model>` | `medium` | `/codex-subagent --model <model> --effort medium --read-only <task>` |
| Review — findings on a diff | `<model>` | `high` | `/codex-subagent review --model <model> --effort high [--uncommitted \| --base <branch> \| --commit <sha>] [focus]` |
| Adversarial review — assume the change is broken and hunt for the break | `<model>` | `high` | the review row, asked for as an adversarial review so the skill prepends its adversarial block |

Runs go to the background. Tell me when the status check shows a run quiet for <N> minutes; the
decision to kill it is mine.
```

That threshold line is the one number worth keeping in `CLAUDE.md`, next to the work it governs.
The plugin holds no threshold and kills nothing, so a repo with legitimately long runs is never
interrupted by it.

## The run directory

The wrapper prints one line on stdout: the run directory. That path is the run id. It sits under
`${TMPDIR:-/tmp}/codex-subagent/<timestamp>-<pid>-<random>/`, created by `mktemp -d` so it is
private to the run, and holds:

| File | What it is |
| --- | --- |
| `final-message.md` | Codex's final message. On success this is the whole result. |
| `events.jsonl` | Codex's JSON event stream. The file that moves while Codex works. |
| `progress.log` | Codex's stderr: CLI-level errors, empty on a healthy run. |
| `pid` | The Codex process id. |
| `thread-id` | The Codex thread, once an event carries it. Feeds `--resume`. |
| `exit-code` | Codex's exit status, written on completion. |
| `prompt.md` | The prompt or focus as it arrived on stdin. |
| `argv` | The exact `codex` argv, one argument per line. |
| `review-scope` | The scope a review ran with, including one the wrapper chose. |
| `resume-fallback` | Present only when a resume was abandoned; one line of reason. |
| `resume-argv`, `resume-events.jsonl`, `resume-progress.log` | The abandoned resume attempt, kept beside the fresh run that replaced it. |

## Status check

One command over a run directory: whether the pid is alive, how long since the log last moved, and
its last lines. It reads and prints, and that is all — see the **Status check** section of
[`skills/codex-subagent/SKILL.md`](skills/codex-subagent/SKILL.md) for the snippet Claude runs.

## Resume

A follow-up continues the same Codex thread, so it costs one short prompt instead of another
exploration:

```
/codex-subagent --model <m> --effort <e> [--read-only] --resume <thread-id> <delta>
```

The thread id comes from an earlier run's `thread-id`. The sandbox is chosen per call and never
inherited from the thread: a thread first run read-only can write when it is resumed without
`--read-only`.

A resume passes `--strict-config`, so Codex rejects a config key it does not recognise instead of
ignoring it. That is deliberate: the resume form has no `--sandbox` flag, so the sandbox travels as
the `sandbox_mode` config key, and a silently ignored key would leave the follow-up running under
whatever sandbox the thread had. The cost is that a resume also fails when your own
`~/.codex/config.toml` holds a key this Codex version does not know; a fresh run still works, and
the fix is to correct the config.

When Codex cannot reopen the thread, the wrapper abandons it rather than retrying: it records the
reason in `resume-fallback`, says so on stderr, and runs the same prompt as a fresh run, exiting
with that run's status. A delta-only prompt may be thin without the thread's memory, so Claude
reports when a result came from a fallback.

## Review

Review goes through Codex's own `codex exec review`, so OpenAI maintains the diff scoping. Scope it
with `--uncommitted`, `--base <branch>`, or `--commit <sha>`. Given no scope flag the wrapper
reviews uncommitted changes when the tree is dirty and the diff against the default branch when it
is clean, recording its choice in `review-scope`. The default branch is `origin/HEAD` when that
exists, else `main`, else `master`.

The focus is free text and may be empty. An adversarial review is the same run with the skill's
canned block prepended: Codex assumes the change is broken and hunts for the inputs and orderings
that break it. A review edits nothing, and Claude presents the findings and stops.

## Exit codes

The wrapper exits with Codex's own status, so Claude's success and failure judgement is Codex's.
Codex's own statuses are normally 0 to 2 and pass through unchanged; 64 to 69 are the wrapper's
own, and it prints one line to stderr with each:

| Code | Reason |
| --- | --- |
| 64 | Unknown subcommand, unknown flag, a flag given where its value belongs, or conflicting review scope flags |
| 65 | Missing `--model` |
| 66 | Missing `--effort` |
| 67 | stdin is a terminal — the prompt must be piped |
| 68 | Not inside a git repository |
| 69 | `codex` not found on `PATH` |

## Manual smoke checklist

`tests/run-tests.sh` in this repository covers the wrapper against a fake `codex` and never calls
the model. Run this checklist by hand before each version bump, in a disposable git repo, to cover
what the tests cannot reach:

- [ ] Install from the marketplace succeeds.
- [ ] The short form `/codex-subagent` resolves.
- [ ] A `--read-only` run changes nothing (`git status --porcelain` stays empty).
- [ ] A workspace-write run makes a small edit and runs a test.
- [ ] A live web search works.
- [ ] A review of uncommitted changes returns findings and edits nothing.
- [ ] A resume continues a thread.
- [ ] A read-only thread resumed with `--read-only` cannot write; the same thread resumed without
      it can.
- [ ] A bad model name surfaces as a failure with a log tail.
