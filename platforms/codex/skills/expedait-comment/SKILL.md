---
name: expedait-comment
description: "Post an inline comment on an Expedait deliverable. Use this skill whenever the user wants to annotate a spec, flag a divergence between code and a deliverable, leave feedback on a requirement, or report an issue in an Expedait deliverable. Also trigger when the user says 'comment on the deliverable', 'flag this in Expedait', or 'leave a note on the requirement'."
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep
argument-hint: [deliverable-id] [comment text]
---

# Post a Comment on an Expedait Deliverable

Run the CLI via `uvx --from expedait-cli expedait` — it runs in an isolated environment via uv, so no global install or virtual environment is needed.

A **deliverable** is an Expedait spec document (formerly a "page"). Comments anchor to a
span of its content.

## Steps

1. Get the deliverable content so you can quote the exact text to anchor the comment to:
   ```bash
   uvx --from expedait-cli expedait deliverables get DELIVERABLE_ID
   ```

2. Create the comment. Pass the exact span via `--selected-text`; the CLI resolves the
   anchor offsets for you, so you no longer compute them by hand:
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

## Tips

- Comments created via the CLI are auto-marked as agent comments (`is_agent_comment: true`).
- Use `--source-deliverable-id` for cross-deliverable notification workflows.
- Keep comments actionable: describe what diverged and why.
- If the span you pass to `--selected-text` is ambiguous or no longer present (the deliverable changed), the command fails — re-fetch with `deliverables get` and quote fresh text.
- Output format auto-detects: text in a terminal, JSON when piped. Use `--format json` to force JSON.
