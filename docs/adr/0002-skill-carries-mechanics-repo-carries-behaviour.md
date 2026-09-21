---
status: accepted
---

# The skill carries the mechanics of a delegation; the repo carries the behaviour around it

The first release put two behaviour rules in the delegating skill: propose and wait for a go-ahead when the routing table matched but the user had not asked for Codex, and present findings and stop after a review. A real run showed both colliding with the orchestrator's general guidance, and a repo's `CLAUDE.md` saying "delegate by the table" contradicted the skill's pause outright. We decided the skill says only how a delegation is done — prompt, sandbox, run, resume, review, status, verification of the result — and a `## Codex delegation` section in each repo's `CLAUDE.md` says when work goes to Codex and how Claude behaves around it: the routing table, the pause rule, the stop-after-review rule, the quiet-run threshold, the concurrency cap, and what Codex cannot run there. A user-invoked setup skill writes that section, so no user pastes a template.

## Considered options

- **Keep the rules in the skill.** Rejected: a skill is the same for every repo and is loaded by the model, so a repo cannot vary the pause or the stop without contradicting it, and the contradiction is exactly what the run surfaced.
- **Rules in the skill, overridable from `CLAUDE.md`.** Rejected: two places say the same thing and the reader has to know which wins.
- **Rules in `CLAUDE.md`, written by a setup skill.** Chosen. One place, per repo, hand-editable, and the setup skill keeps the section's shape current across plugin versions.

## Consequences

- The verification step after an implementation run stays in the skill: a delegation is not done until its result is checked, and that is not a choice a repo should make differently.
- A repo without the section gets no pause and no stop, and the skill does not warn about that; the section is the repo's responsibility.
- The setup skill's default is straight delegation, not the pause the first release shipped, so updating the plugin changes behaviour for a repo that relied on the skill's pause. The version bump to 0.3.0 marks that.
