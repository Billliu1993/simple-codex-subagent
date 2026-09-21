---
name: setup
description: "Interview this repo for its `## Codex delegation` section — routing table, pause rule, quiet-run threshold, concurrency cap — and write it into CLAUDE.md. Invoked by name only."
disable-model-invocation: true
---

A repo's `## Codex delegation` section says when work goes to Codex and how you behave around a
delegation. The `codex-subagent` skill says only how a delegation is done, and reads the rest from
that section. Interview the user for it and write it into one file. Nothing outside that file
changes: no docs, no scripts, no config.

Ask one question at a time, each led by the recommended answer, so the user can accept it in a
word. AskUserQuestion fits that shape — one question per call, the recommendation first among the
options — and plain text asks it just as well.

## 1. Preflight

Report the version and confirm the sign-in before anything else:

```
codex --version
codex login status
```

A signed-in CLI prints one line naming how it is signed in. If `codex` is not on `PATH`, or that
line says it is not signed in, tell the user, name `codex login` as the fix, and stop there — no
interview, no draft, no write.

## 2. Model discovery

Read today's names off the OpenAI Codex models documentation:

```
curl -sL https://developers.openai.com/codex/models
```

The URL answers 308 to a second one, so follow the redirect: `-L` above, or the WebFetch tool,
which follows it too. Collect the model identifiers — the page prints each as a `codex -m
<identifier>` command — and the reasoning-effort levels, which its CLI selector lists lowest
first.

Then read `model` and `model_reasoning_effort` from `~/.codex/config.toml` and mark that model as
the config default in the list you show. When the fetch fails, offer the config default on its own
and accept any name the user types.

Nothing is validated: no run is made to check a model name. A typo surfaces as a failed run, the
way a bad model name always does.

## 3. Interview

In this order, one answer each. Each answer covers every row at once; the user names a row to vary
just that one.

1. **Model per row.** Recommend the config default for every row.
2. **Effort per row.** Recommend high for implementation, medium for research, high for review,
   high for adversarial review.
3. **Pause rule.** Recommend straight delegation. The alternative is to propose by the table and
   wait for a go-ahead when the user did not ask for Codex.
4. **Quiet-run threshold.** Recommend 3 minutes.
5. **What Codex cannot run here.** Recommend nothing. Otherwise a short list, like Docker, a
   package manager, or device simulators.
6. **Concurrency cap.** Recommend 2 runs at once.

## 4. Draft

Show the whole section, filled in from the answers, and let the user edit it before anything is
written:

```markdown
## Codex delegation

Delegate through the `codex-subagent` skill by the table below.

| Work | Model | Effort | Invocation |
| --- | --- | --- | --- |
| Implementation — including spikes and prototypes | `<model>` | `<effort>` | `/codex-subagent --model <model> --effort <effort> <task>` |
| Research and exploration — any source | `<model>` | `<effort>` | `/codex-subagent --model <model> --effort <effort> [--read-only] <task>` |
| Review — findings on a diff | `<model>` | `<effort>` | `/codex-subagent review --model <model> --effort <effort> [--uncommitted \| --base <branch> \| --commit <sha>] [focus]` |
| Adversarial review | `<model>` | `<effort>` | the review row, asked for as an adversarial review so the skill prepends its adversarial block |

One question per research run, with at most a few things to answer. Split a broad topic into
focused runs and dispatch them in waves under the concurrency cap. A research run is read-only:
drop `--read-only` only when the brief names a repo path for Codex to write to, and then say which
files to leave alone.

Runs go to the background.
Tell me when the status check shows a run quiet for <threshold>; the decision to kill it is mine.
Keep at most <cap> runs going at once.
After a review, present the findings and stop: I pick which ones a later run fixes.
Codex cannot run <what it cannot run> here, so the orchestrator runs that verification itself.
```

The heading, the one delegating sentence, the table, the research guidance, and the behaviour lines
appear in that order, and the invocations are the skill form above rather than the wrapper path.
Three of those lines vary with the answers:

- **The delegating sentence.** Exactly one sentence, and exactly one of two: the draft's, or
  `Propose a delegation by the table below and wait for my go-ahead when I did not ask for Codex.`
- **The threshold and cap lines** carry the numbers the user gave.
- **The environment line** is omitted outright when the answer was nothing.

Offer more rows at this step. Each one needs a label, a model, an effort, and one of three shapes:

| Shape | Invocation |
| --- | --- |
| Read-only run | `/codex-subagent --model <m> --effort <e> --read-only <task>` |
| Write run | `/codex-subagent --model <m> --effort <e> <task>` |
| Review | `/codex-subagent review --model <m> --effort <e> [--uncommitted \| --base <branch> \| --commit <sha>] [focus]` |

Adversarial review is one of these three, not a fourth: it is the review shape asked for
adversarially, which is what the default row says. A row that wants a shape outside the three needs
a wrapper change first, so say so and offer the nearest of the three.

## 5. Write

Pick the file: `CLAUDE.md` when it exists, else `AGENTS.md` when it exists, else ask which of the
two to create. Never create one beside the other.

Put the section at the top level of that file, as `## Codex delegation`, standalone — nested under
another heading, another setup skill's write can clobber it. Append it at the end of the file unless
the user says where it goes.

A file that already carries a `## Codex delegation` section is a re-run: keep it single, take the
interview's recommended answers from its current values, and rewrite only the lines this skill owns.

## 6. Done

Name the file you wrote and say the `codex-subagent` skill now reads this repo's delegation rules
from that section.

## Lines this skill owns

The delegating sentence, the table rows it wrote, the threshold line, the cap line, the
stop-after-review line, and the environment line. Everything else in the section is the user's —
rows they added or reworded, guidance they wrote — and a re-run leaves it where it is.
