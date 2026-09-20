# Spec: codex-subagent plugin

Status: ready-for-agent
Source: grilling session on 2026-09-14, superseding the brief in `minimal-claude-codex-delegation-skill.md` where they differ.
Vocabulary: `CONTEXT.md`. Governing decision: ADR-0001.

## Problem Statement

I use the OpenAI Codex CLI as a second coding agent from inside Claude Code for four kinds of work: codebase exploration, research, implementation, and review. The official Claude Code plugin for Codex is the only supported bridge, and it has become a liability: it carries a Node companion, a background broker, hooks, and the evolving app-server protocol; its releases lag the CLI; and its broker hangs silently, which forced me to write my own hang-watching rules into every repo's CLAUDE.md. Community bridges add another maintainer and sometimes escalate to unsandboxed execution on their own. The Codex CLI itself ships several releases a week, so whatever I depend on must be small enough to re-check and fix in minutes.

## Solution

A Claude Code plugin named `codex-subagent`, installable into any of my repos from this repo's marketplace in two commands. It contains one skill and one shell wrapper. The skill is the subagent: Claude builds a prompt from the conversation, hands it to the wrapper, and reads back the final message. The wrapper fixes how Codex is allowed to run, always through the supported `codex exec` interface, always sandboxed, always with the model and effort I chose for that call. Runs happen in the background so Claude keeps working; a status check exists for when I want to look. Reviews go through Codex's built-in review command. Follow-ups resume the same thread when they can and start fresh when they can't.

Alongside the plugin, this repo keeps a maintainer-only skill that checks the installed CLI against stored snapshots and the release notes, so I can re-verify the wrapper after any Codex release with one command.

## User Stories

