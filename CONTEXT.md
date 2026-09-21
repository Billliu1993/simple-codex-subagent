# Simple Codex Subagent

A Claude Code plugin that hands one scoped task to the locally installed OpenAI Codex CLI and returns the result to Claude. Claude plans and verifies; Codex works.

## Language

**Subagent**:
The Codex process Claude delegates to. It is a skill invocation, not a Claude custom agent.
_Avoid_: Worker, rescue, companion

**Run**:
One `codex exec` invocation from start to exit, with its own log and final message.
_Avoid_: Job, task, session

**Thread**:
The Codex-side conversation a run belongs to, identified by a UUID. A later run may resume it.
_Avoid_: Session, conversation

**Final message**:
The last assistant message Codex emits for a run. The only run output Claude reads on success.
_Avoid_: Result, report, output

**Progress log**:
A run's stderr and its JSON event stream, kept as two files in the run directory so Claude can watch for silence. The event stream is the one that moves; stderr carries only CLI-level errors.
_Avoid_: Job log, trace

**Wrapper**:
The shell script that fixes how Codex is allowed to run. Claude decides what to send; the wrapper decides how it runs.
_Avoid_: Runner, bridge, companion

**Sandbox**:
Codex's own write boundary for a run: read-only or workspace-write. The plugin never runs Codex unsandboxed.
_Avoid_: Permission mode, mode

**Review**:
A run that sends a diff scope to Codex's built-in review command instead of a prompt. It reports findings and edits nothing.
_Avoid_: Audit, code review run

**Focus**:
Free-text custom instructions attached to a review, telling Codex what to concentrate on.
_Avoid_: Instructions, prompt, scope

**Adversarial review**:
A review carrying the skill's canned instruction block that assumes the change is broken and hunts for ways to break it around the focus. A prompt convention, not a Codex feature.
_Avoid_: Red-team review, hostile review

**Status check**:
The one-command look at a run: whether the pid is alive, how long since the progress log last moved, and its last lines. It never kills anything.
_Avoid_: Poll, heartbeat, watchdog

**Codex delegation**:
The `## Codex delegation` section a repo's `CLAUDE.md` carries, written by the setup skill and edited by hand after: the routing table, whether to pause for a go-ahead, whether to stop after a review, how long a quiet run may stay quiet, how many runs go at once, and what Codex cannot run here. The delegating skill carries none of this; it only says how a delegation is done.
_Avoid_: Codex policy, skill config, defaults, routing rules

**Setup skill**:
The user-invoked skill that interviews for a repo's Codex delegation and writes the section into `CLAUDE.md`, updating an existing one in place and keeping hand edits.
_Avoid_: Installer, wizard, init

**Routing table**:
The table inside the Codex delegation section that maps a kind of work to the model and effort it runs with. It names routes, never behaviour.
_Avoid_: Model table, delegation table
