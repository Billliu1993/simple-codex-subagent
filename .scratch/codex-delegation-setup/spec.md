# Spec: Codex delegation section, setup skill, and status subcommand

Status: ready-for-agent
Source: grilling session on 2026-09-20, following the first real-work run of plugin version 0.2.3 and the orchestrator's friction report from it.
Vocabulary: `CONTEXT.md`. Governing decisions: ADR-0001, ADR-0002.
Ships as: plugin version 0.3.0, one bump for the whole spec.

## Problem Statement

The first real run of the plugin surfaced three kinds of friction, all from the same cause: the delegating skill says more than how a delegation is done. It tells the orchestrator to propose and wait for a go-ahead when it did not ask for Codex, and to present findings and stop after a review. Both rules are per-repo behaviour, and both collided with what the repo's own `CLAUDE.md` said and with the orchestrator's general guidance, costing a round trip each. The status check is a 15-line snippet the orchestrator pastes on every check, and because only the wrapper is pre-approved, every paste is also a permission prompt. And the routing table that each repo needs is a template pasted from the README, which reads as a standing order to delegate and is the place the behaviour rules actually belong.

## Solution

Draw the boundary from ADR-0002: the delegating skill carries the mechanics of a delegation and nothing else; a `## Codex delegation` section in each repo's `CLAUDE.md` carries the behaviour around it. A new user-invoked setup skill interviews for that section and writes it, so nobody pastes a template. The wrapper gains a `status` subcommand, so the status check is one short line that falls inside the pre-approval the skill already has.

## User Stories

### The boundary

1. As a Claude Code user, I want the delegating skill to say only how a delegation is done, so that it never contradicts my repo's instructions about when to delegate.
2. As a Claude Code user, I want whether and when work goes to Codex decided by my repo's `CLAUDE.md`, so that each repo can choose straight delegation or a pause without editing the plugin.
3. As a Claude Code user, I want whether Claude stops after a review decided by my repo's `CLAUDE.md`, so that the stop is a choice I made and not a surprise from the skill.
4. As a Claude Code user, I want the skill to keep verifying Codex's claims after an implementation run, so that no repo gets unverified work by default.
5. As a Claude Code user, I want the skill to keep loading when my routing table matches a kind of work, so that the section's rules get a chance to apply in the unprompted case.
6. As a Claude Code user, I want the skill to point at the repo's Codex delegation section in one line where the old "when to delegate" rules were, so that an orchestrator without a section knows where the rules would live.

### The Codex delegation section

7. As a Claude Code user, I want one `## Codex delegation` section in my repo's `CLAUDE.md` holding the routing table and the behaviour rules, so that there is one place to read and one place to edit.
8. As a Claude Code user, I want the section to carry the routing table with a model and effort per kind of work, so that every delegation runs on the model I chose for that work.
9. As a Claude Code user, I want the section to state the pause rule, so that the orchestrator knows whether to propose and wait or delegate straight when I did not ask for Codex.
10. As a Claude Code user, I want the section to state the stop-after-review rule, so that the orchestrator presents findings and waits for me to pick which ones matter.
11. As a Claude Code user, I want the section to carry the quiet-run threshold, so that the orchestrator tells me when a run has gone quiet for that long and leaves the kill decision to me.
12. As a Claude Code user, I want the section to carry a concurrency cap, so that research dispatched in waves has a wave size.
13. As a Claude Code user, I want the section to list what Codex cannot run in this environment, so that the orchestrator runs that verification itself after an implementation run.
14. As a Claude Code user, I want the section to carry generic guidance for research runs, one question per run and read-only by default, so that a broad topic is split into focused runs rather than one long one.
15. As a Claude Code user, I want the section to be plain markdown I can edit by hand, so that a repo can grow its rules without the setup skill.

### The setup skill

