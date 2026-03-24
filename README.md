# Expedait Skills

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Step-by-step guides for AI coding agents that use [Expedait](https://expedait.com) to manage project specifications.

## Quickstart

1. Install the [Expedait CLI](https://github.com/Expedait/expedait-cli):

```bash
pip install expedait-cli
```

2. Authenticate:

```bash
# Interactive login
expedait auth login

# Or set environment variables (for CI / agent environments)
export EXPEDAIT_TOKEN="your-jwt-token"
export EXPEDAIT_API_URL="https://your-instance.expedait.com"
export EXPEDAIT_TENANT_ID=1
```

3. Use a skill — for example, download all project specs:

```bash
expedait projects list --format json
expedait projects download 1 --output-dir ./specs
```

## Available Skills

| Skill | Description |
|-------|-------------|
| [Download Project Context](skills/download-project-context.md) | Download all spec pages for a project |
| [Post a Comment](skills/post-comment.md) | Post an inline comment on a spec page |
| [Review and Comment](skills/review-and-comment.md) | End-to-end: read specs, review code, post comments |

## What are Skills?

Skills are structured, agent-oriented guides that describe how to accomplish common workflows using the Expedait CLI. Each skill includes:

- **When to use** — the situation the skill addresses
- **Prerequisites** — what you need before starting
- **Step-by-step instructions** — CLI commands with example output
- **Tips** — best practices and edge cases

They are designed to be consumed by AI coding agents (Claude Code, Cursor, Windsurf, Copilot, etc.) as part of their tool documentation, but are also useful as human reference.

## Using Skills with Claude Code

Add the skills directory to your project's `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": ["Bash(expedait *)"]
  }
}
```

Then reference the skill files in your prompts or CLAUDE.md:

```markdown
## Expedait Integration

See [expedait-skills](https://github.com/Expedait/expedait-skills) for agent workflows:
- Download specs before implementing: skills/download-project-context.md
- Post comments when code diverges from spec: skills/post-comment.md
- Full review workflow: skills/review-and-comment.md
```

## Contributing

Contributions are welcome! To add a new skill:

1. Create a markdown file in `skills/` following the existing format
2. Add it to the table in this README
3. Submit a pull request

## License

This project is licensed under the [Apache License 2.0](LICENSE).
