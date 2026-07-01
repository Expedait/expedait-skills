---
name: expedait-download
description: "Read and download Expedait spec context — list your projects, then pull a project's objectives, deliverables, and their LLM context to disk. Use this skill whenever the user mentions Expedait specs, wants to see which projects exist, needs project requirements, or wants to understand what a project is about before implementing or reviewing code. Also trigger when the user asks to 'list my Expedait projects', 'what projects do I have', 'get the specs', 'fetch the deliverables', 'pull the project context', 'download the objectives', or 'show the project workspace'."
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "[project-id-or-name]"
---

# Read & Download Expedait Spec Context

Ground the agent in what the product should actually do. Instead of guessing requirements,
pull a project's **specs** — objectives, deliverables, and their assembled context — into
the working directory, then implement or review against them. That is the Expedait
aha-moment: the real requirements in the agent's context, one command away.

Every command runs through the CLI: `uvx --from expedait-cli expedait <command>` — an
isolated uv environment, so no global install is needed. Authenticate once with
`uvx --from expedait-cli expedait auth login` (cached in `~/.expedait/config.json`); check
with `auth status`.

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

## Commands at a glance

Run any of these directly — this skill drives the `expedait` CLI over Bash (no MCP tool
required). `PROJECT` is a numeric id, a name/substring, or omitted for an interactive pick.

| Goal | Command (prefix each with `uvx --from expedait-cli expedait`) |
|------|--------------------------------------------------------------|
| **List your projects** | `projects list` |
| Download a project's whole spec set to disk | `projects download PROJECT --output-dir .expedait/context` |
| See deliverables grouped by phase | `projects workspace PROJECT` |
| List a project's deliverables | `deliverables list --project-id PROJECT_ID` |
| Read one deliverable | `deliverables get DELIVERABLE_ID [--include content,score,…]` |
| Richest single read (content + comments + deps + lock) | `deliverables inspect DELIVERABLE_ID` |
| Assembled LLM context for a deliverable | `context get DELIVERABLE_ID` |
| An objective's descendant tree | `objectives overview DELIVERABLE_ID` |

Output auto-detects: text in a terminal, JSON when piped (`--format json` to force).

## The spec model

- **Objectives** — top-level goals. An objective is itself a deliverable that nests child deliverables under it (`parent_deliverable_id`).
- **Deliverables** — the individual spec documents (product vision, PRD, BRD, persona, architecture, …).
- **Context** — the assembled LLM context for a deliverable: its dependency deliverables, linked external sources (Notion, GitHub, …), and uploaded context files.
- **Review** — scoring findings raised against a deliverable. See `/expedait-review`.

## Typical flow

1. **Find the project.** `projects list` (skip if a project id/name was given via $ARGUMENTS). Done when you have the id or name.
2. **Pull the specs.** `projects download PROJECT --output-dir .expedait/context` — extracts one markdown file per deliverable. Done when the files exist on disk.
3. **Read before implementing.** Read the downloaded deliverables — objectives and PRD first — so the work matches the requirements.

For `deliverables get`, opt into heavier sections as needed:
`--include content,score,template,requirements,writer_instructions,dependencies,external_context,comments,versions`.

## Via the MCP server (no CLI)

If you're connected to the hosted Expedait MCP server (`https://mcp.expedait.org`), the same
reads map to these tools (fully-qualified as `ServerName:tool`, where the server is `expedait`;
all read-only, `mcp:deliverables:read`):

```
expedait:list_projects()                     expedait:get_project_workspace(project_id)   # phase grouping
expedait:list_deliverables(project_id)       expedait:get_deliverable(id, include=[...])  # section-aware
expedait:get_objective_overview(id)          expedait:get_deliverable_context(id)         # assembled LLM context
```

`expedait:get_deliverable` defaults to cheap `meta`-only; opt into heavier sections (`content`,
`template`, `requirements`, `writer_instructions`, `dependencies`, `external_context`,
`score`, `comments`, `versions`) only when you need them. Responses are capped at 32 KB with
truncation reported via `truncated` / `truncated_fields`.

Once you understand a project, the MCP server can also **write**: use `/expedait-author` to
create or edit deliverables, and `/expedait-process` to design the project-type template.

## Tips

- Output format auto-detects: text in a terminal, JSON when piped. Use `--format json` to force JSON.
- `deliverables inspect` and `context get` are the richest single-call reads — they include dependency relationships, so you understand how deliverables reference each other.
- Settings resolution order: CLI flag → environment variable (`EXPEDAIT_TOKEN`, `EXPEDAIT_API_URL`, `EXPEDAIT_TENANT_ID`) → `~/.expedait/config.json`.
- Prefer the hosted MCP server (`https://mcp.expedait.org`) when your AI client supports connectors — it exposes the same primitives without the CLI.
