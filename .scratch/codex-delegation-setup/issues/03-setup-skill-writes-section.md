# 03: Setup skill writes the section on a bare repo

**What to build:** A user runs `/codex-subagent:setup` in a repo with no `## Codex delegation` section and gets one written into `CLAUDE.md`, else `AGENTS.md`, else the file they choose when asked. The skill first confirms Codex is on PATH and signed in and reports its version, stopping if not. It fetches the OpenAI Codex models documentation, following its redirect, to offer the current model identifiers and effort levels, marks the default model from the user's Codex config, and falls back to that default with any typed name accepted when the fetch fails; no validation runs. It interviews one section per answer, each led by a recommended answer: model per row, effort per row (high, medium, high, high), pause rule (default straight delegation), quiet-run threshold (default three minutes), what Codex cannot run here (default nothing), concurrency cap (default two). It shows the draft, where the user may add rows, each with a label, model, effort, and one of three shapes: read-only run, write run, or review. The section is standalone at the top level and follows the agreed shape: the delegating sentence, the routing table with the four default rows, the research-run guidance, then the behaviour lines. The skill writes nothing outside that file. One delegation driven by the generated section succeeds.

**Blocked by:** 02 (Delegating skill carries mechanics only)

**Status:** ready-for-agent

**Implementation:** delegate the build to an Agent-tool subagent with `model: "opus"`. The main session runs on Fable and only plans, reviews the subagent's diff, and checks the acceptance criteria. Spec: `.scratch/codex-delegation-setup/spec.md`. Governing decision: ADR-0002. Write the new skill with the `writing-for-agents` skill loaded; the repo's own setup skill under `.claude/skills` is a source of ideas for the explore, ask, draft, write flow, not a template to copy.

- [ ] A second skill in the plugin resolves as `/codex-subagent:setup` and has model invocation disabled
- [ ] Preflight reports the Codex version and stops with the login command named when Codex is missing or not signed in
- [ ] Model discovery fetches the documentation, marks the config default, and falls back to it when the fetch fails
- [ ] The interview runs in the agreed order with the agreed defaults, each answer acceptable in a word
- [ ] The draft is shown before writing; rows can be added, each naming one of the three shapes; adversarial review is the review shape asked for adversarially, not a fourth shape
- [ ] The written section opens with exactly one delegating sentence, carries the routing table, the research-run guidance, and the behaviour lines, and omits the environment line when the answer was nothing
- [ ] The section is standalone at the top level of `CLAUDE.md`, else `AGENTS.md`, else the file the user chose when asked; nothing is written elsewhere
- [ ] In a disposable repo, one delegation run from a row of the generated section returns a final message