1. As a Claude Code user, I want to install the subagent into any repo with `/plugin marketplace add` and `/plugin install`, so that I never copy files by hand.
2. As a Claude Code user, I want to install once at user scope, so that every repo has the subagent and each repo's CLAUDE.md decides when to use it.
3. As a Claude Code user, I want `/plugin update` to pick up new plugin versions, so that fixes reach my repos without reinstalling.
4. As a Claude Code user, I want to invoke the subagent as `/codex-subagent <task>`, so that the short form works without a namespace prefix.
5. As a Claude Code user, I want Claude to invoke the subagent on its own when my repo's CLAUDE.md routing table says a task belongs to Codex, so that I don't type the slash form every time.
6. As a Claude Code user, I want Claude to propose delegation and wait for a go-ahead when the routing table matches but I did not ask, so that Codex never runs on a guess.
7. As a Claude Code user, I want to pass `--model` and `--effort` on every call, so that I control which model works at which effort per kind of task.
8. As a Claude Code user, I want the wrapper to fail when model or effort is missing, so that a run never silently falls back to Codex's own default.
9. As a Claude Code user, I want the plugin to name no model anywhere in its files, so that a model change is a CLAUDE.md edit and never a plugin release.
10. As a Claude Code user, I want implementation runs to use the workspace-write sandbox, so that Codex can edit the repo and install dependencies locally but nothing outside it.
11. As a Claude Code user, I want `--read-only` for exploration and research runs, so that a research task cannot leave edits behind.
12. As a Claude Code user, I want no full-access path in the plugin at all, so that a sandbox problem surfaces to me instead of being bypassed; if writes outside the repo are truly needed, Claude Code does them.
13. As a Claude Code user, I want live web search available in every run, so that Codex can check current documentation during any kind of work.
14. As a Claude Code user, I want network access inside the sandbox, so that package installs and public repository reads work in implementation runs.
15. As a Claude Code user, I want the prompt delivered on stdin, so that no shell quoting of a long prompt can corrupt or inject into the command.
16. As a Claude Code user, I want the prompt to reference files by path and never inline their contents, so that Codex reads current files itself and the prompt stays short.
17. As a Claude Code user, I want the prompt to carry the task and done-condition, what Claude knows that Codex needs, constraints, verification expected, and a return format, filling only the sections that apply, so that Codex gets a complete contract without boilerplate.
18. As a Claude Code user, I want every prompt to forbid commits, pushes, publishing, and deployment, so that Codex leaves the git state to me.
19. As a Claude Code user, I want runs to execute in the background, so that Claude and I keep working while Codex runs.
20. As a Claude Code user, I want Claude to be re-invoked when a run exits, so that success and failure both surface without polling.
21. As a Claude Code user, I want Claude to read only the final message on success, so that Codex's progress stream never floods Claude's context.
22. As a Claude Code user, I want a failed run to surface its exit code and the tail of its progress log, so that I see what went wrong and Claude never reports a failure as success.
23. As a Claude Code user, I want Claude to tell me the run id and the log path right after dispatch, so that I can watch a run myself.
24. As a Claude Code user, I want a status check that shows whether the run is alive, how long since its log last moved, and its last lines, so that I can judge a quiet run in one command.
25. As a Claude Code user, I want no fixed hang thresholds and no automatic kill in the plugin, so that repos with legitimately long runs are not interrupted; any threshold lives in that repo's CLAUDE.md.
26. As a Claude Code user, I want each run's files kept under the system temp directory, so that the plugin owns no persistent state and the OS cleans up.
27. As a Claude Code user, I want each run to record its thread id, so that a follow-up can continue with Codex's memory of the codebase.
28. As a Claude Code user, I want `--resume <thread-id>` on the run form, so that "now fix items 2 and 4" costs one short prompt instead of a re-exploration.
29. As a Claude Code user, I want a resume that fails to fall back to a fresh run and say so, so that a stale or missing thread never blocks the task.
30. As a Claude Code user, I want `/codex-subagent review` to use Codex's built-in review command, so that diff scoping is maintained by OpenAI and not by me.
31. As a Claude Code user, I want review to accept `--uncommitted`, `--base <branch>`, and `--commit <sha>`, so that I can scope a review to what I mean.
32. As a Claude Code user, I want review without a scope flag to pick uncommitted changes when the tree is dirty and otherwise the diff against the default branch, so that the common case needs no flag.
33. As a Claude Code user, I want review to take free-text focus, so that I can steer what Codex concentrates on.
34. As a Claude Code user, I want an adversarial review when I ask for one, so that Codex assumes the change is broken and hunts for ways to break it around my focus.
35. As a Claude Code user, I want review runs to edit nothing and Claude to present findings and stop, so that no fix is applied before I choose which findings matter.
36. As a Claude Code user, I want Claude to inspect the diff and confirm the verification Codex reports after an implementation run, so that Codex's claims are checked before I hear them.
37. As a Claude Code user, I want the plugin README to include a suggested CLAUDE.md routing table with model and effort per kind of work, so that setting up a new repo is a paste.
38. As a plugin maintainer, I want the plugin in a subdirectory of this repo with a root marketplace file, so that installs never drag in the brief, docs, or tests.
39. As a plugin maintainer, I want the version bumped on every change to the plugin directory, so that updates propagate.
40. As a plugin maintainer, I want the wrapper's executable bit committed and the skill to invoke it through an explicit shell anyway, so that a checkout without the bit still works.
41. As a plugin maintainer, I want a repo-only `check-codex-updates` skill that compares installed and latest versions, diffs the live `codex exec` and `codex exec review` help output against stored snapshots, and reads release notes since the snapshot version, so that I learn in one command what in the wrapper needs to change.
42. As a plugin maintainer, I want that skill to report and refresh snapshots on request but never edit the wrapper, so that changes to what Codex may do always go through my review.
43. As a plugin maintainer, I want the wrapper covered by tests that never call the model, so that I can run them after every CLI release.
44. As a plugin maintainer, I want a short manual smoke checklist for the real end-to-end path, so that the parts tests cannot reach are still verified before a version bump.
45. As a plugin maintainer, I want the wrapper to reject any subcommand, sandbox value, or flag it does not know, so that a typo or a stale CLAUDE.md fails closed.
46. As a plugin maintainer, I want the wrapper to preserve Codex's exit status, so that Claude's success and failure judgement is Codex's own.
47. As a plugin maintainer, I want the plugin to require no MCP server, app-server, daemon, broker, Node or Python runtime, third-party package, or persistent job store, so that the whole runtime stays auditable in minutes.

