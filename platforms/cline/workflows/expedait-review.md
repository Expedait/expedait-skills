# Review Code Against Expedait Deliverables

This skill does two things: **read/triage the scoring findings** already on a deliverable,
and **run a manual spec-vs-code comparison** yourself (there is no automated codebase-review
runner). Post divergences you find with `/expedait-comment`.

## Transport: MCP or CLI (same reads, pick what you have)

Reading and triaging findings runs over either of two transports, at parity:

- **MCP tools** (`expedait:*`, hosted at `https://mcp.expedait.org`) — **prefer these when
  they're in your tool list.** No install, no cold start, structured results. Reading is
  `mcp:deliverables:read`; muting needs `mcp:deliverables:write`.
- **The `expedait` CLI** — the fallback that works in any agent with a shell. Runs in an
  isolated uv environment (no global install): `uvx --from expedait-cli expedait <command>`.

Detection rule: if the `expedait:*` tools appear in your tool list, use them; otherwise use the
CLI. The reads are identical on both. The manual comparison below is transport-agnostic — it's
just `git` plus reading deliverables (which the CLI's `projects download` conveniently dumps to
disk).

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

## Commands at a glance — MCP tool ↔ CLI command

CLI commands are prefixed with `uvx --from expedait-cli expedait`. MCP tool names are
`ServerName:tool`, where the server is `expedait`.

| Goal | MCP tool | CLI command |
|------|----------|-------------|
| **Read open review findings on a deliverable** | `list_review_issues(deliverable_id, state?)` | `review issues DELIVERABLE_ID --state open` |
| Mute a finding that isn't actionable | `mute_review_issue(issue_id, muted?, muted_note?)` | `review mute ISSUE_ID --note "…"` (or `--unmute`) |
| An objective's descendant tree | `get_objective_overview(id)` | `objectives overview DELIVERABLE_ID` |
| Pull fresh deliverables to compare against | *(CLI only)* | `projects download PROJECT --output-dir .expedait/context` |

`state` is `open | muted | all` (default `all`). Each issue carries severity, description, the
criteria that flagged it, anchor offsets, and an optional reference. On MCP, pass `muted=false`
to unmute. Mute findings that aren't actionable with a note explaining why (e.g. tracked
elsewhere).

## Reading existing review findings

```bash
# CLI
uvx --from expedait-cli expedait review issues DELIVERABLE_ID --state open
uvx --from expedait-cli expedait review mute ISSUE_ID --note "tracked in JIRA-123"   # --unmute to restore
```

Over MCP: `list_review_issues(deliverable_id, "open")` and
`mute_review_issue(issue_id, muted=true, muted_note="tracked in JIRA-123")`.

## Manual path: scoped local report (no comments posted)

When the user wants a local report to review *before* anything is written back, do the
comparison yourself and scope it to what actually changed. This path is transport-agnostic.

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

Always pull fresh — stale local copies lead to false positives. On the CLI, `projects download`
dumps one markdown file per deliverable to disk:

```bash
uvx --from expedait-cli expedait projects download PROJECT --output-dir .expedait/context
```

Over MCP (no download command), read the deliverables you need with
`get_deliverable(id, include=["content"])` and `get_deliverable_context(id)`.

### Step 3: Identify high-signal deliverables

Focus on the deliverables that define what the product should do and why:

1. **Objectives** — top-level goals and their descendant tree. Read these first to understand intent (`get_objective_overview(id)` / `objectives overview DELIVERABLE_ID`).
2. **Product Vision** — strategic intent. Look for `*vision*`, `*product-vision*` in `.expedait/context/`.
3. **PRD** — detailed requirements. Look for `*prd*`, `*product-requirements*`.

```bash
uvx --from expedait-cli expedait deliverables list --project-id PROJECT_ID --format json
```

(Over MCP: `list_deliverables(project_id)`.) Keep track of deliverable IDs and titles — the
report should reference them.

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
- `deliverables inspect DELIVERABLE_ID` (CLI) shows content + existing comments + dependencies in one call — handy to avoid duplicate comments.
- If the `expedait:*` tools aren't in your tool list, the connector isn't attached — use the CLI. CLI output auto-detects (text in a terminal, JSON when piped; `--format json` to force).
