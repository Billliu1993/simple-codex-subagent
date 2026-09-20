---
status: accepted
---

# Delegate through `codex exec` and a shell wrapper, not app-server or a broker

An official Claude Code plugin for Codex exists. It runs a Node companion, a background broker, and the Codex app-server protocol to offer durable jobs, status, cancel, resume, and transcript transfer. Its maintenance cadence proved unreliable, its broker layer hung silently, and the Codex CLI ships several releases a week, so every protocol adapter is a moving target. We decided the subagent is one skill and one shell wrapper around `codex exec`, the supported non-interactive interface, with the prompt on stdin and the final message on stdout.

## Considered options

- **Official plugin or a community bridge.** Rejected: another maintainer between us and the CLI, persistent state, and in some bridges automatic escalation to an unsandboxed run.
- **Codex app-server or an MCP server.** Rejected: needed only for live steering or durable asynchronous jobs, neither of which the ordinary workflow uses.
- **`codex exec` plus a wrapper.** Chosen. The wrapper fixes what Codex may do (sandbox, network, search, required model and effort); Claude decides what to send.

## Consequences

- No durable job queue. A run lives as long as Claude Code's background Bash process. Status is a look at the run's files; cancel is killing a pid; there is no state that survives a restart.
- Resume is best effort through the thread id Codex emits, never through a broker.
- The wrapper's flags and config keys must track the CLI. A repo-only update check exists for that reason, and a change in the CLI is a change to the wrapper, not to a protocol layer.
- The plugin never runs Codex unsandboxed. If a task needs writes outside the repo, that is Claude Code's job, not the subagent's.
