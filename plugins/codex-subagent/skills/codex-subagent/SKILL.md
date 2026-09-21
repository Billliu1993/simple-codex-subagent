---
name: codex-subagent
description: Hand one scoped task to the local OpenAI Codex CLI and report back its final message. Use when the user asks for Codex, or when this repo's CLAUDE.md routing table sends exploration, research, implementation, or review work to Codex.
argument-hint: "--model <m> --effort <e> [--read-only] [--resume <thread-id>] <task>  |  review --model <m> --effort <e> [--uncommitted | --base <branch> | --commit <sha>] [focus]"
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/codex-subagent.sh *)
---

Codex is the subagent; you plan and verify. Every run goes through the bundled wrapper, invoked as `bash ${CLAUDE_PLUGIN_ROOT}/scripts/codex-subagent.sh`, written exactly that way: the pre-approval matches that literal prefix, so quoting the path turns every dispatch into a permission prompt. Never call `codex` yourself.

Whether and when work goes to Codex, and how you behave around a delegation, is set by this repo's `## Codex delegation` section in CLAUDE.md, or in AGENTS.md when that is the repo's instructions file.

## Model and sandbox

`--model` and `--effort` are required on every call; take them from the user or from the routing table row. `--read-only` picks the read-only sandbox, so the run leaves the tree untouched; without it the run gets the workspace-write sandbox, which a run that edits needs. The routing table row says which sandbox a kind of work gets, and a brief that names a path for Codex to write to needs the flag off.

## Build the prompt

Write five sections in this order, keeping only the ones with something to say:

1. **Task and done-condition** — the work, and what finished looks like.
2. **What you know that Codex needs** — paths to read, decisions already taken, the approved plan.
3. **Constraints** — the mandatory rules below, plus anything specific to this task.
4. **Verification expected** — the tests, builds, or checks Codex runs before it reports.
5. **Return format** — ask for: what changed; files touched; commands run and their outcomes; blockers and unverified assumptions.

Refer to every file by path and let Codex read the current version itself. Inlined contents go stale and crowd out the task.

Every prompt carries these rules, in the constraints section:

> Leave the git state to me: make no commits, pushes, publishing, or deployment.
> Preserve unrelated changes already in the working tree.
> Stop and report if the task needs credentials or writes outside the repository.

## Run

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/codex-subagent.sh run --model <m> --effort <e> [--read-only]
```

Send the prompt on stdin, as a heredoc. Dispatch with the Bash tool's `run_in_background: true`, so you and the user keep working while Codex runs.

The wrapper's first line of stdout is the run directory. That path is the run id, and the run's progress log lives in it as two files: `events.jsonl`, the event stream that moves while Codex works, and `progress.log`, which holds CLI-level errors and is empty on a healthy run. Tell the user the run directory as soon as the run is dispatched, so they can watch it themselves.

## Status check

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/codex-subagent.sh status <run dir>
```

Run it when the user asks how a run is doing, and before you settle in to wait on a final message. It reports the pid alive or exited with its exit code, seconds since the progress log last moved, the thread id, a review's scope, an abandoned resume, and the tail of each log file, so one check answers the question on its own.

The check reads and prints, and that is all it does: it kills nothing and holds no threshold. How long a quiet run may stay quiet, and what to do when it does, is a decision for this repo's `## Codex delegation` section and the user.

## Resume

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/codex-subagent.sh run --model <m> --effort <e> [--read-only] --resume <thread-id>
```

Resume when the task is a follow-up on a run from this conversation and you have its thread id from `<run dir>/thread-id`. Codex still holds what it explored, so send only the delta — "now fix items 2 and 4" — and name any file the delta adds. The mandatory rules travel with the prompt, not with the thread, so repeat them in every resumed prompt too.

The sandbox is chosen per call and never inherited from the thread: pass `--read-only` when the follow-up only reads, and leave it off when it edits, judging the follow-up on its own. A read-only thread resumed without `--read-only` can write.

A resume that fails before Codex starts the thread is abandoned rather than retried: the wrapper prints `codex-subagent: resume of <id> failed before thread start; starting a fresh run` on stderr, records the reason in `<run dir>/resume-fallback`, and runs the same prompt as a fresh run, whose id `thread-id` then holds. A stale or missing thread is only one cause; a bad model name, an auth failure, or a transient CLI error looks the same from here. So when that file is there, tell the user the resume failed before the thread started and the result comes from a fresh run, and quote the one-line reason from `<run dir>/resume-fallback` plus the tail of `<run dir>/resume-events.jsonl` and `<run dir>/resume-progress.log` — the failed attempt's own files, which the wrapper keeps — so they can see which cause it was. A delta-only prompt may well have been too thin for a fresh run, which is the other half of what they need to know.

## Review

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/codex-subagent.sh review --model <m> --effort <e> [--uncommitted | --base <branch> | --commit <sha>]
```

Scope the diff with one of `--uncommitted`, `--base <branch>`, or `--commit <sha>`. Given no scope flag the wrapper reviews uncommitted changes on a dirty tree and the diff against the default branch on a clean one, and records what it chose in `<run dir>/review-scope`. That default is the usual case; reach for a flag when the user names a branch, a commit, or the working tree.

The focus is free text on stdin, and may be empty. It steers what Codex concentrates on, so send what the user is worried about, named by path and symbol.

Codex's review command takes either a scope flag or custom instructions, never both. So when there is a focus the wrapper drops the flag and states the scope in words as the first line of the instructions, ahead of your focus. That is the wrapper's job and it does it from the same scope it would have passed as a flag: send only the focus, and never a scope sentence of your own.

When the user asks for an adversarial review, prepend this block to the focus:

> Assume this change is broken and find how, around the focus below. Hunt for the inputs, orderings, and states that break it; one concrete failing case is worth more than any number of style notes. Report severity-first: the worst thing you can make happen, first.

The findings arrive in `<run dir>/final-message.md`. A review edits nothing: the run leaves the tree untouched.

## Report

The wrapper exits with Codex's own status, so that status decides which branch you take.

**Exit 0.** Read `<run dir>/final-message.md` and report from it. That one file is the whole result; leave `events.jsonl` and `progress.log` unread, so the progress stream stays out of your context.

**Any other exit.** Report the run as failed, with the exit code, `tail -n 40 <run dir>/progress.log` and `tail -n 20 <run dir>/events.jsonl`. The failure may sit in either: stderr holds CLI-level errors and is often empty, so the event stream is usually where the run stops. A failed run produced no result, so there is nothing to summarise as progress.

After an implementation run, check Codex's claims before the user hears them: read `git diff` and `git status`, confirm the change matches what the final message describes, and re-run the verification Codex reports as passing. Tell the user what you confirmed and what you could not.

Only the wrapper is pre-approved, by design, and the status check is the wrapper. Reading a run's files, `git diff`, `git status` and the verification commands all go through the normal permission flow, so the user sees what you run on their tree.
