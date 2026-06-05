# CLAUDE.md

## Before making changes

Check if the `expedait-cli` API has changed. The package is `expedait-cli`; its entrypoint
is now `expedait`, so the canonical invocation is `uvx --from expedait-cli expedait`. Inspect
the live surface with:

```bash
uvx --from expedait-cli expedait --help
uvx --from expedait-cli expedait <command> --help
```

(The PyPI/GitHub READMEs can lag the published CLI — trust `--help` output.) Compare its
latest commands, flags, and output formats against what the skills in `skills/` assume. If
the CLI has changed, update the affected skills to match.

The product's spec model is built on four primitives — **objectives**, **deliverables**
(formerly "pages"), **context**, and **review** — mirrored by the hosted MCP server at
`https://mcp.expedait.org`. Keep the skills' vocabulary aligned with these.

## After modifying skills

Skills in `skills/*/SKILL.md` are the single source of truth. Platform-specific files in `platforms/` are generated. After editing any SKILL.md:

```bash
uv run build.py
```

Commit both the skill changes and the regenerated `platforms/` directory. CI will fail if they are out of sync.

## Releasing

Tags follow semver: `v0.1.0`, `v0.2.0`, `v1.0.0`. Pushing a `v*` tag triggers `.github/workflows/publish.yml`, which publishes to npm and creates a GitHub release.

Version must be updated in two places (CI enforces they match the tag):

- `.claude-plugin/plugin.json` — Claude Code plugin version
- `install.sh` — `VERSION` variable (written to `.expedait-skills-version` on install)

To release: bump both, commit, then `git tag v<version> && git push --tags`.
