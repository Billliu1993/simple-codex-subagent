# 02: Delegating skill carries mechanics only

**What to build:** The delegating skill says how a delegation is done and nothing about when it happens or how Claude behaves around it. The "When to delegate" section is replaced by one line pointing at the repo's `## Codex delegation` section. The review section keeps "a review edits nothing" and drops the instruction to present the findings and stop. The frontmatter description, the model and effort rules, the prompt template, the mandatory constraints, resume, review mechanics, the report branches, and the verification step after an implementation run all stay. A delegation run against the trimmed skill still works end to end.

**Blocked by:** 01 (Status subcommand on the wrapper)

**Status:** ready-for-agent

**Implementation:** delegate the build to an Agent-tool subagent with `model: "opus"`. The main session runs on Fable and only plans, reviews the subagent's diff, and checks the acceptance criteria. Spec: `.scratch/codex-delegation-setup/spec.md`. Governing decision: ADR-0002. Edit the skill with the `writing-for-agents` skill loaded.

- [ ] "When to delegate" is gone; one line in its place says the repo's `## Codex delegation` section decides whether and when work goes to Codex and how Claude behaves around a delegation
- [ ] The frontmatter description is unchanged
- [ ] The review section states that a review edits nothing and no longer tells Claude to present the findings and stop
- [ ] The verification step after an implementation run is unchanged
- [ ] The skill text names no pause rule, no stop rule, and no threshold anywhere
- [ ] Existing tests pass unchanged
- [ ] One real delegation run through the trimmed skill returns a final message
