# 06: Installable from GitHub with a documented routing table

**What to build:** A fresh repo installs the plugin in two commands from this repo's GitHub marketplace at user scope, pastes the README's suggested CLAUDE.md routing table, and one row of it works end to end. The README documents install, update, the invocation forms, the routing table with model and effort per kind of work, the run directory, the status check, resume, review, and the manual smoke checklist run before each version bump. The version is bumped.

**Blocked by:** 02 (Implementation and research runs return a final message), 04 (Follow-up resumes the thread, falls back when it can't), 05 (Review through Codex's built-in command)

**Status:** ready-for-agent

**Implementation:** delegate the build to an Agent-tool subagent with `model: "opus"`. The main session runs on Fable and only plans, reviews the subagent's diff, and checks the acceptance criteria.

- [ ] `/plugin marketplace add Billliu1993/simple-codex-subagent` then `/plugin install codex-subagent@codex-subagent` succeeds in a fresh repo
- [ ] Short form `/codex-subagent` resolves after install
- [ ] README has a routing table with rows for implementation, research and exploration, review, and adversarial review, each with model and effort
- [ ] One pasted row runs successfully in the fresh repo
- [ ] README has the manual smoke checklist from the spec
- [ ] Plugin version bumped; `/plugin update` picks it up
- [ ] README states the plugin needs no MCP server, app-server, daemon, broker, Node or Python runtime, or persistent job store