16. As a Claude Code user, I want a user-invoked setup skill in the same plugin, so that a new repo gets its Codex delegation section in one command.
17. As a Claude Code user, I want the setup skill to never run on the model's own initiative, so that my `CLAUDE.md` changes only when I ask.
18. As a Claude Code user, I want the setup skill to confirm Codex is on PATH and signed in and report its version before writing anything, so that I never get a section for a Codex that is not there.
19. As a Claude Code user, I want the setup skill to fetch the current model and effort names from the OpenAI Codex models documentation, so that I choose from what exists today rather than from a stale list in the plugin.
20. As a Claude Code user, I want the setup skill to mark my Codex config's default model in that list and fall back to it when the fetch fails, so that setup works offline.
21. As a Claude Code user, I want the setup skill to trust the model names I choose rather than validating each with a run, so that setup takes seconds and a typo surfaces the way any bad model name already does.
22. As a Claude Code user, I want the setup skill to interview me section by section, leading with a recommended answer I can accept in a word, so that the common case is quick.
23. As a Claude Code user, I want the interview to ask, in order, for the model per row, the effort per row, the pause rule, the quiet-run threshold, what Codex cannot run here, and the concurrency cap, so that every line of the section is a choice I made or a default I accepted.
24. As a Claude Code user, I want the default rows to be the four I use today, implementation including spikes and prototypes, research and exploration from any source, review, and adversarial review, so that the common table needs no edits.
25. As a Claude Code user, I want to add rows when the setup skill shows me the draft, so that a repo with a fifth kind of work is not stuck with four.
26. As a Claude Code user, I want each added row to name one of three shapes, a read-only run, a write run, or a review, so that the setup skill can write its invocation and the wrapper can run it.
27. As a Claude Code user, I want to see the draft section and edit it before it is written, so that nothing lands in `CLAUDE.md` unseen.
28. As a Claude Code user, I want the setup skill to write into `CLAUDE.md` when it exists, else `AGENTS.md`, and to ask me which to create when neither exists, so that it never creates a second instructions file beside one I already have.
29. As a Claude Code user, I want the section to be standalone at the top level of the file, so that another setup skill updating its own section cannot clobber it.
30. As a Claude Code user, I want a re-run of the setup skill to start from the values already in my section and update it in place, so that switching one model is one answer.
31. As a Claude Code user, I want a re-run to keep every hand edit that is not a line the skill owns, so that the guidance my repo has accumulated survives.
32. As a Claude Code user, I want the setup skill to write nothing outside that one file, so that the section is the whole configuration.
33. As a Claude Code user, I want the section to open with the delegating rule in the words the orchestrator will follow, so that "delegate by the table" and "propose and wait" cannot both be read from it.

### The status subcommand

34. As a Claude Code user, I want a `status <run dir>` subcommand on the wrapper, so that the status check is one short line rather than a pasted snippet.
35. As a Claude Code user, I want the status check to fall inside the wrapper's existing pre-approval, so that looking at a run never costs a permission prompt.
36. As a Claude Code user, I want the status output to show whether the pid is alive or exited, with the exit code when exited, so that I know if the run is still going.
37. As a Claude Code user, I want the status output to show seconds since the progress log last moved, so that I can judge a quiet run against my threshold.
38. As a Claude Code user, I want the status output to show the thread id when it is known, so that I can resume a run that is still going without opening another file.
39. As a Claude Code user, I want the status output to show the review scope on a review, so that I know what diff Codex is reading.
40. As a Claude Code user, I want the status output to flag when a resume fell back to a fresh run, so that I learn it at the first check and not at the report.
41. As a Claude Code user, I want the status output to end with the last five lines of each progress log file, so that I can see what Codex was doing.
42. As a Claude Code user, I want the status subcommand to read and print and do nothing else, so that it never kills a run and holds no threshold.
43. As a Claude Code user, I want the status subcommand to exit 0 when it read the run directory and 64 when it could not, so that a wrong path is an error and not an empty report.
44. As a plugin maintainer, I want the status test to call the subcommand rather than copy a snippet from the skill, so that the skill and the test cannot drift apart.

