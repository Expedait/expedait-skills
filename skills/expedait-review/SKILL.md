---
name: expedait-review
description: "Review code against Expedait specs and post comments on divergences. End-to-end workflow: download specs, compare with code, post inline comments."
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "[project-id]"
---

# Review Code Against Expedait Specs

Use `uvx expedait-cli` for all commands (do NOT use `pip install`).

## Steps

1. Download all specs:
   ```bash
   uvx expedait-cli projects download PROJECT_ID --output-dir ./specs
   ```

2. Read each spec page and compare against the implementation. Check:
   - Are requirements implemented as described?
   - Are there features in code not in the spec?
   - Are there spec requirements implemented differently?

3. Get page IDs for commenting:
   ```bash
   uvx expedait-cli pages list --project-id PROJECT_ID --format json
   ```

4. For each discrepancy, get the page content and compute offsets:
   ```bash
   uvx expedait-cli pages get PAGE_ID
   ```
   ```python
   content = "..."  # from pages get
   selected_text = "the specific text"
   start_offset = content.index(selected_text)
   end_offset = start_offset + len(selected_text)
   ```

5. Post the comment:
   ```bash
   uvx expedait-cli comments create PAGE_ID \
     --text "Implementation note: [describe the divergence]" \
     --selected-text "the specific text" \
     --start-offset START \
     --end-offset END \
     --source-page-id SOURCE_PAGE_ID
   ```

6. Verify all comments:
   ```bash
   uvx expedait-cli comments list PAGE_ID --format json
   ```

## Tips

- Review ALL spec pages, not just the one you're implementing — changes affect dependencies
- Use `uvx expedait-cli pages full PAGE_ID` to see existing comments before adding duplicates
- Comments should be actionable: state what diverged, why, and what needs to change
- Use `--source-page-id` when your agent owns a specific page