## Implementation Decisions

### Names and layout

- The marketplace, the plugin, and the skill are all named `codex-subagent`. The repo keeps its GitHub name.
- The plugin lives in its own subdirectory; the repo root holds the marketplace manifest, the brief, the glossary, ADRs, the maintainer skill, CLI help snapshots, and tests.
- Install: `/plugin marketplace add Billliu1993/simple-codex-subagent`, then `/plugin install codex-subagent@codex-subagent`. User scope.
- The plugin manifest's version field is bumped on every change to the plugin directory.

### Skill

- One skill. Its frontmatter allows model invocation and pre-approves only the bundled wrapper via an allowed-tools rule using the plugin root variable. It declares an argument hint matching the invocation forms below.
- The skill text tells Claude to: delegate when asked; otherwise, when the repo's CLAUDE.md routing table matches, propose and wait; build the prompt; run the wrapper in the background; report run id and log path; on exit read the final message or, on failure, the exit code and log tail; after an implementation run inspect the diff and the verification Codex reports; after a review present findings and stop.
- The skill text contains the prompt template (five sections), the adversarial instruction block, the status check, and the rules on model invocation. It contains no hang thresholds.
- The skill never calls `codex` directly.

### Invocation contract

```
/codex-subagent --model <m> --effort <e> [--read-only] [--resume <thread-id>] <task>
/codex-subagent review --model <m> --effort <e> [--uncommitted | --base <branch> | --commit <sha>] [focus]
```

- `--model` and `--effort` are required for both forms. Effort values pass through unvalidated so the wrapper does not track Codex's list.
- Anything the wrapper does not recognise is an error with a non-zero exit and a one-line reason.

### Wrapper