### Documentation and release

45. As a Claude Code user, I want the README to tell me to run the setup skill and show one example of the section it writes, so that I see what I will get without a template to paste.
46. As a Claude Code user, I want the README's status section to point at the subcommand, so that it describes what actually runs.
47. As a plugin maintainer, I want the manual smoke checklist to cover the setup skill on a bare repo, on a repo with a hand-edited section, and one delegation driven by a generated section, so that what the tests cannot reach is still checked before a release.
48. As a plugin maintainer, I want the version bumped once to 0.3.0 for this whole spec, so that a repo that relied on the skill's pause sees a minor bump where its behaviour changes.
49. As a plugin maintainer, I want ADR-0002 to record why the skill stopped saying when to delegate, so that nobody puts the rules back.

## Implementation Decisions

### Delegating skill

- The "When to delegate" section is removed. In its place, one line says that whether and when work goes to Codex, and how Claude behaves around a delegation, is set by the repo's `## Codex delegation` section.
- The frontmatter description is unchanged, so the skill still loads when the routing table matches a kind of work.
- The rules on model and effort, the prompt template, the mandatory constraints, resume, review mechanics, the report branches, and the verification step after an implementation run all stay.
- In the review section, "a review edits nothing" stays as a fact about Codex's review command. The sentence telling Claude to present the findings and stop is removed.
- The status snippet is replaced by the `status` subcommand invocation, with the same guidance on when to run it: when the user asks, and before settling in to wait. The closing paragraph about pre-approval is reworded, since the status check no longer goes through the permission flow; reading a run's files, `git diff`, `git status`, and verification commands still do.

### Wrapper

- A third subcommand, `status`, taking one positional argument, the run directory. It takes no flags; a flag is exit 64 like any unknown flag.
- Output, in order: pid line (alive, or exited with the recorded exit code, or exited with exit code not recorded); seconds since the newer of the two progress log files changed; the thread id when the file exists; the review scope lines when the file exists; one line noting a resume fallback and quoting the recorded reason when the file exists; then the last five lines of each non-empty progress log file, each preceded by a header naming the file.
- Exit 0 when the run directory exists and is readable, 64 when the argument is missing or the directory cannot be read. The exit code table gains the new 64 cause.
- The pid and mtime logic is the snippet's, including the GNU-then-BSD `stat` fallback. It kills nothing and holds no threshold.
- No change to `allowed-tools`: the wrapper prefix already covers every subcommand.

### Codex delegation section

- Heading `## Codex delegation`, standalone at the top level of the file, never nested under another section.
- Opens with one sentence stating the delegating rule the repo chose: delegate by the table below, or propose by the table and wait for a go-ahead when the user did not ask for Codex. Only one of the two appears.
- Then the routing table: columns for the kind of work, model, effort, and invocation. Default rows: implementation including spikes and prototypes as a write run; research and exploration from any source as a read-only run; review; adversarial review as the review row asked for adversarially. Each row's invocation is the wrapper form for its shape with the row's model and effort filled in.
- Then the research-run guidance: one question per run with at most a few things to answer, broad topics split into focused runs dispatched in waves under the concurrency cap, read-only by default with the flag dropped only when the brief names a repo path for Codex to write to.
- Then the behaviour lines: runs go to the background; report when the status check shows a run quiet for the threshold, the kill decision is the user's; the concurrency cap as a number of runs at once; after a review present the findings and stop, the user picks which ones a later run fixes; the list of what Codex cannot run here and that the orchestrator runs that verification itself, omitted when the answer was nothing.
- The lines the setup skill owns are the delegating sentence, the table rows it wrote, the threshold, the cap, the stop rule, and the environment line. Everything else in the section is the user's.

### Setup skill

