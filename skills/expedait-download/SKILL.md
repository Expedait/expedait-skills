---
name: expedait-download
description: "Download all specification pages for an Expedait project. Use when you need project context, specs, or requirements before implementing or reviewing code."
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "[project-id]"
---

# Download Project Context from Expedait

Use `uvx expedait-cli` for all commands (do NOT use `pip install`).

## Steps

1. If no project ID was given via $ARGUMENTS, list available projects:
   ```bash
   uvx expedait-cli projects list --format json
   ```

2. Download all spec pages:
   ```bash
   uvx expedait-cli projects download PROJECT_ID --output-dir ./specs
   ```

3. Read the downloaded specs in `./specs/` to understand the project requirements.

## Single page alternative

```bash
# Print markdown to stdout
uvx expedait-cli pages get PAGE_ID

# Full context (content + comments + dependencies)
uvx expedait-cli pages full PAGE_ID --format json

# Download as ZIP
uvx expedait-cli pages download PAGE_ID --output-dir ./specs
```

## Tips

- Use `--format json` when piping output to other tools
- `pages full` includes dependency info — useful for understanding page relationships
- Page images referenced as `![name](/api/v1/pages/files/{file_id})` are included in ZIP downloads
