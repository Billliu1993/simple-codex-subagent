---
name: codex-subagent
description: Hand one scoped task to the local OpenAI Codex CLI and report back its final message. Use when the user asks for Codex, or when this repo's CLAUDE.md routing table sends exploration, research, implementation, or review work to Codex.
argument-hint: "--model <m> --effort <e> [--read-only] [--resume <thread-id>] <task>  |  review --model <m> --effort <e> [--uncommitted | --base <branch> | --commit <sha>] [focus]"
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/codex-subagent.sh *)
---

Codex is the subagent; you plan and verify. Every run goes through the bundled wrapper, invoked as
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/codex-subagent.sh"`. Never call `codex` yourself.

## When to delegate

Delegate when the user asks for Codex. When the repo's CLAUDE.md routing table matches but the user
did not ask, propose the delegation and wait for a go-ahead.

## Build the prompt

Five sections, each omitted when empty: task and done-condition; what you know that Codex needs;
constraints; verification expected; return format. Name files by path; never paste their contents.

## Run

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/codex-subagent.sh" run --model <m> --effort <e> [--read-only]
```

The prompt goes on stdin. Run it with the Bash tool's `run_in_background: true`. The wrapper's first
line of stdout is the run directory; report it to the user with the run's log path.

## Status check

How to tell whether a quiet run is alive, how long its progress log has been still, and what its last
lines say.

## Resume

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/codex-subagent.sh" run --model <m> --effort <e> --resume <thread-id>
```

Continues the thread of an earlier run so a follow-up costs one short prompt.

## Review

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/codex-subagent.sh" review --model <m> --effort <e> [--uncommitted | --base <branch> | --commit <sha>]
```

The focus goes on stdin and may be empty. A review edits nothing.

## Report

On success, read the final message only. On failure, report the exit code and the tail of the
progress log. After an implementation run, inspect the diff and confirm the verification Codex
reports. After a review, present the findings and stop.
