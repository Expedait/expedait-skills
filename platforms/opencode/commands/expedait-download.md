---
description: "Download the spec context for an Expedait project — objectives, deliverables, and their LLM context. Use this skill whenever the user mentions Expedait specs, project requirements, downloading context, or needs to understand what a project is about before implementing or reviewing code. Also trigger when the user asks to 'get the specs', 'fetch the deliverables', 'pull the project context', or 'download the objectives'."
subtask: true
---

# Download Project Context from Expedait

Run the CLI via `uvx --from expedait-cli expedait` — it runs in an isolated environment via uv, so no global install or virtual environment is needed.

Expedait's spec model is organized around four primitives:

- **Objectives** — top-level goals. An objective is itself a deliverable that nests child deliverables under it (`parent_deliverable_id`).
- **Deliverables** — the individual spec documents (product vision, PRD, BRD, persona, architecture, …). This is what used to be called a "page".
- **Context** — the assembled LLM context for a deliverable: its dependency deliverables, linked external sources (Notion, GitHub, …), and uploaded context files.
- **Review** — scoring findings raised against a deliverable. See `/expedait-review`.

## Steps

1. Authenticate (first time only — credentials are cached in `~/.expedait/config.json`):
   ```bash
   uvx --from expedait-cli expedait auth login
   uvx --from expedait-cli expedait status        # confirm user, tenant, workspace
   ```

2. If no project ID/name was given via $ARGUMENTS, list available projects:
   ```bash
   uvx --from expedait-cli expedait projects list
   ```
   `PROJECT` can be a numeric ID, a name (or substring), or omitted for interactive selection.

3. Download the full context snapshot for coding agents:
   ```bash
   uvx --from expedait-cli expedait projects context PROJECT
   ```
   Writes to `.expedait/context/` by default (`--output-dir` to change). The snapshot
   includes one markdown file per deliverable, grouped by phase, plus per-deliverable
   JSON (comments, dependencies, history) from the full endpoint. Use
   `--without-full-pages` for a lighter, content-only snapshot.

4. Read the downloaded deliverables in `.expedait/context/` to understand the project before implementing.

## Drilling into a single deliverable

```bash
# List the deliverables in a project
uvx --from expedait-cli expedait deliverables list --project-id PROJECT_ID

# Print one deliverable's markdown content
uvx --from expedait-cli expedait deliverables get DELIVERABLE_ID

# Pull specific sections (content, score, template, requirements, dependencies, …)
uvx --from expedait-cli expedait deliverables get DELIVERABLE_ID --include content,score,dependencies

# Full context: content + comments + dependencies + lock status
uvx --from expedait-cli expedait deliverables inspect DELIVERABLE_ID

# Just the assembled LLM context (dependency deliverables, external sources, files)
uvx --from expedait-cli expedait context get DELIVERABLE_ID
```

## Working with objectives

```bash
# An objective's full descendant tree (child deliverable ids, titles, states, scores)
uvx --from expedait-cli expedait objectives overview DELIVERABLE_ID
```

## Tips

- Output format auto-detects: text in a terminal, JSON when piped. Use `--format json` to force JSON.
- `deliverables inspect` and `context get` are the richest single-call reads — they include dependency relationships, so you understand how deliverables reference each other.
- Settings resolution order: CLI flag → environment variable (`EXPEDAIT_TOKEN`, `EXPEDAIT_API_URL`, `EXPEDAIT_TENANT_ID`) → `~/.expedait/config.json`.
- Prefer the hosted MCP server (`https://mcp.expedait.org`) when your AI client supports connectors — it exposes the same primitives without the CLI.
