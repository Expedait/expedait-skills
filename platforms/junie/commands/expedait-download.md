---
description: "Read and download Expedait spec context — list your projects, then pull a project's objectives, deliverables, and their LLM context to disk. Use this skill whenever the user mentions Expedait specs, wants to see which projects exist, needs project requirements, or wants to understand what a project is about before implementing or reviewing code. Also trigger when the user asks to 'list my Expedait projects', 'what projects do I have', 'get the specs', 'fetch the deliverables', 'pull the project context', 'download the objectives', or 'show the project workspace'."
---

# Read & Download Expedait Spec Context

Ground the agent in what the product should actually do. Instead of guessing requirements,
pull a project's **specs** — objectives, deliverables, and their assembled context — into
the working directory, then implement or review against them. That is the Expedait
aha-moment: the real requirements in the agent's context, one command away.

## Transport: MCP or CLI (same data, pick what you have)

These reads run over either of two transports, at parity:

- **MCP tools** (`expedait:*`, hosted at `https://mcp.expedait.org`) — **prefer these when
  they're in your tool list.** No install, no cold start, structured results. Read scope is
  `mcp:deliverables:read`.
- **The `expedait` CLI** — the fallback that works in any agent with a shell. Runs in an
  isolated uv environment (no global install): `uvx --from expedait-cli expedait <command>`.
  Authenticate once with `uvx --from expedait-cli expedait auth login` (cached in
  `~/.expedait/config.json`; check with `auth status`).

Detection rule: if the `expedait:*` tools appear in your tool list, use them; otherwise use
the CLI. The reads are identical on both — only the invocation differs. The table below gives
both forms side by side. (`projects download`, `projects workspace`, and `deliverables inspect`
are CLI-only — no MCP equivalent yet.)

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

`PROJECT` is a numeric id, a name/substring, or omitted for an interactive pick. CLI commands
are prefixed with `uvx --from expedait-cli expedait`. MCP tool names are `ServerName:tool`,
where the server is `expedait`.

| Goal | MCP tool | CLI command |
|------|----------|-------------|
| **List your projects** | `expedait:list_projects()` | `projects list` |
| Deliverables grouped by phase | `expedait:get_project_workspace(project_id)` | `projects workspace PROJECT` |
| Download a project's whole spec set to disk | *(CLI only)* | `projects download PROJECT --output-dir .expedait/context` |
| List a project's deliverables | `expedait:list_deliverables(project_id)` | `deliverables list --project-id PROJECT_ID` |
| Read one deliverable (section-aware) | `expedait:get_deliverable(id, include=[…])` | `deliverables get DELIVERABLE_ID [--include …]` |
| Richest single read (content + comments + deps + lock) | *(CLI only)* | `deliverables inspect DELIVERABLE_ID` |
| Assembled LLM context for a deliverable | `expedait:get_deliverable_context(id)` | `context get DELIVERABLE_ID` |
| An objective's descendant tree | `expedait:get_objective_overview(id)` | `objectives overview DELIVERABLE_ID` |

`expedait:get_deliverable` defaults to cheap `meta`-only; the CLI's `deliverables get` defaults to
`content`. Either way, pass only the sections you need: `meta`, `content`, `score`, `template`,
`requirements`, `writer_instructions`, `dependencies`, `external_context`, `comments`, `versions`
(MCP `include=[…]`, CLI `--include`). MCP responses are capped at 32 KB
with truncation reported via `truncated` / `truncated_fields`. CLI output auto-detects: text in
a terminal, JSON when piped (`--format json` to force it).

## The spec model

- **Objectives** — top-level goals. An objective is itself a deliverable that nests child deliverables under it (`parent_deliverable_id`).
- **Deliverables** — the individual spec documents (product vision, PRD, BRD, persona, architecture, …).
- **Context** — the assembled LLM context for a deliverable: its dependency deliverables, linked external sources (Notion, GitHub, …), and uploaded context files.
- **Review** — scoring findings raised against a deliverable. See `/expedait-review`.

## Typical flow

1. **Find the project.** `expedait:list_projects()` / `projects list` (skip if a project id/name was given via the user's input). Done when you have the id or name.
2. **Pull the specs.** On the CLI, `projects download PROJECT --output-dir .expedait/context` extracts one markdown file per deliverable to disk. Over MCP (no download command), read the deliverables you need with `expedait:get_deliverable(id, include=["content"])`. Done when you have the content.
3. **Read before implementing.** Read the objectives and PRD first so the work matches the requirements.

## Once you understand a project

Both transports can also **write**: use `/expedait-author` to create or edit deliverables,
`/expedait-comment` to annotate them, and `/expedait-process` to design the project-type
template.

## Tips

- `deliverables inspect` and `context get` / `expedait:get_deliverable_context` are the richest single-call reads — they include dependency relationships, so you understand how deliverables reference each other.
- CLI settings resolution order: CLI flag → environment variable (`EXPEDAIT_TOKEN`, `EXPEDAIT_API_URL`, `EXPEDAIT_TENANT_ID`) → `~/.expedait/config.json`.
- If the `expedait:*` tools aren't in your tool list, the connector isn't attached — use the CLI path. If neither is available, authenticate the CLI with `auth login` first.
