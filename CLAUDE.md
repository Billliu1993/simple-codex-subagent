## Agent skills

### Issue tracker

Issues live as local markdown files under `.scratch/<feature>/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### Claude delegation

When an Agent-tool subagent would run on Fable, pass `model: "opus"` so it runs on Opus instead.

## Documentation Style

- Write each prose paragraph or list item on a single physical line; do not hard-wrap sentences to a fixed column.
- Keep structural line breaks for headings, lists, tables, and fenced code blocks.
