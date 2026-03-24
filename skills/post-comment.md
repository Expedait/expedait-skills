# Skill: Post a Comment on a Spec Page

## When to Use

Your code diverges from a specification, or you've found an issue in a spec page that needs attention. Post a comment on the specific text that's affected.

## Prerequisites

- [Expedait CLI](https://github.com/Expedait/expedait-cli) — run via `uvx expedait-cli` (no install needed)
- Know the page ID and the text you want to comment on

## Steps

### 1. Get the page content

```bash
uvx expedait-cli pages get PAGE_ID
```

### 2. Find the text to comment on

Identify the exact text in the page content. You need:
- `selected_text`: the exact string from the page
- `start_offset`: character position where the selected text starts (0-indexed)
- `end_offset`: character position where the selected text ends

### 3. Create the comment

```bash
uvx expedait-cli comments create PAGE_ID \
  --text "Implementation uses WebSockets instead of SSE as specified here. The change was made for bidirectional communication needs." \
  --selected-text "Server-Sent Events for real-time updates" \
  --start-offset 1423 \
  --end-offset 1464 \
  --source-page-id 5
```

Options:
- `--text` (required): Your comment content
- `--selected-text` (required): The exact text from the page being commented on
- `--start-offset` (required): Start character offset in the page content
- `--end-offset` (required): End character offset in the page content
- `--source-page-id` (optional): The page ID that your agent is working from
- `--parent-comment-id` (optional): Reply to an existing comment

### 4. Verify the comment was created

```bash
uvx expedait-cli comments list PAGE_ID --format json
```

## Computing Offsets

To find the character offsets for a piece of text in the page content:

```python
content = "..."  # page content from `uvx expedait-cli pages get PAGE_ID`
selected = "Server-Sent Events for real-time updates"
start = content.index(selected)
end = start + len(selected)
```

## Tips

- Comments created via CLI are automatically marked as agent comments (`is_agent_comment: true`)
- Use `--source-page-id` to link the comment back to the page your agent is responsible for — this enables cross-page notification workflows
- Keep comments actionable: describe what diverged and why
