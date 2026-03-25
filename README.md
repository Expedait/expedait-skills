# Expedait Skills

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Step-by-step guides for AI coding agents that use [Expedait](https://expedait.com) to manage project specifications.

## Quickstart

### 1. Install skills into your project

**Claude Code plugin** (recommended):

```bash
/plugin marketplace add Expedait/expedait-skills
/plugin install expedait-skills@expedait
```

**Script installer** (Claude Code, Cursor, OpenCode, Codex, Gemini CLI):

```bash
curl -fsSL https://raw.githubusercontent.com/Expedait/expedait-skills/main/install.sh | bash
```

The script installer auto-detects your agent and sets up the right config files. See [Agent Setup](#agent-setup) for manual instructions.

### 2. Authenticate and initialize

The CLI runs via [`uvx`](https://docs.astral.sh/uv/) — no global install needed:

```bash
# Interactive login
uvx expedait-cli auth login

# Check auth status
uvx expedait-cli auth status

# Or set environment variables (for CI / agent environments)
export EXPEDAIT_TOKEN="your-jwt-token"
export EXPEDAIT_API_URL="https://your-instance.expedait.com"
export EXPEDAIT_TENANT_ID=1
```

Then initialize your project directory:

```bash
uvx expedait-cli init
```

This creates `.expedait/settings.json` with your tenant and project IDs. Settings are resolved in order: CLI flag → environment variable → local config → home directory config.

### 3. Use a skill

Ask your agent to download specs, post comments, or review code — it knows the workflows.

```
> /expedait-download     # Claude Code
> @expedait-download     # Cursor (manual rule invocation)
```

Or just ask naturally: *"Download the specs for project 1 and review my code against them."*

## Available Skills

| Skill | Description |
|-------|-------------|
| [Download Project Context](skills/download-project-context.md) | Download all spec pages for a project |
| [Post a Comment](skills/post-comment.md) | Post an inline comment on a spec page |
| [Review](skills/review-and-comment.md) | Check PRD/vision alignment against code — scopes to branch changes or full audit |

## Agent Setup

### Claude Code (Plugin)

Install as a Claude Code plugin — no manual file setup needed:

```bash
/plugin marketplace add Expedait/expedait-skills
/plugin install expedait-skills@expedait
```

This registers the marketplace and installs the skills as `/expedait-download`, `/expedait-comment`, and `/expedait-review`.

Teams can also auto-enable the plugin by adding to `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "expedait": {
      "source": {
        "source": "github",
        "repo": "Expedait/expedait-skills"
      }
    }
  },
  "enabledPlugins": {
    "expedait-skills@expedait": true
  }
}
```

### Claude Code (Script)

The installer creates skills as custom slash commands in `.claude/skills/`:

```
.claude/skills/
  expedait-download/SKILL.md
  expedait-comment/SKILL.md
  expedait-review/SKILL.md
```

These become available as `/expedait-download`, `/expedait-comment`, and `/expedait-review`.

**Manual setup:**

```bash
./install.sh --agent claude-code
```

Or add to your `CLAUDE.md`:

```markdown
## Expedait Integration

Use `uvx expedait-cli` (not `pip`) for all Expedait commands.
Run `uvx expedait-cli init` to initialize a project directory.
See the skills in `.claude/skills/expedait-*` for workflows.
```

### Cursor

The installer creates a rule file at `.cursor/rules/expedait.mdc`:

```yaml
---
description: "Expedait spec management — download specs, post comments, review code"
alwaysApply: false
---
```

Cursor's agent will pick it up automatically when Expedait-related questions come up, or you can invoke it manually with `@expedait`.

**Manual setup:**

```bash
./install.sh --agent cursor
```

### OpenCode

The installer creates commands in `.opencode/commands/` using the native command format:

```bash
./install.sh --agent opencode
```

```
.opencode/commands/
  expedait-download.md
  expedait-comment.md
  expedait-review.md
```

These become available as `/expedait-download`, `/expedait-comment`, and `/expedait-review`.

### Codex (OpenAI)

The installer creates skills in `.codex/skills/` using the native SKILL.md format:

```bash
./install.sh --agent codex
```

```
.codex/skills/
  expedait-download/SKILL.md
  expedait-comment/SKILL.md
  expedait-review/SKILL.md
```

### Gemini CLI

The installer creates custom commands in `.gemini/commands/` using the native TOML format:

```bash
./install.sh --agent gemini
```

```
.gemini/commands/
  expedait-download.toml
  expedait-comment.toml
  expedait-review.toml
```

These become available as `/expedait-download`, `/expedait-comment`, and `/expedait-review`.

### All agents at once

```bash
./install.sh --all
```

## What are Skills?

Skills are structured, agent-oriented guides that describe how to accomplish common workflows using the Expedait CLI. Each skill includes:

- **When to use** — the situation the skill addresses
- **Prerequisites** — what you need before starting
- **Step-by-step instructions** — CLI commands with example output
- **Tips** — best practices and edge cases

They are designed to be consumed by AI coding agents (Claude Code, Cursor, OpenCode, Codex, etc.) as part of their tool documentation, but are also useful as human reference.

## Architecture

Skills are defined once in `skills/*/SKILL.md` (the single source of truth) and transformed into platform-specific formats by `build.py`:

```
skills/                        # canonical source (SKILL.md format)
  expedait-download/SKILL.md
  expedait-comment/SKILL.md
  expedait-review/SKILL.md

platforms/                     # generated — do not edit directly
  codex/skills/*/SKILL.md     # same format as Claude Code
  opencode/commands/*.md       # OpenCode command format
  gemini/commands/*.toml       # Gemini CLI TOML format
  cursor/rules/*.mdc           # Cursor rule format
```

Claude Code uses `skills/` directly (native format). Other platforms use files from `platforms/`.

## Contributing

To add or modify a skill:

1. Edit the SKILL.md in `skills/` (not in `platforms/`)
2. Run `uv run build.py` to regenerate platform files
3. Add the skill to the table in this README
4. Submit a pull request (CI checks that `platforms/` is in sync)

## License

This project is licensed under the [Apache License 2.0](LICENSE).
