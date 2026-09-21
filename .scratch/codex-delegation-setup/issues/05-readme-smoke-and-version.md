# 05: README, smoke checklist, and version 0.3.0

**What to build:** A user reading the README learns to run the setup skill instead of pasting a template, sees one example of a generated section copied from real output, and finds the status subcommand and ADR-0002 referenced where the old snippet and template were. The manual smoke checklist covers what the tests cannot reach: setup on a bare repo, setup on a repo with a hand-edited section, and one delegation driven by a generated section. The plugin manifest reads 0.3.0 and the update check still passes.

**Blocked by:** 04 (Setup skill re-run keeps hand edits)

**Status:** ready-for-agent

**Implementation:** delegate the build to an Agent-tool subagent with `model: "opus"`. The main session runs on Fable and only plans, reviews the subagent's diff, and checks the acceptance criteria. Spec: `.scratch/codex-delegation-setup/spec.md`. Governing decisions: ADR-0001, ADR-0002.

- [x] The paste-in routing table template is gone; the routing section says to run the setup skill and shows one example section copied from real output
- [x] The README says the skill carries mechanics and the section carries behaviour, with a pointer to ADR-0002
- [x] The smoke checklist gains the three setup cases
- [x] Plugin manifest version is 0.3.0 and the update check reports the plugin current
- [x] The full manual smoke checklist has been run once in a disposable repo before the bump, with results recorded as a comment on this ticket

## Comments

