---
name: expedait-process
description: "Create or adapt an Expedait process — the project-type template that every project is instantiated from: its phases, deliverable types, dependencies, and owner roles. Use this skill whenever the user wants to design a new process, set up a project template, add or reorder phases, add deliverable types/cards, wire dependencies between deliverable types, assign owner roles, define a new role, or restructure the Process Designer. Also trigger for 'create a new process', 'set up a project type', 'design the spec workflow', 'add a deliverable type to the template', or 'who owns this deliverable type'."
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "[process name or what the process should produce]"
---

# Create or Adapt an Expedait Process

A **process** is the template layer of Expedait — the project type that every project is
instantiated from. Editing a process reshapes **every** project built from it.

## Transport: MCP or CLI (same op model, pick what you have)

Process building runs over either of two transports, at parity:

- **MCP tools** (`expedait:*`, hosted at `https://mcp.expedait.org`) — **prefer these when
  they're in your tool list.** No install, no cold start, and the ops array is a structured
  argument, so you never hand-escape JSON in a shell. Writing needs the `mcp:process:write`
  scope (kept separate from `mcp:deliverables:write` on purpose — reshaping a template touches
  every project of that type).
- **The `expedait` CLI** — the fallback that works in any agent with a shell. Runs in an
  isolated uv environment (no global install): `uvx --from expedait-cli expedait <command>`.
  Authenticate once with `uvx --from expedait-cli expedait auth login`.

Detection rule: if the `expedait:*` tools appear in your tool list, use them; otherwise use the
CLI. **The op model is identical on both** — the same `ops` array with `ref` / `@ref` chaining.
Only the invocation envelope differs, as the table below shows.

Its shape:

- **Phases** — ordered stages of the process (e.g. Discovery → Definition → Design).
- **Phase rows** — optional horizontal lanes inside a phase for laying out cards.
- **Deliverable types** — the cards in each phase, each a template for a deliverable (PRD,
  vision, persona, …) with its own instructions, template content, and requirements. A card
  flagged `is_objective` owns its own **subprocess** (an inner set of phases) — that is how an
  objective nests child deliverables.
- **Dependencies** — directed edges between deliverable types (which upstream deliverables
  feed a deliverable's LLM context). Only siblings may depend on each other.
- **Owner roles** — the project role(s) responsible for each deliverable type, drawn from the
  workspace's role pool.

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
| List existing processes | `list_processes()` | `processes list` |
| Inspect a process (full tree) | `get_process(id)` | `processes get PROCESS_ID` |
| List the workspace role pool | `list_roles()` | `roles list` |
| **Build or modify a process atomically** | `write_process(ops=[…])` | `processes write --ops -` |
| Create / change roles atomically | `write_role(ops=[…])` | `roles write --ops -` |
| Create an owner role (ergonomic) | via `write_role` `create_role` op | `roles create --name "…" --instructions @file` |

## Look before you build

Reuse or extend rather than duplicate, and inspect any process you'll adapt —
`list_processes()` / `get_process(id)` (MCP) or:

```bash
uvx --from expedait-cli expedait processes list                 # id, name, description, icon
uvx --from expedait-cli expedait processes get PROCESS_ID       # full tree: phases → rows → cards, deps, owner roles, subprocesses
```

## Check (or create) the role pool

Owner roles are assigned by name or id. See what exists, and create any that don't. On the CLI:

```bash
uvx --from expedait-cli expedait roles list
uvx --from expedait-cli expedait roles create --name "Data Architect" \
  --instructions @data-architect-persona.md          # --instructions: @file, -, or literal
# update / delete also available:
uvx --from expedait-cli expedait roles update ROLE_ID --description "..."
uvx --from expedait-cli expedait roles delete ROLE_ID
```

`instructions` is the role's LLM coaching persona (the system prompt for deliverables this role
owns). For several role changes at once, use the atomic `write_role(ops=[…])` /
`roles write --ops` form (`create_role` / `update_role` / `delete_role`, chainable with
`ref` / `@ref`).

## Build the process in one write call (identical op model on both transports)

Process building is one atomic `ops` array. Ops execute in order and chain across entity kinds
via **named refs**: a create op carries `ref: "x"`, later ops reference `"@x"`. You don't
compute canvas coordinates — omit `col_position` / rows and cards auto-place.

The `ops` array is the same JSON on both transports:

