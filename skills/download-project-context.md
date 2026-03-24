# Skill: Download Project Context

## When to Use

You need all specification pages for a project to implement or review code. This gives you the full context in one command.

## Prerequisites

- [Expedait CLI](https://github.com/Expedait/expedait-cli) installed and authenticated
- Know the project ID (use `expedait projects list` to find it)

## Steps

### 1. Find the project

```bash
expedait projects list --format json
```

Output:
```json
[
  {"id": 1, "name": "My SaaS App", "type": "SaaS"},
  {"id": 2, "name": "Data Pipeline", "type": "Data Processing"}
]
```

### 2. Download all pages

```bash
expedait projects download PROJECT_ID --output-dir ./specs
```

This extracts a ZIP containing:
- One `.md` file per page, organized by phase
- A `README.md` with project metadata
- Any file attachments in a `files/` subdirectory

### 3. Read the specs

The extracted files are plain markdown. Read them to understand the project requirements before implementing.

```bash
ls ./specs/
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
expedait pages get PAGE_ID

# Get full context (content + comments + dependencies + lock status)
expedait pages full PAGE_ID --format json

# Download as ZIP
expedait pages download PAGE_ID --output-dir ./specs
```

## Tips

- Use `--format json` when piping output to other tools
- The `pages full` command includes dependency information — useful for understanding page relationships
- Page content may reference images via `![name](/api/v1/pages/files/{file_id})` — these are included in the ZIP download
