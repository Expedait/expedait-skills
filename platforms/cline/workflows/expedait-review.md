# Review Code Against Expedait Deliverables

This skill drives the `expedait` CLI over Bash — no MCP tool required. Run every command as
`uvx --from expedait-cli expedait <command>` (an isolated uv environment, no global install).

This skill does two things: **read/triage the scoring findings** already on a deliverable,
and **run a manual spec-vs-code comparison** yourself (the CLI has no automated
codebase-review runner). Post divergences you find with `/expedait-comment`.

## Commands at a glance

| Goal | Command (prefix each with `uvx --from expedait-cli expedait`) |
|------|--------------------------------------------------------------|
| **Read open review findings on a deliverable** | `review issues DELIVERABLE_ID --state open` |
| Mute a finding that isn't actionable | `review mute ISSUE_ID --note "…"` (or `--unmute`) |
| Pull fresh deliverables to compare against | `projects download PROJECT --output-dir .expedait/context` |
| An objective's descendant tree | `objectives overview DELIVERABLE_ID` |

## Reading existing review findings

```bash
# Scoring findings on a deliverable (severity, description, criteria, anchors)
uvx --from expedait-cli expedait review issues DELIVERABLE_ID --state open

# Mute a finding that isn't actionable (or --unmute to restore)
uvx --from expedait-cli expedait review mute ISSUE_ID --note "tracked in JIRA-123"
```

## Via the MCP server (reading & triaging findings)

If you're connected to the hosted Expedait MCP server (`https://mcp.expedait.org`) instead
of the CLI, you can read and triage review findings directly (tool names are `ServerName:tool`,
where the server is `expedait`):

```
expedait:list_review_issues(deliverable_id, state?)   # state: open | muted | all (default all)
expedait:mute_review_issue(issue_id, muted?, muted_note?)   # muted=false to unmute; needs mcp:deliverables:write
```

Each issue carries severity, description, the criteria that flagged it, anchor offsets, and
an optional reference. Mute findings that aren't actionable with a `muted_note` explaining
why (e.g. tracked elsewhere). If these tools aren't in your tool list, the connector isn't
attached — use the CLI path above instead.

## Manual path: scoped local report (no comments posted)

When the user wants a local report to review *before* anything is written back, do the
comparison yourself and scope it to what actually changed.

### Step 1: Determine review scope

```bash
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
```

**On a feature branch** (current branch differs from default):
```bash
MERGE_BASE=$(git merge-base HEAD "origin/$DEFAULT_BRANCH")
git diff --name-only "$MERGE_BASE"..HEAD
```
Only review these changed files against the deliverables.

**On the default branch**, or if the user explicitly asks for a full audit, review the entire codebase. Useful for periodic alignment checks or before major releases.

**If the user's input contains a project ID/name**, use it directly. Otherwise list projects.

### Step 2: Fetch the latest deliverables

Always pull fresh — stale local copies lead to false positives.

```bash
uvx --from expedait-cli expedait projects download PROJECT --output-dir .expedait/context
```

Extracts the deliverables to `.expedait/context/`.

### Step 3: Identify high-signal deliverables

Focus on the deliverables that define what the product should do and why:

1. **Objectives** — top-level goals and their descendant tree. Read these first to understand intent (`expedait objectives overview DELIVERABLE_ID`).
2. **Product Vision** — strategic intent. Look for `*vision*`, `*product-vision*` in `.expedait/context/`.
3. **PRD** — detailed requirements. Look for `*prd*`, `*product-requirements*`.

```bash
uvx --from expedait-cli expedait deliverables list --project-id PROJECT_ID --format json
```

Keep track of deliverable IDs and titles — the report should reference them.

### Step 4: Compare deliverables against code

**What to flag** (high signal):
- A requirement the code contradicts or ignores
- An objective or vision principle the implementation works against
- A feature partially implemented in a way that changes its behavior
- New code that introduces functionality not covered by any deliverable (scope creep)

**What to skip** (low signal):
- Minor naming differences between spec and code
- Implementation details the deliverable intentionally leaves open
- Work-in-progress code that clearly isn't finished
- Deliverables describing future phases not yet started

### Step 5: Produce the consistency report

```markdown
## Consistency Report

**Scope:** [branch `feature/xyz` — 12 files changed] or [full codebase audit]
**Deliverables reviewed:** Objective "Launch v1" (deliverable 3), Product Vision (deliverable 5), PRD (deliverable 10)

### Conflicts (deliverable says X, code does Y)
- **PRD § "Authentication" (deliverable 10)**: requires OAuth2 PKCE flow, but `src/auth/login.ts` implements basic JWT with no PKCE.

### Missing (deliverable requires it, code doesn't have it)
- **Vision § "Offline-first" (deliverable 5)**: no service worker or local caching in the changed files.

### Unspecified (code does it, no deliverable mentions it)
- `src/api/webhooks.ts` implements a webhook retry system not described in any deliverable.

### Aligned
- Payment flow matches PRD § "Billing" — Stripe integration as specified.
```

Objective- and vision-level conflicts are higher priority than PRD-level ones — they indicate strategic misalignment. Group divergences that share a theme rather than listing individually.

## Posting findings back

The manual report stays local until the developer decides what's worth flagging. To post a
finding, use `/expedait-comment` to anchor it to the exact deliverable text it diverges from.

## Tips

- On a feature branch, the merge-base diff is the right scope — reviewing unchanged files adds noise.
- Always fetch fresh deliverables before reviewing.
- `expedait deliverables inspect DELIVERABLE_ID` shows content + existing comments + dependencies in one call — handy to avoid duplicate comments.
- Output format auto-detects: text in a terminal, JSON when piped. Use `--format json` to force JSON.
