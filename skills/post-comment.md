# Skill: Post a Comment on a Deliverable

> Canonical source: [`expedait-comment/SKILL.md`](expedait-comment/SKILL.md). This file is a human-readable copy.

## When to Use

Your code diverges from a deliverable, or you've found an issue in a deliverable that needs attention. Post a comment anchored to the specific text that's affected.

## Prerequisites

- [Expedait CLI](https://github.com/Expedait/expedait-cli) — run via `uvx --from expedait-cli expedait` (no install needed)
- Authenticated: `uvx --from expedait-cli expedait auth login`

A **deliverable** is an Expedait spec document (formerly a "page").

## Steps

### 1. Get the deliverable content

```bash
uvx --from expedait-cli expedait deliverables get DELIVERABLE_ID
```

### 2. Create the comment

Pass the exact span via `--selected-text`; the CLI resolves the anchor offsets for you —
you no longer compute character offsets by hand.

```bash
uvx --from expedait-cli expedait comments create DELIVERABLE_ID \
  --text "Implementation uses WebSockets instead of SSE as specified here. Changed for bidirectional needs." \
  --selected-text "Server-Sent Events for real-time updates" \
  --source-deliverable-id 5
```

Options:
- `--text` (required): Your comment content
- `--selected-text` (required): The exact text from the deliverable being commented on
- `--source-deliverable-id` (optional): The deliverable your agent is working from
- `--parent-comment-id` (optional): Reply to an existing comment
- `--agent-run-id` (optional): Link the comment to a build run

### 3. Verify the comment was created

```bash
uvx --from expedait-cli expedait comments list DELIVERABLE_ID --format json
```

## Resolving and Deleting Comments

```bash
# Mark a comment as resolved
uvx --from expedait-cli expedait comments resolve DELIVERABLE_ID COMMENT_ID

# Delete a comment
uvx --from expedait-cli expedait comments delete DELIVERABLE_ID COMMENT_ID
```

## Tips

- Comments created via the CLI are auto-marked as agent comments (`is_agent_comment: true`).
- Use `--source-deliverable-id` to link the comment back to the deliverable your agent is responsible for — this enables cross-deliverable notification workflows.
- If `--selected-text` is ambiguous or no longer present (the deliverable changed), the command fails — re-fetch with `deliverables get` and quote fresh text.
- Keep comments actionable: describe what diverged and why.
- Output format auto-detects: text in a terminal, JSON when piped. Use `--format json` to force JSON.
