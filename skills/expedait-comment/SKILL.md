---
name: expedait-comment
description: "Post an inline comment on an Expedait spec page. Use when code diverges from a specification or you find an issue in a spec."
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "[page-id] [comment text]"
---

# Post a Comment on an Expedait Spec Page

Use `uvx expedait-cli` for all commands (do NOT use `pip install`).

## Steps

1. Get the page content:
   ```bash
   uvx expedait-cli pages get PAGE_ID
   ```

2. Find the exact text to comment on. Compute character offsets:
   ```python
   content = "..."  # page content
   selected = "the text to comment on"
   start = content.index(selected)
   end = start + len(selected)
   ```

3. Create the comment:
   ```bash
   uvx expedait-cli comments create PAGE_ID \
     --text "Your comment" \
     --selected-text "exact text from the page" \
     --start-offset START \
     --end-offset END \
     --source-page-id SOURCE_PAGE_ID
   ```

4. Verify:
   ```bash
   uvx expedait-cli comments list PAGE_ID --format json
   ```

## Options

- `--text` (required): Your comment content
- `--selected-text` (required): Exact text from the page
- `--start-offset` / `--end-offset` (required): Character offsets
- `--source-page-id` (optional): The page your agent is working from
- `--parent-comment-id` (optional): Reply to an existing comment

## Tips

- Comments are auto-marked as agent comments (`is_agent_comment: true`)
- Use `--source-page-id` for cross-page notification workflows
- Keep comments actionable: describe what diverged and why
