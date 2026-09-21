# codex-subagent

A Claude Code plugin that hands one scoped task to the locally installed OpenAI Codex CLI and reads back its final message. Claude plans and verifies; Codex works.

The whole plugin is two skills and one shell wrapper: a delegating skill that hands the work over, a setup skill that writes a repo's delegation rules, and the wrapper that runs Codex. Every run goes through `codex exec` — the supported non-interactive interface — and every run is sandboxed by Codex as `read-only` or `workspace-write`. The wrapper offers no bypass and no full-access option, and has no code path that could add one.

## What it needs

- The Codex CLI on `PATH`, signed in. Verified against codex-cli 0.155.1.
- `git`. Codex refuses to run outside a repository, and so does the wrapper.
- Bash and coreutils.

## What it does not need

No MCP server, no app-server protocol, no daemon, no background broker, no hooks, no Node or Python runtime, no third-party package, and no persistent job store. Run state is a directory under the system temp directory that the OS cleans up. The entire runtime is the wrapper script, so re-auditing it after a Codex release takes minutes.

## Install

Install once at user scope; each repo's `CLAUDE.md` then decides when work goes to Codex, and `/codex-subagent:setup-codex-delegation` writes that part for you, once per repo.

```
/plugin marketplace add Billliu1993/simple-codex-subagent
/plugin install codex-subagent@codex-subagent
```

Update with `/plugin update`. The version in the plugin manifest is bumped on every change to the plugin directory, so an update always has something to pick up.

## Invoke

```
/codex-subagent:setup-codex-delegation
/codex-subagent --model <m> --effort <e> [--read-only] [--resume <thread-id>] <task>
/codex-subagent review --model <m> --effort <e> [--uncommitted | --base <branch> | --commit <sha>] [focus]
```

`/codex-subagent:setup-codex-delegation` is the once-per-repo one, and it runs only when you ask for it by name. The other two are the delegation itself.

`--model` and `--effort` are required on both delegation forms; a call missing either one fails rather than falling back to a Codex default. Effort values pass straight through to Codex, so the wrapper never goes stale on that list. `--read-only` picks the read-only sandbox; without it the run gets `workspace-write`, which can edit the repository and reach the network but nothing outside the repository.

Nothing the plugin runs names a model: no wrapper default, no skill default. Which model does which work is a `CLAUDE.md` edit — the example section below shows the models one repo chose — never a plugin release, so the plugin never goes stale on a model that ships or retires.

## The repo's Codex delegation section

Run `/codex-subagent:setup-codex-delegation` once in a repo. It interviews you and writes a `## Codex delegation` section into that repo's `CLAUDE.md` — or `AGENTS.md`, or whichever of the two you ask it to create when the repo has neither — and writes nothing anywhere else. The questions come one at a time, each led by a recommendation you can accept in a word: the model for each kind of work, the effort for each kind of work, whether Claude delegates straight away or proposes and waits for your go-ahead when you did not ask for Codex, how long a run may go quiet before Claude tells you, what Codex cannot run in this environment, and how many runs may go at once. You see the whole section, and can edit it and add rows, before any of it is written.

Accepting every recommendation in a repo with no instructions file writes this:

```markdown
## Codex delegation

Delegate through the `codex-subagent` skill by the table below.

| Work | Model | Effort | Invocation |
| --- | --- | --- | --- |
| Implementation — including spikes and prototypes | `gpt-5.6-sol` | `high` | `/codex-subagent --model gpt-5.6-sol --effort high <task>` |
| Research and exploration — any source | `gpt-5.6-sol` | `medium` | `/codex-subagent --model gpt-5.6-sol --effort medium --read-only <task>` |
| Review — findings on a diff | `gpt-5.6-sol` | `high` | `/codex-subagent review --model gpt-5.6-sol --effort high [--uncommitted \| --base <branch> \| --commit <sha>] [focus]` |
| Adversarial review | `gpt-5.6-sol` | `high` | the review row, asked for as an adversarial review so the skill prepends its adversarial block |

One question per research run, with at most a few things to answer. Split a broad topic into focused runs and dispatch them in waves under the concurrency cap. A research run is read-only: drop `--read-only` only when the brief names a repo path for Codex to write to, and then say which files to leave alone.

Runs go to the background.
Tell me when the status check shows a run quiet for 3 minutes; the decision to kill it is mine.
Keep at most 2 runs going at once.
After a review, present the findings and stop: I pick which ones a later run fixes.
```

