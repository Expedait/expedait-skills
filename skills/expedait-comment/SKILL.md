---
name: expedait-comment
description: "Post, list, resolve, or delete inline comments on an Expedait deliverable. Use this skill whenever the user wants to annotate a spec, flag a divergence between code and a deliverable, leave feedback on a requirement, report an issue, read existing comments, or resolve a comment on an Expedait deliverable. Also trigger when the user says 'comment on the deliverable', 'flag this in Expedait', 'leave a note on the requirement', 'list the comments', 'show comments on the deliverable', or 'resolve the comment'."
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "[deliverable-id] [comment text]"
---

# Post a Comment on an Expedait Deliverable

This skill drives the `expedait` CLI over Bash — no MCP tool required. Run every command
as `uvx --from expedait-cli expedait <command>` (an isolated uv environment, no global
install). A **deliverable** is an Expedait spec document; comments anchor to a span of its
content.

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

| Goal | Command (prefix each with `uvx --from expedait-cli expedait`) |
|------|--------------------------------------------------------------|
| Read the deliverable to quote an exact span | `deliverables get DELIVERABLE_ID` |
| **Post an anchored comment** | `comments create DELIVERABLE_ID --text "…" --selected-text "…"` |
| List existing comments | `comments list DELIVERABLE_ID` |
| Resolve a comment | `comments resolve DELIVERABLE_ID COMMENT_ID` |
| Delete a comment | `comments delete DELIVERABLE_ID COMMENT_ID` |

## Steps

1. Get the deliverable content so you can quote the exact text to anchor the comment to:
   ```bash
   uvx --from expedait-cli expedait deliverables get DELIVERABLE_ID
   ```

2. Create the comment. Pass the exact span via `--selected-text`; the CLI resolves the
   anchor offsets for you, so you don't compute them by hand:
   ```bash
   uvx --from expedait-cli expedait comments create DELIVERABLE_ID \
     --text "Your comment" \
     --selected-text "exact text from the deliverable" \
     --source-deliverable-id SOURCE_DELIVERABLE_ID
   ```

3. Verify:
   ```bash
   uvx --from expedait-cli expedait comments list DELIVERABLE_ID --format json
   ```

## Options

- `--text` (required): Your comment content
- `--selected-text` (required): Exact text from the deliverable being commented on
- `--source-deliverable-id` (optional): The deliverable your agent is working from — enables cross-deliverable notification workflows
- `--parent-comment-id` (optional): Reply to an existing comment
- `--agent-run-id` (optional): Link the comment to a build run

## Resolving and Deleting Comments

```bash
# Mark a comment as resolved
uvx --from expedait-cli expedait comments resolve DELIVERABLE_ID COMMENT_ID

# Delete a comment
uvx --from expedait-cli expedait comments delete DELIVERABLE_ID COMMENT_ID
```

## Via the MCP server (no CLI)

If you're connected to the hosted Expedait MCP server (`https://mcp.expedait.org`) instead
of the CLI, the same workflow maps to these tools (fully-qualified as `ServerName:tool`, where
the server is `expedait`; requires the `mcp:comments:write` scope):

```
expedait:get_deliverable(id, include=["content"])   # quote exact span to anchor to
expedait:list_comments(deliverable_id)              # see existing comments, avoid dupes
expedait:create_comment(deliverable_id, text, selected_text, start_offset, end_offset,
               parent_comment_id?, client_request_id?)
expedait:resolve_comment(deliverable_id, comment_id)   # idempotent
```

Unlike the CLI, `expedait:create_comment` takes explicit `start_offset` / `end_offset`: they are
0-based character offsets into the `content` string returned by
`expedait:get_deliverable(id, include=["content"])`. Find `selected_text` in that string —
`start_offset` is its index, `end_offset` is `start_offset + len(selected_text)`. Pass
`client_request_id` to make the create idempotent if you retry. If these tools aren't in your
tool list, the connector isn't attached — use the CLI path above instead.

## Tips

- Comments created via the CLI are auto-marked as agent comments (`is_agent_comment: true`).
- Use `--source-deliverable-id` for cross-deliverable notification workflows.
- Keep comments actionable: describe what diverged and why.
- If the span you pass to `--selected-text` is ambiguous or no longer present (the deliverable changed), the command fails — re-fetch with `deliverables get` and quote fresh text.
- Output format auto-detects: text in a terminal, JSON when piped. Use `--format json` to force JSON.
