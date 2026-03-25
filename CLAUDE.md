# CLAUDE.md

## Before making changes

Check if the `expedait-cli` API has changed by reviewing its PyPI page: https://pypi.org/project/expedait-cli/

Compare its latest commands, flags, and output formats against what the skills in `skills/` assume. If the CLI has changed, update the affected skills to match.

## Releasing

Tags follow semver: `v0.1.0`, `v0.2.0`, `v1.0.0`. Pushing a `v*` tag triggers `.github/workflows/publish.yml`, which publishes to npm and creates a GitHub release.

Version must be updated in two places (CI enforces they match the tag):

- `.claude-plugin/plugin.json` — Claude Code plugin version
- `install.sh` — `VERSION` variable (written to `.expedait-skills-version` on install)

To release: bump both, commit, then `git tag v<version> && git push --tags`.
