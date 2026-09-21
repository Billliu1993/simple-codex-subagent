# 04: Setup skill re-run keeps hand edits

**What to build:** A user re-runs `/codex-subagent:setup` on a repo whose section already exists and has hand-written lines. The interview starts from the values already in the section, so switching one model is one answer. The write updates only the lines the skill owns: the delegating sentence, the table rows it wrote, the threshold, the cap, the stop rule, and the environment line. Every other line in the section, including rows the user added or reworded and guidance they wrote, stays where it is. The section is never duplicated.

**Blocked by:** 03 (Setup skill writes the section on a bare repo)

**Status:** ready-for-agent

**Implementation:** delegate the build to an Agent-tool subagent with `model: "opus"`. The main session runs on Fable and only plans, reviews the subagent's diff, and checks the acceptance criteria. Spec: `.scratch/codex-delegation-setup/spec.md`. Governing decision: ADR-0002. Edit the skill with the `writing-for-agents` skill loaded.

- [ ] On a repo with an existing section, the interview's recommended answers are the section's current values
- [ ] After a re-run that changes one model, that row's model and invocation change and nothing else in the section does
- [ ] Hand-written lines in the section, and rows the user added or reworded, survive a re-run byte for byte
- [ ] A re-run never produces a second `## Codex delegation` section
- [ ] The skill text names which lines it owns
