# Skill: Review Code Against Specs

## When to Use

You want to check whether your code (or just recent branch changes) is aligned with the product vision and PRD. Useful before merging a feature branch, after a spec update, or as a periodic alignment audit.

This skill produces a local report. It does not post comments back to Expedait — that's a deliberate follow-up via the comment skill.

## Prerequisites

- [Expedait CLI](https://github.com/Expedait/expedait-cli) — run via `uvx expedait-cli` (no install needed)
- A git repository with code to review
- Project initialized with `uvx expedait-cli init` (or know the project ID)

## How Scoping Works

The skill adapts its scope based on your git branch:

- **Feature branch**: only files changed since the branch diverged from the default branch are reviewed
- **Default branch** (main/master): the full codebase is reviewed against specs
- **Explicit override**: the user can always ask for a full audit regardless of branch

## Steps

### 1. Determine scope

```bash
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

# On a feature branch: find changed files
MERGE_BASE=$(git merge-base HEAD "origin/$DEFAULT_BRANCH")
git diff --name-only "$MERGE_BASE"..HEAD
```

### 2. Fetch latest specs

```bash
uvx expedait-cli projects download PROJECT_ID
```

Downloads to `.expedait/context/` by default. Always fetch fresh to avoid false positives from stale copies.

### 3. Identify high-signal specs

Focus on specs that define product intent:

- **Product Vision** — strategic direction and principles
- **PRD** — detailed feature requirements

```bash
uvx expedait-cli pages list --project-id PROJECT_ID --format json
```

### 4. Compare specs against code

For each high-signal spec, check the code in scope.

**Flag these (high signal):**
- Requirements the code contradicts or ignores
- Vision principles the implementation works against
- Features partially implemented in a way that changes their behavior
- New code not covered by any spec (scope creep)

**Skip these (low signal):**
- Minor naming differences
- Implementation details specs leave open
- Work-in-progress code
- Specs describing future phases

### 5. Produce the consistency report

Group findings by severity:

| Category | Meaning | Post comment? |
|----------|---------|---------------|
| **Conflict** | Spec says X, code does Y | Only if user asks |
| **Missing** | Spec requires it, code doesn't have it | Only if user asks |
| **Unspecified** | Code does it, spec doesn't mention it | No — report only |
| **Aligned** | Code matches spec | No — report only |

Include page IDs and spec section references so findings are actionable.

## Example: Branch Review

```bash
# 1. Scope to branch changes
MERGE_BASE=$(git merge-base HEAD origin/main)
git diff --name-only "$MERGE_BASE"..HEAD
# src/auth/login.ts
# src/auth/session.ts
# src/api/webhooks.ts

# 2. Fetch specs
uvx expedait-cli projects download 1

# 3. Read PRD and vision
cat .expedait/context/01-conceptualization/product-vision.md
cat .expedait/context/02-definition-ux/prd.md

# 4. Compare and produce report
```

Example output:

```markdown
## Consistency Report

**Scope:** branch `feature/auth-rework` — 3 files changed
**Specs reviewed:** Product Vision (page 5), PRD (page 10)

### Conflicts
- **PRD § "Authentication" (page 10)**: Spec requires OAuth2 PKCE flow, but `src/auth/login.ts` implements basic JWT.

### Missing
- **Vision § "Offline-first" (page 5)**: No local caching found in changed files.

### Unspecified
- `src/api/webhooks.ts` implements retry logic not in any spec.

### Aligned
- Session management matches PRD § "Session Handling".
```

## Posting Findings as Comments

The report is for the developer to review locally. To post specific findings back to Expedait:

```bash
# Post a single finding as an inline comment
uvx expedait-cli comments create PAGE_ID \
  --text "Consistency check: login.ts uses basic JWT, but PRD specifies OAuth2 PKCE." \
  --selected-text "OAuth2 with PKCE flow for all client authentication" \
  --start-offset 2150 \
  --end-offset 2200
```

Or ask the agent to post all Conflict/Missing findings after reviewing the report.

## Tips

- Vision-level conflicts are higher priority than PRD-level ones — they indicate strategic misalignment
- On feature branches, the merge-base diff is the right scope — reviewing unchanged files adds noise
- If many divergences share a theme, group them rather than listing individually
- Use `uvx expedait-cli pages full PAGE_ID` to check for existing comments before posting
- Output format auto-detects: text for terminal, JSON when piped. Use `--format json` to force JSON output