```json
[
  {"op": "create_process", "ref": "p", "name": "Lean PRD", "description": "Vision → PRD"},
  {"op": "create_phase", "ref": "ph", "process_id": "@p", "name": "Definition"},
  {"op": "create_deliverable_type", "ref": "vision", "phase_id": "@ph", "name": "Product Vision",
   "abbreviation": "PV", "instructions": "Capture the strategic intent…",
   "template_content": "## Vision\n\n## Why now\n"},
  {"op": "create_deliverable_type", "ref": "prd", "phase_id": "@ph", "name": "PRD",
   "abbreviation": "PRD", "after_type_id": "@vision"},
  {"op": "set_dependencies", "type_id": "@prd", "dependency_ids": ["@vision"]},
  {"op": "set_owner_roles", "type_id": "@prd", "role_names": ["Product Manager"]}
]
```

- **MCP (preferred):** `write_process(ops=[…])` — pass the array as a structured argument,
  no shell escaping.
- **CLI:** `processes write --ops -` and feed the array on stdin (or `@file.json`, or an inline
  string):
  ```bash
  uvx --from expedait-cli expedait processes write --ops - <<'JSON'
  [
    {"op": "create_process", "ref": "p", "name": "Lean PRD", "description": "Vision → PRD"},
    {"op": "create_phase", "ref": "ph", "process_id": "@p", "name": "Definition"},
    {"op": "create_deliverable_type", "ref": "prd", "phase_id": "@ph", "name": "PRD",
     "abbreviation": "PRD"},
    {"op": "set_owner_roles", "type_id": "@prd", "role_names": ["Product Manager"]}
  ]
  JSON
  ```

**Verify** with `get_process(id)` / `processes get PROCESS_ID` — the write result also reports
per-op `{status, …}` and the new ids (`affected_ids`) so you know the new process id to read back.

## `write_process` op reference

- `{op: "create_process", ref?, name, description?, instructions?, icon?}`
- `{op: "update_process", id, …}` / `{op: "duplicate_process", ref?, id}` /
  `{op: "delete_process", id, confirm_in_use?}`
- `{op: "create_phase", ref?, process_id | parent_type_id, name, order?, description?}` —
  `process_id` for a top-level phase, `parent_type_id` for an objective's subprocess phase
  (pass exactly one)
- `{op: "update_phase", id, …}` / `{op: "delete_phase", id}`
- `{op: "create_phase_row", ref?, phase_id, position?}` /
  `{op: "update_phase_row", id, position}` / `{op: "delete_phase_row", id}`
- `{op: "create_deliverable_type", ref?, phase_id, name, abbreviation?, description?,
  instructions?, template_content?, deliverable_requirements?, allow_multiple?, is_objective?,
  parent_type_id?, phase_row_id?, col_position?, after_type_id?}` — omit `col_position` to
  auto-place (append, or just after `after_type_id`); set `is_objective: true` to make the
  card own a subprocess
- `{op: "update_deliverable_type", id, …}` / `{op: "delete_deliverable_type", id, confirm_in_use?}`
- `{op: "set_dependencies", type_id, dependency_ids[]}` — `type_id` and each `dependency_id`
  accept `@refs`; only siblings may depend on each other
- `{op: "set_owner_roles", type_id, role_ids[] | role_names[]}` — names resolve server-side,
  so no `roles list` round-trip is needed

## Tips

- **One call, many ops.** A single write builds a whole process — refs let create → wire-deps →
  assign-roles happen atomically (cap 50 ops).
- **Per-op results.** Ops stop on the first failure; the rest report `skipped`. Each result is
  `{status: ok | error | skipped}` with a structured `{error_code, error, fix_hint}` (e.g.
  `bad_ref`, `delete_in_use`) — read it to know exactly which ops landed.
- **Deletes are guarded.** `delete_process` / `delete_deliverable_type` refuse an in-use
  template unless you pass `confirm_in_use: true`. Deleting reshapes live projects — confirm
  with the user first.
- **Objectives nest.** Create a deliverable type with `is_objective: true`, then add its inner
  phases with `create_phase` using `parent_type_id: "@thatcard"`.
- If the `expedait:*` tools aren't in your tool list, the connector isn't attached — use the
  CLI. CLI output auto-detects (text in a terminal, JSON when piped; `--format json` to force).
