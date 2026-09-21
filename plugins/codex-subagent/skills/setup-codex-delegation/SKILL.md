---
name: setup-codex-delegation
description: "Interview this repo for its `## Codex delegation` section — routing table, pause rule, quiet-run threshold, concurrency cap — and write it into CLAUDE.md."
disable-model-invocation: true
---

A repo's `## Codex delegation` section says when work goes to Codex and how you behave around a delegation. The `codex-subagent` skill says only how a delegation is done, and reads the rest from that section. Interview the user for it and write it into one file. Nothing outside that file changes: no docs, no scripts, no config.

Ask one question at a time, each led by the recommended answer, so the user can accept it in a word. AskUserQuestion fits that shape — one question per call, the recommendation first among the options — and plain text asks it just as well.

## 1. Preflight

Report the version and confirm the sign-in before anything else:

```
codex --version
codex login status
```

A signed-in CLI prints one line naming how it is signed in. If `codex` is not on `PATH`, or that line says it is not signed in, tell the user, name `codex login` as the fix, and stop there — no interview, no draft, no write.

## 2. Model discovery

Read today's names off the OpenAI Codex models documentation:

```
curl -sL https://developers.openai.com/codex/models
```

The URL answers 308 to a second one, so follow the redirect: `-L` above, or the WebFetch tool, which follows it too. Collect the model identifiers — the page prints each as a `codex -m <identifier>` command — and the reasoning-effort levels, which its CLI selector lists lowest first.

Then read `model` and `model_reasoning_effort` from `~/.codex/config.toml` and mark that model as the config default in the list you show. When the fetch fails, offer the config default on its own and accept any name the user types.

Nothing is validated: no run is made to check a model name. A typo surfaces as a failed run, the way a bad model name always does.

## 3. The file, and the section already in it

Pick the file before the interview, because a section already in it sets the recommendations: `CLAUDE.md` when it exists, else `AGENTS.md` when it exists, else ask which of the two to create. Never create one beside the other.

Then look for the section:

```
grep -n '^## Codex delegation' <file>
```

The section runs from that top-level heading to the next top-level `## ` heading, or to the end of the file. No heading is a first run: the interview recommends the defaults in step 4, and step 6 appends a new section. One heading is a re-run: the section's current values are the recommendations, and step 6 updates that section where it stands.

Read each value off the section as it reads now, so a line the user reworded still yields it:

| Answer | The line | The value in it |
| --- | --- | --- |
| Model and effort, per row | Each table row | The quoted name in that row's Model cell and in its Effort cell |
| Pause rule | The delegating sentence under the heading | Straight delegation when it says to delegate by the table; the pause when it says to propose and wait for a go-ahead |
| Threshold | The line about a run gone quiet | The duration in it |
| Cap | The line about how many runs go at once | The number in it |
| Environment list | The line about what Codex cannot run here | The things it lists; no such line means the answer is nothing |

When a line is gone, or carries no value you can read, recommend step 4's default for that one answer and say as you ask it that the default is where the recommendation came from. Every other answer still comes from the section.

Read the per-row models and efforts only from the rows this skill owns, matched by their Work label. A row the user added, and a row whose label they reworded, is theirs: the interview passes over it and the write leaves it byte for byte. Name those rows when you show the draft, so the user knows they stay as they are and can edit them by hand.

## 4. Interview

In this order, one answer each. Each answer covers every row at once; the user names a row to vary just that one. Lead with the current value whenever step 3 found one — a re-run that switches one model is then one answer, the rest accepted as they stand — and otherwise with the default here:

1. **Model per row.** Recommend the config default for every row.
2. **Effort per row.** Recommend high for implementation, medium for research, high for review, high for adversarial review.
3. **Pause rule.** Recommend straight delegation. The alternative is to propose by the table and wait for a go-ahead when the user did not ask for Codex.
4. **Quiet-run threshold.** Recommend 3 minutes.
5. **What Codex cannot run here.** Recommend nothing. Otherwise a short list, like Docker, a package manager, or device simulators.
6. **Concurrency cap.** Recommend 2 runs at once.

## 5. Draft

Show the whole section, filled in from the answers, and let the user edit it before anything is written:

