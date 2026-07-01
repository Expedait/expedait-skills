---
name: expedait-comment
description: "Post, list, resolve, or delete inline comments on an Expedait deliverable. Use this skill whenever the user wants to annotate a spec, flag a divergence between code and a deliverable, leave feedback on a requirement, report an issue, read existing comments, or resolve a comment on an Expedait deliverable. Also trigger when the user says 'comment on the deliverable', 'flag this in Expedait', 'leave a note on the requirement', 'list the comments', 'show comments on the deliverable', or 'resolve the comment'."
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "[deliverable-id] [comment text]"
---

# Post a Comment on an Expedait Deliverable

A **deliverable** is an Expedait spec document; comments anchor to a span of its content.

## Transport: MCP or CLI (same workflow, pick what you have)

Commenting runs over either of two transports, at parity:

- **MCP tools** (`expedait:*`, hosted at `https://mcp.expedait.org`) — **prefer these when
  they're in your tool list.** No install, no cold start, structured args. Writing comments
  needs the `mcp:comments:write` scope.
- **The `expedait` CLI** — the fallback that works in any agent with a shell. Runs in an
  isolated uv environment (no global install): `uvx --from expedait-cli expedait <command>`.
  Authenticate once with `uvx --from expedait-cli expedait auth login`.

Detection rule: if the `expedait:*` tools appear in your tool list, use them; otherwise use the
CLI. The workflow is the same on both; the one real difference is how the anchor is specified —
the CLI resolves offsets for you from `--selected-text`, while the MCP tool takes explicit
`start_offset` / `end_offset` (see "Anchoring over MCP" below).

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
| Read the deliverable to quote an exact span | `expedait:get_deliverable(id, include=["content"])` | `deliverables get DELIVERABLE_ID` |
| List existing comments (avoid dupes) | `expedait:list_comments(deliverable_id)` | `comments list DELIVERABLE_ID` |
| **Post an anchored comment** | `expedait:create_comment(deliverable_id, text, selected_text, start_offset, end_offset, …)` | `comments create DELIVERABLE_ID --text "…" --selected-text "…"` |
| Resolve a comment (idempotent) | `expedait:resolve_comment(deliverable_id, comment_id)` | `comments resolve DELIVERABLE_ID COMMENT_ID` |
| Delete a comment | *(CLI only)* | `comments delete DELIVERABLE_ID COMMENT_ID` |

## Steps

1. **Read the deliverable content** so you can quote the exact text to anchor to —
   `expedait:get_deliverable(id, include=["content"])` (MCP) or `deliverables get DELIVERABLE_ID` (CLI).

2. **Create the comment**, passing the exact span.

   **CLI** — pass the span via `--selected-text`; the CLI resolves the anchor offsets for you:
   ```bash
   uvx --from expedait-cli expedait comments create DELIVERABLE_ID \
     --text "Your comment" \
     --selected-text "exact text from the deliverable" \
     --source-deliverable-id SOURCE_DELIVERABLE_ID
   ```

   **MCP** — `expedait:create_comment(deliverable_id, text, selected_text, start_offset, end_offset,
   parent_comment_id?, client_request_id?)`. See "Anchoring over MCP" for how to compute offsets.

3. **Verify:** `expedait:list_comments(deliverable_id)` (MCP) or `comments list DELIVERABLE_ID --format json` (CLI).

## Options / fields

- `text` (required): Your comment content
- `selected_text` (required): Exact text from the deliverable being commented on
- `source_deliverable_id` / `--source-deliverable-id` (optional): The deliverable your agent is working from — enables cross-deliverable notification workflows
- `parent_comment_id` / `--parent-comment-id` (optional): Reply to an existing comment
- `--agent-run-id` (CLI, optional): Link the comment to a build run
- `client_request_id` (MCP, optional): Makes the create idempotent if you retry

## Anchoring over MCP

Unlike the CLI, `expedait:create_comment` takes explicit `start_offset` / `end_offset`: 0-based character
offsets into the `content` string returned by `expedait:get_deliverable(id, include=["content"])`. Find
`selected_text` in that string — `start_offset` is its index, `end_offset` is
`start_offset + len(selected_text)`. The CLI computes these for you from `--selected-text`.

## Resolving and deleting

```bash
# CLI
uvx --from expedait-cli expedait comments resolve DELIVERABLE_ID COMMENT_ID   # mark resolved
uvx --from expedait-cli expedait comments delete DELIVERABLE_ID COMMENT_ID    # delete
```

Over MCP, `expedait:resolve_comment(deliverable_id, comment_id)` is idempotent. (Deleting a comment is
CLI-only today.)

## Tips

- Comments created via the CLI are auto-marked as agent comments (`is_agent_comment: true`).
- Use `source_deliverable_id` for cross-deliverable notification workflows.
- Keep comments actionable: describe what diverged and why.
- If the span you pass is ambiguous or no longer present (the deliverable changed), the create fails — re-fetch the content and quote fresh text.
- If the `expedait:*` tools aren't in your tool list, the connector isn't attached — use the CLI. CLI output auto-detects (text in a terminal, JSON when piped; `--format json` to force).
