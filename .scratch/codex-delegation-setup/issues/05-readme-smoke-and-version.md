# 05: README, smoke checklist, and version 0.3.0

**What to build:** A user reading the README learns to run the setup skill instead of pasting a template, sees one example of a generated section copied from real output, and finds the status subcommand and ADR-0002 referenced where the old snippet and template were. The manual smoke checklist covers what the tests cannot reach: setup on a bare repo, setup on a repo with a hand-edited section, and one delegation driven by a generated section. The plugin manifest reads 0.3.0 and the update check still passes.

**Blocked by:** 04 (Setup skill re-run keeps hand edits)

**Status:** ready-for-agent

**Implementation:** delegate the build to an Agent-tool subagent with `model: "opus"`. The main session runs on Fable and only plans, reviews the subagent's diff, and checks the acceptance criteria. Spec: `.scratch/codex-delegation-setup/spec.md`. Governing decisions: ADR-0001, ADR-0002.

- [ ] The paste-in routing table template is gone; the routing section says to run the setup skill and shows one example section copied from real output
- [ ] The README says the skill carries mechanics and the section carries behaviour, with a pointer to ADR-0002
- [ ] The smoke checklist gains the three setup cases
- [ ] Plugin manifest version is 0.3.0 and the update check reports the plugin current
- [ ] The full manual smoke checklist has been run once in a disposable repo before the bump, with results recorded as a comment on this ticket