The `codex-subagent` skill carries the mechanics of a delegation — the prompt, the sandbox, the run, resume, review, the status check, the verification of Codex's claims after an implementation run — and the section carries the behaviour around it: the pause rule, the stop after a review, the quiet-run threshold, the concurrency cap, and what Codex cannot run here. One place per repo to read and to edit, and no rule the plugin and the repo can state differently. Why the line is drawn there: `docs/adr/0002-skill-carries-mechanics-repo-carries-behaviour.md`. The threshold and the cap are the two numbers worth keeping next to the work they govern, and they are the repo's because the plugin holds neither and kills nothing, so a repo with legitimately long runs is never interrupted by them.

The section is plain markdown, so edit it by hand: reword a row, add one, write down the guidance the repo has learned. A re-run of the setup skill starts from the values already in the section and rewrites only the lines it owns — the delegating sentence, the rows it wrote, the threshold line, the cap line, the stop-after-review line, and the environment line. Everything else stays byte for byte, in place.

## The run directory

The wrapper prints one line on stdout: the run directory. That path is the run id. It sits under `${TMPDIR:-/tmp}/codex-subagent/<timestamp>-<pid>-<random>/`, created by `mktemp -d` so it is private to the run, and holds:

| File | What it is |
| --- | --- |
| `final-message.md` | Codex's final message. On success this is the whole result. |
| `events.jsonl` | Codex's JSON event stream. The file that moves while Codex works. |
| `progress.log` | Codex's stderr: CLI-level errors, empty on a healthy run. |
| `pid` | The Codex process id. |
| `thread-id` | The Codex thread, once an event carries it. Feeds `--resume`. |
| `exit-code` | Codex's exit status, written on completion. |
| `prompt.md` | What Codex read on stdin: the prompt as it arrived, or, for a review with a focus, the scope line and the focus. |
| `focus.md` | Present only on a review with a focus: the focus as it arrived on stdin. |
| `argv` | The exact `codex` argv, one argument per line. |
| `review-scope` | The scope a review ran with, including one the wrapper chose, and how it was delivered. |
| `resume-fallback` | Present only when a resume was abandoned; one line of reason. |
| `resume-argv`, `resume-events.jsonl`, `resume-progress.log` | The abandoned resume attempt, kept beside the fresh run that replaced it. |

## Status check

A third subcommand reads one run directory and says how the run is doing:

```
codex-subagent.sh status <run dir>
```

It prints, in order: whether the pid is alive, or has exited and with which exit code; how many seconds since the newer of `events.jsonl` and `progress.log` last changed; the thread id; a review's scope and how it was delivered; one line quoting the reason a resume was abandoned; then the last five lines of each of those two files that has any. Every line but the first two comes from a file the run only sometimes has, and appears only when that file is there. A finished run reports the exit code it recorded even when its pid has since been reused by another process, since `exit-code` is read before the pid is probed; until a log file exists there is no silence to measure, and the seconds line says so instead of giving a number.

The check refuses a path that is not a run directory — one it cannot read, one holding neither a `pid` file nor a `prompt.md`, or one whose `pid` file holds no pid — with exit 64 and a line on stderr, because that is a wrong path rather than a run with nothing to report. A run directory checked before Codex has started, holding the prompt but no pid yet, is reported as not started yet. Otherwise it reads and prints, and that is all it does: it kills nothing, holds no threshold, and starts no run, so it takes neither `--model` nor `--effort` and needs no prompt on stdin, and it exits 0. Being the wrapper, it falls inside the skill's pre-approval, so a status check costs no permission prompt.

## Resume

A follow-up continues the same Codex thread, so it costs one short prompt instead of another exploration:

```
/codex-subagent --model <m> --effort <e> [--read-only] --resume <thread-id> <delta>
```

The thread id comes from an earlier run's `thread-id`. The sandbox is chosen per call and never inherited from the thread: a thread first run read-only can write when it is resumed without `--read-only`.