- 2026-09-20: built on branch `feat/codex-delegation-setup`. `plugins/codex-subagent/README.md`: the
  "Suggested CLAUDE.md routing table" section — the paste-in template and the threshold paragraph
  after it — is replaced by "The repo's Codex delegation section", which says to run
  `/codex-subagent:setup-codex-delegation` once per repo, lists what the interview asks for in order, shows one
  example section copied verbatim from a real run today (the bare-repo case below, every
  recommendation accepted, so it names `gpt-5.6-sol`), states that the skill carries the mechanics
  and the section carries the behaviour — pause rule, stop after review, threshold, cap, what Codex
  cannot run — with a pointer to `docs/adr/0002-skill-carries-mechanics-repo-carries-behaviour.md`,
  and says the section is plain markdown to hand-edit and that a re-run rewrites only the lines the
  skill owns. Stale statements fixed: the intro now reads "two skills and one shell wrapper"; Install
  names the setup skill; Invoke lists `/codex-subagent:setup-codex-delegation` and notes it runs only when asked by
  name; the Review section's close is now "A review edits nothing: the run leaves the tree
  untouched", with the stop attributed to the repo's section rather than the skill. Grepped the file
  for "propose", "go-ahead", "stop" and "threshold": the remaining mentions are the interview
  question about the pause rule, the example section's own lines, the boundary paragraph, and the
  status check's "holds no threshold" — all consistent with the boundary. "No file in the plugin
  names a model" became "Nothing the plugin runs names a model: no wrapper default, no skill
  default", since the example section names the model the dry run chose. The status-check section and
  the exit-code table (ticket 01's) read correctly and are untouched. The root `README.md` had the
  same two stale claims ("one skill", "a routing table to paste") and now points at the generated
  section. "Verified against codex-cli 0.155.1" stays: `bash .claude/skills/check-codex-updates/check.sh`
  run today reports no help drift and 0.155.1 as the newest published release, exit 0.
- 2026-09-20: `case_plugin_names_no_model` in `tests/run-tests.sh` grepped all of `plugins/` for
  `gpt-`, which the README's example section now trips. The spec wants the example copied from real
  output, and a placeholder would make it dishonest, so the test was narrowed to the files the plugin
  actually runs — `scripts/`, `skills/`, `.claude-plugin/` — with a comment saying why the README is
  excluded: an example in prose starts no run, a model name in the wrapper or a skill would. README
  is the only file under `plugins/` the narrowed grep no longer covers. `bash tests/run-tests.sh`
  reports PASS: 311 FAIL: 0, and `grep -rn 'gpt-' plugins/` hits only the four example table rows in
  `plugins/codex-subagent/README.md`.
- 2026-09-20: manual smoke checklist, run before the bump in a disposable git repo at
  `<scratchpad>/disposable-05` (one seed commit, `notes.txt` and `hello.py`). Runs used the wrapper
  directly against the real Codex, `--model gpt-5.6-sol --effort low` unless noted, one-line prompts.
  Run directories are under `/var/folders/f8/rxr5rt517xj0ffgj45w23ncm0000gn/T/codex-subagent/`.

  | Item | Result | Run dir or reason |
  | --- | --- | --- |
  | Install from the marketplace | pass, from the local path | `claude plugin marketplace add <repo>` then `claude plugin install codex-subagent@codex-subagent`, both exit 0, run with `CLAUDE_CONFIG_DIR` pointed at a scratch config so the user's global install (0.2.3, from GitHub) was not touched. `claude plugin details` there lists Skills (2): `codex-subagent`, `setup`. After the bump, `claude plugin marketplace update` + `claude plugin update` moved that install 0.2.3 → 0.3.0. `claude plugin validate` passes on both manifests (author/description warnings only) |
  | The short form `/codex-subagent` resolves | unchecked | needs a live Claude session on an installed 0.3.0; the session running this work has 0.2.3 from the GitHub marketplace |
  | `/codex-subagent:setup-codex-delegation` on a repo with no `CLAUDE.md` | pass, prose executed by hand | preflight printed `codex-cli 0.155.1` and `Logged in using ChatGPT`; `curl -sL https://developers.openai.com/codex/models` returned 200 (~648 KB) listing `gpt-6-astra`, `gpt-5.6-sol`, `gpt-5.6-terra`, `gpt-5.6-luna`, `gpt-5.5`, `gpt-5.4`, `gpt-5.4-mini`; config default `gpt-5.6-sol` / `high`. Neither `CLAUDE.md` nor `AGENTS.md` existed, so the skill asks which to create and the run chose `CLAUDE.md`. Every recommendation accepted (config default for all four rows; high/medium/high/high; straight delegation; 3 minutes; nothing Codex cannot run; cap 2). `CLAUDE.md` was the only file written, one top-level `## Codex delegation` heading, no environment line. That file is the README's example, verbatim |
  | `/codex-subagent:setup-codex-delegation` re-run keeps hand edits | pass, prose executed by hand | same repo, section hand-edited first: `## Build` before and `## Release` after it, the review row's label reworded to "findings on a diff, severity first", an added "Changelog drafting" row, a hand-written `secrets/` paragraph, and the threshold edited to 90 seconds. Step 3 read the current values off the section (straight delegation, 90 seconds, cap 2, no environment line) and passed over the reworded and added rows; the interview changed one answer, the research row's model to `gpt-6-astra`. The diff is exactly that one row line, its Model and Invocation cells; every hand edit and both neighbouring sections survive, and `grep -c '^## Codex delegation'` is 1 |
  | One delegation driven by a row of the generated section | pass | the generated research row, `--model gpt-5.6-sol --effort medium --read-only`, exit 0, `20260920-215941-27891-H059Jw`, final message `print("hi")`, tree unchanged |
  | A `--read-only` run changes nothing | pass | `20260920-215621-23861-JEuDI0`, exit 0, `final-message.md` is `OK`, `git status --porcelain` unchanged |
  | A workspace-write run makes a small edit and runs a check | pass | `20260920-215632-24286-Y3ieRE`, exit 0, appended "second line" to `notes.txt` and reported the output of `cat notes.txt`; `git status` shows `M notes.txt` |
  | A live web search works | pass | `20260920-215649-24734-kngnG6`, exit 0, read-only, returned Reuters' top headline dated 2026-09-20; `events.jsonl` carries 14 `web_search` events |
  | A review of uncommitted changes returns findings and edits nothing | pass | `20260920-215732-25186-bx3QYY`, exit 0, `review-scope` records `--uncommitted` / `delivered-as: instructions`, findings returned, `git status` and `notes.txt`'s checksum identical before and after |
  | A resume continues a thread | pass | thread opened at `20260920-215807-25802-duEEuf` (`thread-id` `01a0c254-1c23-7851-99e6-1de3fe484772`); the resume at `20260920-215817-26221-2YwQkR` answered `41`, the number the first run was asked to remember, exit 0, no `resume-fallback` |
  | A read-only thread resumed with `--read-only` cannot write; without it can | pass | with the flag, `20260920-215830-26601-J1Lo2L`, exit 0, final message "Write failed: the workspace is read-only." and no `ro-test.txt`; same thread without the flag, `20260920-215843-26990-c61BlD`, exit 0, "Write succeeded." and `ro-test.txt` holds `written` |
  | A bad model name surfaces as a failure with a log tail | pass | `--model gpt-9-nope`, `20260920-215900-27383-odn4DH`, exit 1, `exit-code` 1, `progress.log` empty as documented, `events.jsonl` tail carries the 400 "The 'gpt-9-nope' model is not supported…"; `status <run dir>` reports "exited, exit code 1" and prints that tail |

- 2026-09-20: not verified. The two live-session items above — the short form resolving and
  `/codex-subagent:setup-codex-delegation` invoked as a slash command — cannot be observed until 0.3.0 is installed in
  a session; the setup cases were executed as prose by hand instead, the way tickets 03 and 04 did.
  The GitHub marketplace form of the install is likewise unverified on this branch: it resolves the
  default branch, which is still 0.2.3 until this merges. Every criterion is ticked; the `Status:`
  line is left at `ready-for-agent` for the orchestrator.
- 2026-09-20: the "short form resolves / setup invoked as a slash command" gap was closed for the setup skill by a headless `--plugin-dir` session; see ticket 03. The `/codex-subagent` short form was not re-checked, since that skill is unchanged in layout since 0.2.3.
- 2026-09-20: a Codex review of the branch (`review --base main`, run through the wrapper) raised six P2 findings; five were validated and fixed: status reports a run directory that holds the prompt but no pid yet as not started instead of refusing it; the setup skill matches the heading as a whole line and adds back an owned line the user deleted; the delegating skill names AGENTS.md beside CLAUDE.md and defers the sandbox choice to the routing row. Left as designed: the skill still dispatches runs in the background.
