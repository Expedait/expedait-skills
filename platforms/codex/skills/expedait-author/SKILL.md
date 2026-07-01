---
name: expedait-author
description: "Author and edit Expedait deliverables — create a new spec document, draft or fill in its content, rename it, snapshot a version, or change its state. Use this skill whenever the user wants to write a deliverable, draft a PRD/vision/persona/architecture doc, fill in a spec from the template, update a deliverable's content, add a child deliverable under an objective, save a version, or move a deliverable to Review/Approved/Completed. Also trigger for 'write the PRD', 'draft the product vision', 'create a deliverable', 'edit the spec', 'snapshot this version', or 'mark the deliverable approved'."
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep
argument-hint: [deliverable id or what to write]
---

# Author & Edit Expedait Deliverables

A **deliverable** is an Expedait spec document. This skill creates and edits its content, not
just reads it.

## Transport: MCP or CLI (same op model, pick what you have)

Authoring runs over either of two transports, at parity:

- **MCP tools** (`expedait:*`, hosted at `https://mcp.expedait.org`) — **prefer these when
  they're in your tool list.** No install, no cold start, and args are structured/validated,
  so you never hand-escape the ops JSON in a shell. Writing needs the `mcp:deliverables:write`
  scope.
- **The `expedait` CLI** — the fallback that works in any agent with a shell. Runs in an
  isolated uv environment (no global install): `uvx --from expedait-cli expedait <command>`.
  Authenticate once with `uvx --from expedait-cli expedait auth login`.

Detection rule: if the `expedait:*` tools appear in your tool list, use them; otherwise use
the CLI. **The op model is identical on both** — the same `ops` array with `$last` / `@ref`
chaining. Only the invocation envelope differs, as the table below shows. Pass the project per
command (by id or name); on the CLI you can run `expedait init` once to write
`.expedait/settings.json` so `--project` defaults for this directory.

## First: check for skill updates

Run this once, before anything else. It's throttled (hits the network at most once a day),
non-blocking, and silent when you're current or offline — never let it delay or abort the task.

```bash
{ _S="$HOME/.expedait"; [ "${EXPEDAIT_SKILLS_UPDATE_CHECK:-}" != "false" ] && [ ! -f "$_S/no-update-check" ] && {
  mkdir -p "$_S"
  if [ -z "$(find "$_S/update-check" -mmin -1440 2>/dev/null)" ]; then
    touch "$_S/update-check"
    _L=$(cat .expedait-skills-version 2>/dev/null || echo unknown)
    _R=$(curl -fsSL --max-time 3 https://api.github.com/repos/Expedait/expedait-skills/releases/latest 2>/dev/null | grep -o '"tag_name":"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/^v//')
    printf '%s %s\n' "${_L:-unknown}" "${_R:-}" > "$_S/update-check.last"
  fi
  read -r _L _R < "$_S/update-check.last" 2>/dev/null || true
  [ -n "${_R:-}" ] && [ "$_L" != "$_R" ] && [ "$(printf '%s\n%s\n' "$_L" "$_R" | sort -V | tail -1)" = "$_R" ] && echo "EXPEDAIT_UPDATE_AVAILABLE $_L $_R"
}; } 2>/dev/null || true
```

