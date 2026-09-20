---
name: codex-subagent
description: Hand one scoped task to the local OpenAI Codex CLI and report back its final message. Use when the user asks for Codex, or when this repo's CLAUDE.md routing table sends exploration, research, implementation, or review work to Codex.
argument-hint: "--model <m> --effort <e> [--read-only] [--resume <thread-id>] <task>  |  review --model <m> --effort <e> [--uncommitted | --base <branch> | --commit <sha>] [focus]"
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/codex-subagent.sh *)
---

Codex is the subagent; you plan and verify. Every run goes through the bundled wrapper, invoked as
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/codex-subagent.sh"`. Never call `codex` yourself.

## When to delegate

- **The user asks for Codex** — delegate straight away.
- **This repo's CLAUDE.md routing table sends this kind of work to Codex, and the user did not ask**
  — propose the delegation, name the model and effort the table gives for that row, and wait for a
  go-ahead before dispatching.

`--model` and `--effort` are required on every call; take them from the user or from the routing
table row. Pass `--read-only` for exploration and research, so the run leaves the tree untouched.
Leave it off for implementation, which needs the workspace-write sandbox.

## Build the prompt

Write five sections in this order, keeping only the ones with something to say:

1. **Task and done-condition** — the work, and what finished looks like.
2. **What you know that Codex needs** — paths to read, decisions already taken, the approved plan.
3. **Constraints** — the mandatory rules below, plus anything specific to this task.
4. **Verification expected** — the tests, builds, or checks Codex runs before it reports.
5. **Return format** — ask for: what changed; files touched; commands run and their outcomes;
   blockers and unverified assumptions.

Refer to every file by path and let Codex read the current version itself. Inlined contents go
stale and crowd out the task.

Every prompt carries these rules, in the constraints section:

> Leave the git state to me: make no commits, pushes, publishing, or deployment.
> Preserve unrelated changes already in the working tree.
> Stop and report if the task needs credentials or writes outside the repository.

## Run

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/codex-subagent.sh" run --model <m> --effort <e> [--read-only]
```

Send the prompt on stdin, as a heredoc. Dispatch with the Bash tool's `run_in_background: true`, so
you and the user keep working while Codex runs.

The wrapper's first line of stdout is the run directory. That path is the run id, and the progress
log is `<run dir>/progress.log`. Tell the user both as soon as the run is dispatched, so they can
watch it themselves.

## Status check

How to tell whether a quiet run is alive, how long its progress log has been still, and what its last
lines say.

## Resume

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/codex-subagent.sh" run --model <m> --effort <e> [--read-only] --resume <thread-id>
```

Resume when the task is a follow-up on a run from this conversation and you have its thread id from
`<run dir>/thread-id`. Codex still holds what it explored, so send only the delta — "now fix items 2
and 4" — and name any file the delta adds. The mandatory rules travel with the prompt, not with the
thread, so repeat them in every resumed prompt too.

The sandbox is chosen per call and never inherited from the thread: pass `--read-only` when the
follow-up only reads, and leave it off when it edits, judging the follow-up on its own. A read-only
thread resumed without `--read-only` can write.

A thread Codex cannot reopen is abandoned rather than retried: the wrapper prints
`codex-subagent: resume of <id> failed before thread start; starting a fresh run` on stderr, records
the reason in `<run dir>/resume-fallback`, and runs the same prompt as a fresh run, whose id
`thread-id` then holds. When that file is there, tell the user the thread was lost and the result
comes from a run that started without it — a delta-only prompt may well have been too thin for one.

## Review

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/codex-subagent.sh" review --model <m> --effort <e> [--uncommitted | --base <branch> | --commit <sha>]
```

The focus goes on stdin and may be empty. A review edits nothing: present the findings and stop.

## Report

The wrapper exits with Codex's own status, so that status decides which branch you take.

**Exit 0.** Read `<run dir>/final-message.md` and report from it. That one file is the whole
result; leave `events.jsonl` and `progress.log` unread, so the progress stream stays out of your
context.

**Any other exit.** Report the run as failed, with the exit code and `tail -n 40
<run dir>/progress.log`. A failed run produced no result, so there is nothing to summarise as
progress.

After an implementation run, check Codex's claims before the user hears them: read `git diff` and
`git status`, confirm the change matches what the final message describes, and re-run the
verification Codex reports as passing. Tell the user what you confirmed and what you could not.
