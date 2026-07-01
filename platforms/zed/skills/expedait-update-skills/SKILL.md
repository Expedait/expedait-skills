---
name: expedait-update-skills
description: "Check whether the installed Expedait skills are the latest version and update them if not. Use this skill whenever the user asks to 'update the Expedait skills', 'check for skill updates', 'am I on the latest Expedait skills', 'upgrade expedait-skills', or when another Expedait skill's update-check preamble reported EXPEDAIT_UPDATE_AVAILABLE. Compares the locally installed version against the latest GitHub release and walks through the right update path (script installer or Claude Code plugin)."
---

# Keep the Expedait skills up to date

Skills are distributed as static files (via `install.sh` or the Claude Code plugin
marketplace), so they don't update themselves — this skill checks the installed version
against the latest GitHub **release** and, if you're behind, runs the right update path.

Every other Expedait skill runs a throttled version check in its preamble; when it prints
`EXPEDAIT_UPDATE_AVAILABLE <local> <latest>`, it points here. You can also invoke this
skill directly at any time.

## Step 1 — check the version

Force a fresh check (this bypasses the once-a-day throttle used by the preambles):

```bash
_LOCAL=$(cat .expedait-skills-version 2>/dev/null || echo unknown)
_LATEST=$(curl -fsSL --max-time 8 https://api.github.com/repos/Expedait/expedait-skills/releases/latest 2>/dev/null \
  | grep -o '"tag_name":"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/^v//')
echo "installed=${_LOCAL:-unknown}  latest=${_LATEST:-unreachable}"
# Refresh the shared cache so the preambles reflect this result immediately.
mkdir -p "$HOME/.expedait" && printf '%s %s\n' "${_LOCAL:-unknown}" "${_LATEST:-}" > "$HOME/.expedait/update-check.last" && touch "$HOME/.expedait/update-check"
```

Interpret the result:

- **`latest=unreachable`** — no network / GitHub API down. Tell the user you couldn't check and stop; don't guess.
- **`installed` equals `latest`** — already current. Say so (`Up to date (vX.Y.Z)`) and stop.
- **`installed=unknown`** — the version marker file is missing. This is normal for **plugin** installs (they carry no `.expedait-skills-version`); go to Step 2 and use the plugin path. For a script install it means the marker was lost — re-running the installer (Step 2, script path) restores it.
- **`installed` older than `latest`** — an update is available. Go to Step 2.

## Step 2 — detect the install method and update

Pick the path that matches how the skills were installed:

```bash
if [ -f .expedait-skills-version ]; then echo "method=script"; else echo "method=plugin"; fi
```

Ask the user before changing anything (via AskUserQuestion when available): *"Expedait skills
v{latest} is available (you're on v{local}). Update now?"* — options: **Update now** / **Not now**.
If they decline, stop and continue with whatever they were doing.

### Script install (`install.sh`)

Re-running the installer re-copies the latest `SKILL.md` / platform files for every detected
agent and rewrites `.expedait-skills-version`. It's idempotent:

```bash
curl -fsSL https://raw.githubusercontent.com/Expedait/expedait-skills/main/install.sh | bash
```

Scope it to one agent with `| bash -s -- --agent claude-code` (or `cursor`, `gemini`, …) if
the user only wants one target. After it finishes, re-run the Step 1 check block to confirm
`installed` now equals `latest`, and refresh the cache line so the preambles go quiet.

### Claude Code plugin

Plugin-managed skills update through Claude Code, not this script. Tell the user to run:

```
/plugin marketplace update expedait
/plugin
```

Then update `expedait-skills` from the plugin manager. (These are Claude Code slash commands
the user runs themselves — you can't run them from here.)

## Step 3 — report

State the outcome plainly: the old and new version, which path was used, and — for a script
update — the confirmation from the re-check. If anything failed (network, installer error),
say so with the actual output rather than claiming success.

## Notes

- **Silence it:** `export EXPEDAIT_SKILLS_UPDATE_CHECK=false`, or `touch ~/.expedait/no-update-check`, disables the preamble checks in every skill.
- **Throttle state** lives in `~/.expedait/update-check` (last-check timestamp) and `~/.expedait/update-check.last` (cached `local latest`). Delete them to force the preambles to re-check on their next run.
- This checks the **skills package** version, not the `expedait-cli` or the product API. CLI upgrades happen automatically via `uvx --from expedait-cli expedait …`.