- A single Bash script with strict mode. First argument is the subcommand, `run` or `review`. Prompt or focus arrives on stdin; a terminal on stdin is an error.
- `run` maps to `codex exec` with: sandbox read-only or workspace-write; model and effort as config overrides or flags; web search set to live via config override; sandbox network access enabled via config override; working directory the git toplevel; JSON event output on stdout so the thread id can be captured from the first event; the final message written to a file via the last-message option. The approval flag is not passed; exec is already non-interactive. Ephemeral mode is never used, because it prevents resume.
- `run --resume <id>` maps to `codex exec resume <id>` with the same model, effort, and output options. The resume form accepts no `--sandbox` flag, so the wrapper sets the sandbox on every resume with a `sandbox_mode` config override (`read-only` or `workspace-write`, from the `--read-only` flag). A resumed run never inherits its sandbox from the thread or the user's config. If that invocation fails before producing a thread-started event, the wrapper starts a fresh run with the same prompt and writes a note to stderr and to the run directory saying the resume was abandoned.
- `review` maps to `codex exec review` with the chosen scope flag, model, effort, and last-message output. The review command accepts no sandbox flag and edits nothing. When no scope flag is given, the wrapper picks uncommitted if the working tree is dirty, else base against the repository's default branch.
- Every run creates a directory under the system temp directory named by a timestamp and pid. It holds: the progress log (Codex's stderr), the raw event stream, the final message, the pid, the thread id once known, and the exit code on completion. The wrapper prints the run directory path as its first line of stdout so Claude can find it.
- The wrapper exits with Codex's exit status. Its own errors use distinct non-zero codes.
- The wrapper never passes any bypass or full-access option and has no code path that could.

### Prompt

- Five sections: task and done-condition; what Claude knows that Codex needs (paths, decisions, an approved plan when one exists); constraints; verification expected; return format. Empty sections are omitted.
- Files are named by path. Contents are never pasted.
- Every prompt states: no commits, pushes, publishing, or deployment; preserve unrelated changes; stop and report if the task needs credentials or writes outside the repo.
- The return format asks Codex for: what changed, files touched, commands run and outcomes, blockers and unverified assumptions.

### Maintenance

- `check-codex-updates` is a skill under this repo's own `.claude/skills`, not in the plugin. It: reads the installed version and the latest published version; diffs the live help output for `codex exec`, `codex exec resume`, and `codex exec review` against snapshots stored in the repo; fetches release notes for versions after the snapshot's; reports lines in the wrapper that reference anything changed; on request, refreshes the snapshots. It never edits the wrapper.
- Snapshots are stored with the version they were taken from.

### Explicit non-goals

- No custom Claude agent, no forked context, no hooks.
- No durable job queue, no status or cancel commands that survive a restart, no transcript transfer.
- No full-access sandbox, no add-dir passthrough, no automatic escalation.
- No hang thresholds or automatic kill.
- No worktree or branch management.
- No Windows support.

## Testing Decisions

- A good test observes the wrapper only through its command line, stdin, stdout, stderr, exit code, and the run directory it creates. Tests never read the wrapper's internals and never call the real Codex.
- One seam: the wrapper's CLI. Tests place a fake `codex` executable first on PATH. The fake records its argv and stdin to files, optionally emits a scripted thread-started event and a final message, and exits with a scripted code.
- Tests are a single plain Bash script under the repo's `tests` directory, not shipped in the plugin, runnable with no dependencies beyond Bash, git, and coreutils. They create a throwaway git repo per case.
- Cases to cover: unknown subcommand rejected; missing model rejected; missing effort rejected; stdin from a terminal rejected; run passes read-only sandbox with the flag and workspace-write without; resume passes the matching `sandbox_mode` override and never the `--sandbox` flag; run passes model, effort, web search, and network overrides; run passes the prompt through stdin byte-for-byte; run directory contains log, final message, pid, thread id, and exit code; wrapper exit code equals the fake's; resume passes the thread id and falls back to a fresh run when the fake fails resume; review passes the chosen scope flag; review with no scope picks uncommitted on a dirty tree and base on a clean tree; no invocation ever contains a bypass or full-access option.
- Prior art: none in this repo. Structure follows the common pattern of a shell test script with a per-case setup function, an assertion helper, and a pass/fail summary.
- Manual smoke checklist, run before each version bump in a disposable repo: install from the marketplace; short form resolves; a read-only run changes nothing; a workspace-write run makes a small edit and runs a test; a live web search works; a review of uncommitted changes returns findings and edits nothing; resume continues a thread; a read-only thread resumed with `--read-only` cannot write and the same thread resumed without it can; a bad model name surfaces as a failure with a log tail.

## Out of Scope

- Everything under explicit non-goals above.
- Domain-level egress control or a restricted network profile.
- Structured output schemas for the final message.
- Choosing cached or indexed web search modes.
- Uninstalling the official plugin; that is a user step once this one proves out.
- Updating the brief document; it stays as history and this spec supersedes it.

## Further Notes

- Facts verified against codex-cli 0.155.1 on 2026-09-19: `exec resume` and `exec fork` accept no `--sandbox` or `-C` flag; `sandbox_mode` is accepted as a `-c` override on `resume` under `--strict-config`, and an unknown key is rejected, so the override is the sandbox mechanism for resume; new since 0.154.0 and unused by the wrapper: `exec fork`, `--worktree`, `--approve-for-me`, `--output-schema`, `--dangerously-bypass-hook-trust`. The help snapshots for issue 07 must be taken from 0.155.1 or later.
- Facts verified against codex-cli 0.154.0 on 2026-09-14: `exec` rejects the approval and search flags that the brief used; web search and sandbox network are set by config override; progress goes to stderr and the final message to stdout; the thread id is the first JSON event; the review command takes no sandbox flag; Codex refuses to run outside a git repository on its own; both plugin path variables expand inside allowed-tools rules; nothing sets the executable bit on install.
- The routing table the README suggests should carry model and effort per row and use the invocation forms above. The user's current table for the official plugin is the model for it.
- The hang-watching rules the user wrote for the official plugin move, if wanted, to each repo's CLAUDE.md as a threshold on the status check. The plugin does not carry them.
