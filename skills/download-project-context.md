# Skill: Download Project Context

> Canonical source: [`expedait-download/SKILL.md`](expedait-download/SKILL.md). This file is a human-readable copy.

## When to Use

You need the deliverables for a project to implement or review code. This gives you the full context in one command.

## Prerequisites

- [Expedait CLI](https://github.com/Expedait/expedait-cli) — run via `uvx --from expedait-cli expedait` (no install needed)
- Authenticated: `uvx --from expedait-cli expedait auth login`

## The spec model

Expedait organizes specs around four primitives:

- **Objectives** — top-level goals; an objective is a deliverable that nests child deliverables (`parent_deliverable_id`).
- **Deliverables** — the individual spec documents (product vision, PRD, BRD, persona, …). Formerly called "pages".
- **Context** — the assembled LLM context for a deliverable: dependency deliverables, external sources, uploaded files.
- **Review** — scoring findings on a deliverable (see the review skill).

## Steps

### 1. Authenticate (first time only)

```bash
uvx --from expedait-cli expedait auth login
uvx --from expedait-cli expedait status
```

Credentials are cached in `~/.expedait/config.json`.

### 2. Find the project

```bash
uvx --from expedait-cli expedait projects list
```

`PROJECT` can be a numeric ID, a name (or substring), or omitted for interactive selection.

### 3. Download the context snapshot

```bash
uvx --from expedait-cli expedait projects context PROJECT
```

Writes to `.expedait/context/` by default (`--output-dir` to change). The snapshot contains:
- One `.md` file per deliverable, grouped by phase
- Per-deliverable JSON (comments, dependencies, history) — omit with `--without-full-pages`

### 4. Read the deliverables

```bash
ls .expedait/context/
# 01-conceptualization/
#   product-vision.md
#   lean-canvas.md
# 02-definition-ux/
#   prd.md
#   brd.md
#   user-persona.md
```

## Drilling into a single deliverable

```bash
# Print one deliverable's markdown content
uvx --from expedait-cli expedait deliverables get DELIVERABLE_ID

# Specific sections: content, score, template, requirements, dependencies, …
uvx --from expedait-cli expedait deliverables get DELIVERABLE_ID --include content,score,dependencies

# Full context: content + comments + dependencies + lock status
uvx --from expedait-cli expedait deliverables inspect DELIVERABLE_ID

# Assembled LLM context (dependency deliverables, external sources, files)
uvx --from expedait-cli expedait context get DELIVERABLE_ID

# An objective's descendant tree
uvx --from expedait-cli expedait objectives overview DELIVERABLE_ID
```

## Tips

- Output format auto-detects: text in a terminal, JSON when piped. Use `--format json` to force JSON.
- `deliverables inspect` and `context get` include dependency relationships — useful for understanding how deliverables reference each other.
- Settings resolution order: CLI flag → environment variable → `~/.expedait/config.json`.
- The hosted MCP server (`https://mcp.expedait.org`) exposes the same primitives for AI clients that support connectors.