- A second skill in the plugin, invoked as `/codex-subagent:setup`, with model invocation disabled so it runs only when the user asks.
- Preflight: `codex` on PATH and `codex --version` reported; sign-in confirmed by whatever the CLI offers for it, with the login command named if it is not signed in. Preflight failure ends the skill before any interview.
- Model discovery: fetch the OpenAI Codex models documentation, following its redirect, and collect the model identifiers and effort levels it lists. Read the default model from the user's Codex config and mark it. If the fetch fails, offer the config default and accept any typed name. No validation runs.
- Interview, one section per answer, each led by the recommended answer: model per row with the config default as the recommendation; effort per row with high for implementation, medium for research, high for review and adversarial review; pause rule with straight delegation as the default; quiet-run threshold with three minutes as the default; what Codex cannot run here with nothing as the default; concurrency cap with two as the default.
- Draft: show the whole section. Additions offered at this step: more rows, each with a label, model, effort, and one of three shapes, read-only run, write run, or review. Adversarial review is not a shape; it is the review shape asked for adversarially. The user edits the draft before it is written.
- Write: into `CLAUDE.md` if it exists, else `AGENTS.md` if it exists, else ask which to create. When the file already has a `## Codex delegation` section, the interview's defaults come from its current values, and the write updates only the lines the skill owns, leaving every other line in the section where it is. Nothing is written outside that file.
- Done: say which file was written and that the delegating skill now reads the section from there.

### README

- The paste-in template is removed. The routing section tells the user to run the setup skill and shows one example of a generated section, copied from real output so it stays honest.
- The status section names the subcommand and its output.
- The exit code table gains the status cause under 64.
- The manual smoke checklist gains the three setup cases from user story 47.

### Version

- Plugin manifest version 0.3.0.

## Testing Decisions

- A good test observes the wrapper only through its command line, stdin, stdout, stderr, exit code, and the run directory. Tests never read the wrapper's internals and never call the real Codex.
- One seam, unchanged: the wrapper's CLI, with the fake `codex` first on PATH.
- The ticket 03 status test stops copying the skill's snippet and calls the `status` subcommand. Cases: mid-run with a sleeping fake, the output says alive and the log moved recently; after exit, the output says exited with the fake's exit code; a run with a thread id prints it; a review prints its scope lines; a run whose resume fell back prints the fallback line; a missing directory exits 64; a flag exits 64.
- The two skills have no automated seam. They are prose executed by Claude and are covered by the manual smoke checklist: setup on a repo with no `CLAUDE.md`; setup on a repo whose section carries hand edits, confirming the edits survive; one delegation run driven by a generated section.
- Prior art: the existing test script, its per-ticket sections, assertion helpers, and fake `codex`.

## Out of Scope

- Review usage data. `codex exec review` reports its token usage in a child session file the wrapper cannot see; a README note at most, in a later change.
- Removing the extra read that gets the run directory from a background dispatch. The read is the price of the completion notification, and the alternatives lose that or the private run directory.
- Validating model names at setup with a real run.
- Writing anything outside `CLAUDE.md` or `AGENTS.md` from the setup skill.
- A fourth invocation shape for custom rows; a row that needs one needs a wrapper change first.
- Changing the delegating skill's frontmatter description.
- Amending the first spec; ADR-0002 records what changed and why.

## Further Notes

- Verified on 2026-09-20: the Codex CLI has no model-listing command; the OpenAI Codex models documentation page redirects once and then lists the model identifiers and the effort levels, including levels the README's suggested efforts do not use. The user's Codex config carries a default model and effort the setup skill can read.
- Verified on 2026-09-20 on a real review run: the parent session file holds the findings and no token counts; the child session created seconds later holds the counts and the rate-limit snapshots. This is why review usage data is out of scope for the wrapper.
- The section the user runs today, with four rows, research guidance, a three-minute threshold, and a list of tools Codex cannot run, is the model for the generated section's shape and wording.
- Spec stories 6 and 35 of the first spec are superseded by this spec and ADR-0002. The plugin's default becomes straight delegation, which is a behaviour change on update for any repo that relied on the skill's pause.
