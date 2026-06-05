# Skill: Review Code Against Deliverables

> Canonical source: [`expedait-review/SKILL.md`](expedait-review/SKILL.md). This file is a human-readable copy.

## When to Use

You want to check whether your code (or just recent branch changes) is aligned with the project's objectives, product vision, and PRD. Useful before merging a feature branch, after a deliverable update, or as a periodic alignment audit.

## Prerequisites

- [Expedait CLI](https://github.com/Expedait/expedait-cli) — run via `uvx --from expedait-cli expedait` (no install needed)
- A git repository with code to review
- Authenticated: `uvx --from expedait-cli expedait auth login`

"Review" is a first-class Expedait primitive with two surfaces: running a review (posts
findings) and reading the review issues already raised on a deliverable.

## Fast path: let the CLI run the review

```bash
uvx --from expedait-cli expedait review PROJECT --target-dir .
```

Analyzes the codebase against the project's deliverables and posts `DIVERGENCE` / `MISSING`
comments back on the relevant deliverables. Flags: `--timeout MINUTES` (default 60),
`--model claude|gemini|openai`, `--debug`.

## Reading existing review findings

```bash
# Scoring findings on a deliverable (severity, description, criteria, anchors)
uvx --from expedait-cli expedait review issues DELIVERABLE_ID --state open

# Mute a finding that isn't actionable (--unmute to restore)
uvx --from expedait-cli expedait review mute ISSUE_ID --note "tracked in JIRA-123"
```

## Manual path: scoped local report (no comments posted)

When the user wants a local report before anything is written back.

### 1. Determine scope

```bash
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

# On a feature branch: find changed files
MERGE_BASE=$(git merge-base HEAD "origin/$DEFAULT_BRANCH")
git diff --name-only "$MERGE_BASE"..HEAD
```

On the default branch (or when asked for a full audit), review the whole codebase.

### 2. Fetch latest deliverables

```bash
uvx --from expedait-cli expedait projects context PROJECT
```

Writes to `.expedait/context/`. Always fetch fresh to avoid false positives from stale copies.

### 3. Identify high-signal deliverables

- **Objectives** — top-level goals and their descendant tree (`expedait objectives overview DELIVERABLE_ID`)
- **Product Vision** — strategic direction
- **PRD** — detailed feature requirements

```bash
uvx --from expedait-cli expedait deliverables list --project-id PROJECT_ID --format json
```

### 4. Compare deliverables against code

**Flag (high signal):** requirements the code contradicts or ignores; objective/vision principles the implementation works against; features partially implemented in a way that changes behavior; new code not covered by any deliverable (scope creep).

**Skip (low signal):** minor naming differences; implementation details left open; work-in-progress code; deliverables describing future phases.

### 5. Produce the consistency report

Group findings by severity and reference deliverable IDs:

```markdown
## Consistency Report

**Scope:** branch `feature/auth-rework` — 3 files changed
**Deliverables reviewed:** Objective "Launch v1" (deliverable 3), Product Vision (deliverable 5), PRD (deliverable 10)

### Conflicts
- **PRD § "Authentication" (deliverable 10)**: requires OAuth2 PKCE, but `src/auth/login.ts` implements basic JWT.

### Missing
- **Vision § "Offline-first" (deliverable 5)**: no local caching found in changed files.

### Unspecified
- `src/api/webhooks.ts` implements retry logic not in any deliverable.

### Aligned
- Session management matches PRD § "Session Handling".
```

Objective- and vision-level conflicts outrank PRD-level ones — they indicate strategic misalignment.

## Posting findings back

The report stays local until the developer decides what to flag. To post:
- Use the comment skill for individual findings (`expedait comments create`), or
- Re-run `expedait review` to let the CLI post `DIVERGENCE`/`MISSING` comments.

## Tips

- On a feature branch, the merge-base diff is the right scope — reviewing unchanged files adds noise.
- Always fetch fresh deliverables before reviewing.
- Use `expedait deliverables inspect DELIVERABLE_ID` to see content + existing comments + dependencies in one call before posting.
- Output format auto-detects: text in a terminal, JSON when piped. Use `--format json` to force JSON.
