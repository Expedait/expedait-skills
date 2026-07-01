# Contributing to Expedait Skills

Thanks for helping improve the Expedait agent skills. This repo holds step-by-step
guides that AI coding agents use to drive the Expedait CLI and MCP server.

By participating, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## Architecture

Skills are authored **once** in `skills/*/SKILL.md` — the single source of truth — and
transformed into platform-specific formats (`platforms/`) by `build.py`. Never edit files
under `platforms/` by hand; they are generated and CI checks that they stay in sync.

```
skills/                     # canonical source (SKILL.md format) — edit here
  expedait-download/SKILL.md
  expedait-author/SKILL.md
  expedait-process/SKILL.md
  expedait-comment/SKILL.md
  expedait-review/SKILL.md
platforms/                  # generated — do not edit directly
```

## Making a change

1. Edit the relevant `skills/*/SKILL.md` (add a new directory for a new skill).
2. Regenerate the platform files:
   ```bash
   uv run build.py
   ```
3. If you added or renamed a skill, update the table in `README.md`.
4. Commit **both** the `skills/` change and the regenerated `platforms/` directory.
5. Run the eval battery's fast tier locally (see below).
6. Open a pull request. CI (`check-sync.yml`) fails if `platforms/` is out of sync with
   `skills/`, `check-evals.yml` runs the static lint + unit tests, and `test-install.yml`
   smoke-tests the installer.

## Testing

The [`evals/`](evals/) directory holds a local battery that checks **which `expedait`
commands each skill leads an agent to run**, against a hermetic mock CLI. Before opening a
PR, run the agent-free tier:

```bash
python3 evals/lint.py                    # static frontmatter/body checks
uv run --with pytest pytest evals/       # unit tests for the grader + lint
python3 evals/runner.py --dry-run        # validate eval schema + mock wiring
```

If you change a skill's commands, add or update its cases in `evals/<skill>/evals.json`
and, when you have the `claude` CLI available, run the full battery:
`python3 evals/runner.py --skill <skill>`. See [`evals/README.md`](evals/README.md).

## Authoring guidelines

Skills follow [Anthropic's skill-authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices). In short:

- **Frontmatter.** `name` is lowercase-hyphen, ≤64 chars, no reserved words
  (`anthropic`, `claude`). `description` is third person, ≤1024 chars, and states both
  **what** the skill does and **when** to trigger it (include natural-language trigger phrases).
- **Body.** Keep `SKILL.md` under 500 lines. Be concise — assume the agent is already
  capable and only add context it doesn't have.
- **No time-sensitive phrasing.** Avoid version-pinned notes ("as of CLI 0.4.0…") and
  migration cruft ("formerly a page") that will age. State current behavior plainly.
- **MCP tool references** are fully qualified as `ServerName:tool` (the server is `expedait`),
  e.g. `expedait:write_deliverable`.
- **Paths** use forward slashes. **Terminology** stays consistent across skills.

### Write for the cheapest model you ship to

If a small model (e.g. Haiku) can't reliably use a skill, the skill isn't clear enough —
fix the skill, not the model. The eval battery runs on Haiku for exactly this reason. Two
patterns that measurably improved trigger + execution reliability here:

- **Front-load the full command surface.** Put a "Commands at a glance" table near the top
  so the whole capability is visible immediately. A capability buried in a conditional step
  (e.g. `projects list` inside "if no project was given") gets missed — a cheap model
  concluded the download skill "can't list projects" even though it could.
- **State the execution path once, up front:** "This skill drives the `expedait` CLI over
  Bash — no MCP tool required." Without it, models sometimes punt with "I can't invoke MCP
  tools." Keep the MCP-alternative section, but lead with the CLI.

These echo Anthropic's "concise, discoverable" guidance and Matt Pocock's
[writing-great-skills](https://github.com/mattpocock/skills) (front-load leading words,
give each step a checkable completion criterion).

## Before you change a skill's commands

Verify the `expedait-cli` surface first — the published CLI can lead the READMEs:

```bash
uvx --from expedait-cli expedait --help
uvx --from expedait-cli expedait <command> --help
```

Keep the skills' vocabulary aligned with the spec model's four primitives —
**objectives**, **deliverables**, **context**, and **review**.

## Releasing

Maintainers release by bumping the version in both `.claude-plugin/plugin.json` and the
`VERSION` variable in `install.sh` (CI enforces they match the tag), committing, then
pushing a semver tag: `git tag v<version> && git push --tags`. Pushing a `v*` tag triggers
`.github/workflows/publish.yml`, which creates the GitHub release.

## License

By contributing, you agree that your contributions are licensed under the
[Apache License 2.0](LICENSE).