```markdown
## Codex delegation

Delegate through the `codex-subagent` skill by the table below.

| Work | Model | Effort | Invocation |
| --- | --- | --- | --- |
| Implementation — including spikes and prototypes | `<model>` | `<effort>` | `/codex-subagent --model <model> --effort <effort> <task>` |
| Research and exploration — any source | `<model>` | `<effort>` | `/codex-subagent --model <model> --effort <effort> --read-only <task>` |
| Review — findings on a diff | `<model>` | `<effort>` | `/codex-subagent review --model <model> --effort <effort> [--uncommitted \| --base <branch> \| --commit <sha>] [focus]` |
| Adversarial review | `<model>` | `<effort>` | the review row, asked for as an adversarial review so the skill prepends its adversarial block |

One question per research run, with at most a few things to answer. Split a broad topic into focused runs and dispatch them in waves under the concurrency cap. A research run is read-only: drop `--read-only` only when the brief names a repo path for Codex to write to, and then say which files to leave alone.

Runs go to the background.
Tell me when the status check shows a run quiet for <threshold>; the decision to kill it is mine.
Keep at most <cap> runs going at once.
After a review, present the findings and stop: I pick which ones a later run fixes.
Codex cannot run <what it cannot run> here, so the orchestrator runs that verification itself.
```

The heading, the one delegating sentence, the table, the research guidance, and the behaviour lines appear in that order, and the invocations are the skill form above rather than the wrapper path. Three of those lines vary with the answers:

- **The delegating sentence.** Exactly one sentence, and exactly one of two: the draft's, or `Propose a delegation by the table below and wait for my go-ahead when I did not ask for Codex.`
- **The threshold and cap lines** carry the numbers the user gave.
- **The environment line** is omitted outright when the answer was nothing.

On a re-run the draft is the section as it will read afterwards: the section as it stands now, with the owned lines carrying the new answers. Everything the user wrote — their guidance, their rows — shows in the draft exactly as it already reads.

Offer more rows at this step. Each one needs a label, a model, an effort, and one of three shapes:

| Shape | Invocation |
| --- | --- |
| Read-only run | `/codex-subagent --model <m> --effort <e> --read-only <task>` |
| Write run | `/codex-subagent --model <m> --effort <e> <task>` |
| Review | `/codex-subagent review --model <m> --effort <e> [--uncommitted \| --base <branch> \| --commit <sha>] [focus]` |

Adversarial review is one of these three, not a fourth: it is the review shape asked for adversarially, which is what the default row says. A row that wants a shape outside the three needs a wrapper change first, so say so and offer the nearest of the three.

## 6. Write

The file is the one step 3 picked. The section sits at the top level of it, as `## Codex delegation`, standalone — nested under another heading, another setup skill's write can clobber it.

A first run appends the whole section at the end of the file, unless the user says where it goes.

A re-run edits each owned line where it stands, one edit per line, matching the line as it reads now. That is what keeps the rest of the section intact; a section rewritten wholesale from the draft flattens the user's lines back to the draft's.

The six lines below are the ones this skill owns, and the only ones a re-run rewrites; every other line in the section is the user's:

- **The delegating sentence.** Replace whichever of the two forms the section carries, in place.
- **The rows this skill wrote.** Find each by its Work label and replace that row's Model, Effort, and Invocation cells. A switched model lands in two cells of one row and moves nothing else in the table.
- **The threshold line, the cap line, and the stop-after-review line.** Replace each in place. The interview asks for the two numbers and never for the stop-after-review line, whose wording is fixed: the skill writes it on a first run and rewrites it on a re-run all the same.
- **The environment line.** Update it, add it when the answer names something and no line is there, or drop it when the answer is now nothing. A line already there keeps the position it has; a new one goes where the draft puts it, last of the behaviour lines.

Every other line in the section survives byte for byte, in place: the research guidance, rows the user added or reworded, and every line they wrote themselves. Afterwards `grep -c '^## Codex delegation'` on the file is 1, and the rest of the file — every section before and after — reads as it did.

## 7. Done

Name the file you wrote and say the `codex-subagent` skill now reads this repo's delegation rules from that section.
