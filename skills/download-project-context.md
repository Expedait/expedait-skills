# Skill: Download Project Context

## When to Use

You need all specification pages for a project to implement or review code. This gives you the full context in one command.

## Prerequisites

- [Expedait CLI](https://github.com/Expedait/expedait-cli) — run via `uvx expedait-cli` (no install needed)
- Know the project ID (use `expedait-cli projects list` to find it), or initialize a project first with `uvx expedait-cli init`

## Steps

### 1. Initialize the project (first time only)

```bash
uvx expedait-cli init
```

This creates `.expedait/settings.json` with your tenant and project IDs. After init, commands automatically use the stored project context.

### 2. Find the project

```bash
uvx expedait-cli projects list
```

Output (auto-detects format — text in terminal, JSON when piped):
```json
[
  {"id": 1, "name": "My SaaS App", "type": "SaaS"},
  {"id": 2, "name": "Data Pipeline", "type": "Data Processing"}
]
```

### 3. Download all pages

```bash
uvx expedait-cli projects download PROJECT_ID
```

Downloads to `.expedait/context/` by default. This extracts a ZIP containing:
- One `.md` file per page, organized by phase
- A `README.md` with project metadata
- Any file attachments in a `files/` subdirectory

### 4. Read the specs

The extracted files are plain markdown. Read them to understand the project requirements before implementing.

```bash
ls .expedait/context/
# 01-conceptualization/
#   product-vision.md
#   lean-canvas.md
# 02-definition-ux/
#   prd.md
#   brd.md
#   user-persona.md
# README.md
```

## Alternative: Download a single page

If you only need one page:

```bash
# Print markdown content to stdout
uvx expedait-cli pages get PAGE_ID

# Get full context (content + comments + dependencies + lock status)
uvx expedait-cli pages full PAGE_ID

# Download as ZIP
uvx expedait-cli pages download PAGE_ID
```

## Tips

- Output format auto-detects: text for terminal, JSON when piped. Use `--format json` to force JSON output
- The `uvx expedait-cli pages full` command includes dependency information — useful for understanding page relationships
- Page content may reference images via `![name](/api/v1/pages/files/{file_id})` — these are included in the ZIP download
- Settings are resolved in order: CLI flag → environment variable → local `.expedait/settings.json` → `~/.expedait/config.json`
