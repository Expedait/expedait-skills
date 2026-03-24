# Skill: Review Code Against Specs and Post Comments

## When to Use

You've implemented code based on Expedait specs and need to flag any places where the implementation diverges from the documentation. This keeps specs and code in sync across iterations.

## Prerequisites

- [Expedait CLI](https://github.com/Expedait/expedait-cli) installed and authenticated
- Access to the codebase being reviewed
- Know the project ID

## Steps

### 1. Download all specs

```bash
expedait projects list --format json
# Find your project ID

expedait projects download PROJECT_ID --output-dir ./specs
```

### 2. Read each spec page

Review the downloaded markdown files against your implementation. For each spec page, check:
- Are the requirements implemented as described?
- Are there features in code that aren't in the spec?
- Are there spec requirements that weren't implemented or were implemented differently?

### 3. Get page IDs for commenting

```bash
expedait pages list --project-id PROJECT_ID --format json
```

This returns all pages with their IDs, titles, and states.

### 4. For each discrepancy, post a comment

First, get the page content to compute offsets:

```bash
expedait pages get PAGE_ID
```

Then find the relevant text and compute offsets:

```python
content = "..."  # from pages get
selected_text = "the specific text that relates to the discrepancy"
start_offset = content.index(selected_text)
end_offset = start_offset + len(selected_text)
```

Post the comment:

```bash
expedait comments create PAGE_ID \
  --text "Implementation note: [describe the divergence and reasoning]" \
  --selected-text "the specific text" \
  --start-offset START \
  --end-offset END \
  --source-page-id SOURCE_PAGE_ID
```

### 5. Verify all comments

```bash
expedait comments list PAGE_ID --format json
```

## Example Workflow

```bash
# 1. Get specs
expedait projects download 1 --output-dir ./specs

# 2. List pages to get IDs
expedait pages list --project-id 1 --format json
# [{"id": 10, "title": "PRD", ...}, {"id": 11, "title": "BRD", ...}]

# 3. Read PRD content
expedait pages get 10
# Returns markdown content...

# 4. Post comment about a divergence in the PRD
expedait comments create 10 \
  --text "Auth uses JWT tokens instead of session cookies. Changed for stateless API compatibility." \
  --selected-text "session-based authentication" \
  --start-offset 2150 \
  --end-offset 2178

# 5. Post comment about a missing feature in the BRD
expedait comments create 11 \
  --text "Export to PDF is not yet implemented. Deferred to v2 due to scope." \
  --selected-text "Users can export reports to PDF" \
  --start-offset 890 \
  --end-offset 920
```

## Tips

- Review all spec pages, not just the one you're directly implementing — changes in one area often affect dependencies
- Use `expedait pages full PAGE_ID` to see existing comments before adding duplicates
- Comments should be actionable: state what diverged, why, and what (if anything) needs to change
- Use `--source-page-id` when your agent owns a specific page — replies to your comments will trigger notifications on that page
- After posting comments, the spec authors can resolve them once acknowledged, or update the spec to match the implementation