A resume passes `--strict-config`, so Codex rejects a config key it does not recognise instead of ignoring it. That is deliberate: the resume form has no `--sandbox` flag, so the sandbox travels as the `sandbox_mode` config key, and a silently ignored key would leave the follow-up running under whatever sandbox the thread had. The cost is that a resume also fails when your own `~/.codex/config.toml` holds a key this Codex version does not know; a fresh run still works, and the fix is to correct the config.

When a resume exits non-zero before Codex starts the thread, the wrapper abandons it rather than retrying: it records the reason in `resume-fallback`, says so on stderr, keeps the failed attempt as `resume-argv`, `resume-events.jsonl` and `resume-progress.log`, and runs the same prompt as a fresh run, exiting with that run's status. The trigger is the failure, not a diagnosis of it — a stale thread, a bad model name, an auth failure and a transient CLI error all land here — so Claude quotes the recorded reason rather than telling the user the thread was lost. A delta-only prompt may be thin without the thread's memory, so Claude reports when a result came from a fallback.

## Review

Review goes through Codex's own `codex exec review`, so OpenAI maintains the diff scoping. Scope it with `--uncommitted`, `--base <branch>`, or `--commit <sha>`. Given no scope flag the wrapper reviews uncommitted changes when the tree is dirty and the diff against the default branch when it is clean, recording its choice in `review-scope`. The default branch is `origin/HEAD` when that exists, else `main`, else `master`.

The focus is free text and may be empty. `codex exec review` accepts either a scope flag or custom instructions and rejects the two together, so a review with a focus carries no scope flag: the wrapper states the scope in words as the first line of the instructions, a blank line, then the focus unchanged, and `review-scope` gains a `delivered-as: flag` or `delivered-as: instructions` line saying which route it took (the raw focus is kept in `focus.md`). This is the one place the wrapper says the diff scope in words rather than leaving it to Codex's flag, so the sentences live next to the flags in the wrapper and are asserted in the tests.

`codex exec review` has no `--sandbox` flag either, so a review pins `sandbox_mode="read-only"` the same way a resume pins its sandbox, `--strict-config` included: a review reads, and it reads under the wrapper's sandbox rather than whatever your own Codex config would have given it.

An adversarial review is the same run with the skill's canned block prepended: Codex assumes the change is broken and hunts for the inputs and orderings that break it. A review edits nothing: the run leaves the tree untouched. Whether Claude then presents the findings and stops, or carries on and fixes them, is the repo's `## Codex delegation` section's call, not the skill's.

## Exit codes

The wrapper exits with Codex's own status, so Claude's success and failure judgement is Codex's. Codex's own statuses are normally 0 to 2 and pass through unchanged; 64 to 69 are the wrapper's own, and it prints one line to stderr with each:

| Code | Reason |
| --- | --- |
| 64 | Unknown subcommand, unknown flag, a flag given where its value belongs, conflicting review scope flags, or a `status` whose argument is missing, is a flag, is one of several, or is not a readable run directory |
| 65 | Missing `--model` |
| 66 | Missing `--effort` |
| 67 | stdin is a terminal — the prompt must be piped |
| 68 | Not inside a git repository |
| 69 | `codex` not found on `PATH` |

## Manual smoke checklist

`tests/run-tests.sh` in this repository covers the wrapper against a fake `codex` and never calls the model. Run this checklist by hand before each version bump, in a disposable git repo, to cover what the tests cannot reach:

- [ ] Install from the marketplace succeeds.
- [ ] The short form `/codex-subagent` resolves.
- [ ] `/codex-subagent:setup-codex-delegation` in a repo with no `CLAUDE.md` and no `AGENTS.md` asks which to create, and writes the section into that one file and nothing else.
- [ ] `/codex-subagent:setup-codex-delegation` re-run on a repo whose section carries hand edits — a reworded row, an added row, a paragraph of its own guidance, an edited threshold — changes only the lines it owns and leaves every hand edit where it was.
- [ ] One delegation driven by a row of a generated section returns a final message.
- [ ] A `--read-only` run changes nothing (`git status --porcelain` stays empty).
- [ ] A workspace-write run makes a small edit and runs a test.
- [ ] A live web search works.
- [ ] A review of uncommitted changes returns findings and edits nothing.
- [ ] A resume continues a thread.
- [ ] A read-only thread resumed with `--read-only` cannot write; the same thread resumed without it can.
- [ ] A bad model name surfaces as a failure with a log tail.
