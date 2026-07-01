# Create or Adapt an Expedait Process

This skill drives the `expedait` CLI over Bash — no MCP tool required. Run every command as
`uvx --from expedait-cli expedait <command>` (an isolated uv environment, no global install);
authenticate once with `uvx --from expedait-cli expedait auth login`.

## Commands at a glance

| Goal | Command (prefix each with `uvx --from expedait-cli expedait`) |
|------|--------------------------------------------------------------|
| List existing processes | `processes list` |
| Inspect a process (full tree) | `processes get PROCESS_ID` |
| List the workspace role pool | `roles list` |
| Create an owner role | `roles create --name "…" --instructions @file` |
| **Build or modify a process atomically** | `processes write --ops -` |
| Change several roles atomically | `roles write --ops -` |

A **process** is the template layer of Expedait — the project type that every project is
instantiated from. Editing a process reshapes **every** project built from it. Its shape:

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

## Look before you build

Reuse or extend rather than duplicate, and inspect any process you'll adapt:

```bash
uvx --from expedait-cli expedait processes list                 # id, name, description, icon
uvx --from expedait-cli expedait processes get PROCESS_ID       # full tree: phases → rows → cards, deps, owner roles, subprocesses
```

## Check (or create) the role pool

Owner roles are assigned by name or id. See what exists, and create any that don't:

```bash
uvx --from expedait-cli expedait roles list
uvx --from expedait-cli expedait roles create --name "Data Architect" \
  --instructions @data-architect-persona.md          # --instructions: @file, -, or literal
# update / delete also available:
uvx --from expedait-cli expedait roles update ROLE_ID --description "..."
uvx --from expedait-cli expedait roles delete ROLE_ID
```

`--instructions` is the role's LLM coaching persona (the system prompt for deliverables this
role owns). For several role changes at once, use the atomic `roles write --ops` form
(`create_role` / `update_role` / `delete_role`, chainable with `ref` / `@ref`).

## Build the process in one `processes write` call

Process building is one atomic ops array (mirrors the MCP `expedait:write_process` tool). Ops execute
in order and chain across entity kinds via **named refs**: a create op carries `ref: "x"`,
later ops reference `"@x"`. You don't compute canvas coordinates — omit `col_position` / rows
and cards auto-place.

```bash
uvx --from expedait-cli expedait processes write --ops - <<'JSON'
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
JSON
```

`--ops` accepts `@file.json`, `-` (stdin), or an inline string. **Verify** with
`processes get PROCESS_ID` — the write result also reports per-op `{status, …}` and the new
ids (`affected_ids`) so you know the new process id to read back.

## `processes write` op reference

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

- **One call, many ops.** A single `processes write` builds a whole process — refs let
  create → wire-deps → assign-roles happen atomically (cap 50 ops).
- **Per-op results.** Ops stop on the first failure; the rest report `skipped`. Each result is
  `{status: ok | error | skipped}` with a structured `{error_code, error, fix_hint}` (e.g.
  `bad_ref`, `delete_in_use`) — read it to know exactly which ops landed.
- **Deletes are guarded.** `delete_process` / `delete_deliverable_type` refuse an in-use
  template unless you pass `confirm_in_use: true`. Deleting reshapes live projects — confirm
  with the user first.
- **Objectives nest.** Create a deliverable type with `is_objective: true`, then add its inner
  phases with `create_phase` using `parent_type_id: "@thatcard"`.

## Via the MCP server (alternative to the CLI)

Connected to the hosted Expedait MCP server (`https://mcp.expedait.org`) instead of the CLI?
The same surface maps to `expedait:list_processes` / `expedait:get_process` / `expedait:list_roles`,
`expedait:write_process(ops=[...])`, and `expedait:write_role(ops=[...])` (tool names are
`ServerName:tool`, where the server is `expedait`), with the identical op set and named refs. Requires the
`mcp:process:write` scope (kept separate from `mcp:deliverables:write` on purpose, since
reshaping a template touches every project of that type). If those tools aren't in your tool
list, the connector isn't attached — use the CLI above instead.