If it prints `EXPEDAIT_UPDATE_AVAILABLE <local> <latest>`, mention it once — "Expedait skills
v<latest> is available (you're on v<local>); run `/expedait-update-skills` to update" — then
carry on with the task below. If it prints nothing, say nothing and proceed.

## Commands at a glance — MCP tool ↔ CLI command

CLI commands are prefixed with `uvx --from expedait-cli expedait`. MCP tool names are
`ServerName:tool`, where the server is `expedait`.

| Goal | MCP tool | CLI command |
|------|----------|-------------|
| Read a type's template + requirements before writing | `expedait:get_deliverable(id, include=["meta","template","requirements","writer_instructions"])` | `deliverables get ID --include meta,template,requirements,writer_instructions` |
| Assembled upstream context this one depends on | `expedait:get_deliverable_context(id)` | `context get ID` |
| Find the type id for a new deliverable | *(CLI only)* | `deliverables types` |
| **Create / edit / rename / snapshot / set-state (atomic)** | `expedait:write_deliverable(ops=[…])` | `deliverables write --ops -` |
| Create a deliverable (ergonomic) | via `expedait:write_deliverable` `create` op | `deliverables create --project ID --type TYPE_ID --title "…" --content @file` |
| Edit content (autosave, no version bump) | via `edit` op | `deliverables edit ID --content @file` |
| Rename | via `rename` op | `deliverables rename ID --title "…"` |
| Snapshot a restorable version | via `save_version` op | `deliverables save-version ID --reason "…"` |
| Change state | via `set_state` op | `deliverables set-state ID --state "Review"` |

## Always read before you write

A good deliverable follows its type's template and satisfies its requirements. Pull that
context first so what you write actually fits — the template structure, the bar it's scored
against, how to write it, and the upstream deliverables this one depends on:

- **MCP:** `expedait:get_deliverable(id, include=["meta","template","requirements","writer_instructions"])`,
  then `expedait:get_deliverable_context(id)`. For an existing deliverable, `expedait:get_deliverable(id, include=["content"])`.
- **CLI:**
  ```bash
  uvx --from expedait-cli expedait deliverables get DELIVERABLE_ID \
    --include meta,template,requirements,writer_instructions
  uvx --from expedait-cli expedait context get DELIVERABLE_ID
  uvx --from expedait-cli expedait deliverables get DELIVERABLE_ID --include content   # if editing
  ```

Read the upstream dependencies before drafting so you stay consistent with them.

## Finding the ids you need

`create` needs a project id and a deliverable **type** id — look them up, don't guess.
On MCP: `expedait:list_projects()`, then `expedait:list_deliverables(project_id)` and `expedait:get_objective_overview(id)`
to place a child under an objective. On the CLI:

```bash
uvx --from expedait-cli expedait projects list                  # project id
uvx --from expedait-cli expedait deliverables types             # the --type id for create
uvx --from expedait-cli expedait deliverables list --project-id PROJECT_ID
# Nesting under an objective? its descendant tree gives the parent id:
uvx --from expedait-cli expedait objectives overview OBJECTIVE_DELIVERABLE_ID
```

## Write — the atomic op model (identical on both transports)

Create-then-fill-then-snapshot in one atomic call with an ordered `ops` array. Chain on a fresh
deliverable with `id: "$last"`, or bind `ref` on a create and reference `id: "@name"` later.
The op set is the same everywhere: `create` / `edit` / `rename` / `save_version` / `set_state`.
Ops execute in order; if one fails the rest are skipped and the result reports per-op
`{status: ok | error | skipped}`.

The `ops` array is the same JSON on both transports:

```json
[
  {"op": "create", "project_id": 7, "deliverable_type_id": 12, "title": "Auth PRD"},
  {"op": "edit", "id": "$last", "content": "## Goals\n\n## Requirements\n"},
  {"op": "save_version", "id": "$last", "reason": "first complete draft"},
  {"op": "set_state", "id": "$last", "state": "Review"}
]
```

- **MCP (preferred):** `expedait:write_deliverable(ops=[…])` — pass the array as a structured argument,
  no shell escaping.
- **CLI:** `deliverables write --ops -` and feed the array on stdin (or `@file.json`, or an
  inline string):
  ```bash
  uvx --from expedait-cli expedait deliverables write --ops - <<'JSON'
  [
    {"op": "create", "project_id": 7, "deliverable_type_id": 12, "title": "Auth PRD"},
    {"op": "edit", "id": "$last", "content": "## Goals\n\n## Requirements\n"},
    {"op": "save_version", "id": "$last", "reason": "first complete draft"},
    {"op": "set_state", "id": "$last", "state": "Review"}
  ]
  JSON
  ```

Valid states for `set_state`: `Not Started`, `In Progress`, `Review`, `Approved`,
`Completed`, `Final`.

## Write — ergonomic single steps (CLI)

When you're not chaining, the CLI has one-shot subcommands (each maps to a single op above):

```bash
# Create (content accepts @file, - for stdin, or a literal string)
uvx --from expedait-cli expedait deliverables create \
  --project PROJECT_ID --type TYPE_ID --title "Auth PRD" --content @draft.md \
  [--parent-deliverable-id OBJECTIVE_INSTANCE_ID]

uvx --from expedait-cli expedait deliverables edit DELIVERABLE_ID --content @draft.md   # autosave, no version bump
uvx --from expedait-cli expedait deliverables rename DELIVERABLE_ID --title "New title"
uvx --from expedait-cli expedait deliverables save-version DELIVERABLE_ID --reason "first complete draft"
uvx --from expedait-cli expedait deliverables set-state DELIVERABLE_ID --state "Review" --reason "ready for review"
```

Over MCP, do the same single steps as a one-op `expedait:write_deliverable(ops=[{...}])` call.

## Tips

- **`edit` vs `save_version`.** `edit` autosaves without bumping the version; `save_version`
  makes a named, restorable snapshot. Draft with `edit`, snapshot at milestones.
- **Locks & state legality.** The backend re-checks lock status and whether a state
  transition is legal; a rejected op surfaces as an error — re-read the deliverable and retry.
  Don't fight another editor's lock; surface it to the user.
- **Verify** after writing: read back `content` and `score` (`expedait:get_deliverable(id, include=["content","score"])`
  or `deliverables get ID --include content,score`) — `score` shows how the new content
  measures against the type's requirements once scoring runs.
- If the `expedait:*` tools aren't in your tool list, the connector isn't attached — use the
  CLI. CLI output auto-detects (text in a terminal, JSON when piped; `--format json` to force).
- Reviewing instead of writing? Use `/expedait-review`. Commenting? Use `/expedait-comment`.
