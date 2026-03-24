#!/usr/bin/env bash
set -euo pipefail

# Expedait Skills Installer
# Detects your AI coding agent and installs the appropriate config files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
TARGET_DIR="${TARGET_DIR:-.}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
error() { echo -e "${RED}✗${NC} $*" >&2; }

usage() {
  cat <<EOF
Usage: install.sh [OPTIONS]

Install Expedait skills for your AI coding agent.

Options:
  --agent <name>    Install for a specific agent:
                      claude-code, cursor, opencode, codex
  --all             Install for all detected agents
  --target <dir>    Target project directory (default: current directory)
  -h, --help        Show this help

Examples:
  ./install.sh                    # Auto-detect and install
  ./install.sh --agent cursor     # Install for Cursor only
  ./install.sh --all              # Install for all agents
  ./install.sh --target ~/myapp   # Install into a specific project
EOF
}

# --- Claude Code ---
install_claude_code() {
  local dir="$TARGET_DIR/.claude/skills"

  # Download Project Context
  mkdir -p "$dir/expedait-download"
  cat > "$dir/expedait-download/SKILL.md" <<'SKILL'
---
name: expedait-download
description: "Download all specification pages for an Expedait project. Use when you need project context, specs, or requirements before implementing or reviewing code."
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "[project-id]"
---

# Download Project Context from Expedait

Use `uvx expedait-cli` for all commands (do NOT use `pip install`).

## Steps

1. If no project ID was given via $ARGUMENTS, list available projects:
   ```bash
   uvx expedait-cli projects list --format json
   ```

2. Download all spec pages:
   ```bash
   uvx expedait-cli projects download PROJECT_ID --output-dir ./specs
   ```

3. Read the downloaded specs in `./specs/` to understand the project requirements.

## Single page alternative

```bash
# Print markdown to stdout
uvx expedait-cli pages get PAGE_ID

# Full context (content + comments + dependencies)
uvx expedait-cli pages full PAGE_ID --format json

# Download as ZIP
uvx expedait-cli pages download PAGE_ID --output-dir ./specs
```

## Tips

- Use `--format json` when piping output to other tools
- `pages full` includes dependency info — useful for understanding page relationships
- Page images referenced as `![name](/api/v1/pages/files/{file_id})` are included in ZIP downloads
SKILL

  # Post Comment
  mkdir -p "$dir/expedait-comment"
  cat > "$dir/expedait-comment/SKILL.md" <<'SKILL'
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
SKILL

  # Review and Comment
  mkdir -p "$dir/expedait-review"
  cat > "$dir/expedait-review/SKILL.md" <<'SKILL'
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
SKILL

  info "Claude Code: installed skills in $dir/"
  info "  /expedait-download  — download project specs"
  info "  /expedait-comment   — post a comment on a spec page"
  info "  /expedait-review    — review code against specs"
}

# --- Cursor ---
install_cursor() {
  local dir="$TARGET_DIR/.cursor/rules"
  mkdir -p "$dir"

  cat > "$dir/expedait.mdc" <<'RULE'
---
description: "Expedait spec management — download project specs, post inline comments, and review code against specifications. Activate when the user mentions Expedait, specs, specifications, or project requirements."
alwaysApply: false
---

# Expedait Integration

Use `uvx expedait-cli` for all Expedait commands. Do NOT use `pip install`.

## Authentication

The user must authenticate first:
```bash
uvx expedait-cli auth login
```

Or via environment variables: `EXPEDAIT_TOKEN`, `EXPEDAIT_API_URL`, `EXPEDAIT_TENANT_ID`.

## Download Project Specs

```bash
uvx expedait-cli projects list --format json
uvx expedait-cli projects download PROJECT_ID --output-dir ./specs
```

Downloaded specs are markdown files organized by phase in `./specs/`.

## Post a Comment

When code diverges from a spec, post an inline comment:

```bash
# Get page content
uvx expedait-cli pages get PAGE_ID

# Post comment with text selection
uvx expedait-cli comments create PAGE_ID \
  --text "Your comment" \
  --selected-text "exact text from the page" \
  --start-offset START --end-offset END
```

Compute offsets: `start = content.index(selected_text)`, `end = start + len(selected_text)`.

## Review Code Against Specs

1. Download specs: `uvx expedait-cli projects download PROJECT_ID --output-dir ./specs`
2. Compare each spec page against the implementation
3. For each discrepancy, post an inline comment with `uvx expedait-cli comments create`
4. Check for existing comments first: `uvx expedait-cli pages full PAGE_ID`

## Tips

- Use `--format json` when piping output to other tools
- Comments are auto-marked as agent comments
- Use `--source-page-id` to link comments to the page your agent owns
RULE

  info "Cursor: installed rule at $dir/expedait.mdc"
}

# --- AGENTS.md (OpenCode / Codex) ---
install_agents_md() {
  local file="$TARGET_DIR/AGENTS.md"
  local section_marker="## Expedait Integration"

  # Check if section already exists
  if [[ -f "$file" ]] && grep -q "$section_marker" "$file"; then
    warn "AGENTS.md already contains Expedait section — skipping"
    return
  fi

  local content
  content=$(cat <<'AGENTS'

## Expedait Integration

Use `uvx expedait-cli` for all Expedait commands. Do NOT use `pip install`.

### Authentication

```bash
uvx expedait-cli auth login
```

Or set environment variables: `EXPEDAIT_TOKEN`, `EXPEDAIT_API_URL`, `EXPEDAIT_TENANT_ID`.

### Download Project Specs

```bash
uvx expedait-cli projects list --format json
uvx expedait-cli projects download PROJECT_ID --output-dir ./specs
```

### Post a Comment on a Spec Page

```bash
uvx expedait-cli pages get PAGE_ID
uvx expedait-cli comments create PAGE_ID \
  --text "Your comment" \
  --selected-text "exact text from page" \
  --start-offset START --end-offset END
```

Compute offsets: `start = content.index(selected_text)`, `end = start + len(selected_text)`.

### Review Code Against Specs

1. Download specs: `uvx expedait-cli projects download PROJECT_ID --output-dir ./specs`
2. Compare each spec against the implementation
3. Post inline comments for each discrepancy using `comments create`
4. Check existing comments first: `uvx expedait-cli pages full PAGE_ID`

### Tips

- Use `--format json` for machine-readable output
- Comments are auto-marked as agent comments
- Use `--source-page-id` to link comments back to your agent's page
AGENTS
)

  if [[ -f "$file" ]]; then
    echo "$content" >> "$file"
    info "AGENTS.md: appended Expedait section"
  else
    echo "# Project Instructions" > "$file"
    echo "$content" >> "$file"
    info "AGENTS.md: created with Expedait section"
  fi
}

install_opencode() { install_agents_md; }
install_codex()    { install_agents_md; }

# --- Auto-detect ---
detect_agents() {
  local agents=()
  # Claude Code: check for .claude dir or claude command
  if [[ -d "$TARGET_DIR/.claude" ]] || command -v claude &>/dev/null; then
    agents+=("claude-code")
  fi
  # Cursor: check for .cursor dir
  if [[ -d "$TARGET_DIR/.cursor" ]]; then
    agents+=("cursor")
  fi
  # OpenCode: check for AGENTS.md or opencode command
  if command -v opencode &>/dev/null; then
    agents+=("opencode")
  fi
  # Codex: check for .codex dir or codex command
  if [[ -d "$HOME/.codex" ]] || command -v codex &>/dev/null; then
    agents+=("codex")
  fi
  # If AGENTS.md exists, include it
  if [[ -f "$TARGET_DIR/AGENTS.md" ]] && [[ ${#agents[@]} -eq 0 ]]; then
    agents+=("opencode")
  fi
  # Default to claude-code if nothing detected
  if [[ ${#agents[@]} -eq 0 ]]; then
    agents+=("claude-code")
  fi
  echo "${agents[@]}"
}

install_agent() {
  case "$1" in
    claude-code) install_claude_code ;;
    cursor)      install_cursor ;;
    opencode)    install_opencode ;;
    codex)       install_codex ;;
    *) error "Unknown agent: $1"; exit 1 ;;
  esac
}

# --- Main ---
main() {
  local agent=""
  local all=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent)    agent="$2"; shift 2 ;;
      --all)      all=true; shift ;;
      --target)   TARGET_DIR="$2"; shift 2 ;;
      -h|--help)  usage; exit 0 ;;
      *)          error "Unknown option: $1"; usage; exit 1 ;;
    esac
  done

  # Resolve target to absolute path
  TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

  echo -e "${BOLD}Expedait Skills Installer${NC}"
  echo ""

  if [[ -n "$agent" ]]; then
    install_agent "$agent"
  elif $all; then
    install_claude_code
    install_cursor
    install_agents_md
  else
    local detected
    detected=$(detect_agents)
    echo "Detected agents: $detected"
    echo ""
    for a in $detected; do
      install_agent "$a"
    done
  fi

  echo ""
  echo -e "${BOLD}Next steps:${NC}"
  echo "  1. Authenticate: uvx expedait-cli auth login"
  echo "  2. Ask your agent to download specs or review code"
  echo ""
  echo -e "${BOLD}Tip:${NC} Claude Code users can also install via plugin:"
  echo "  /plugin marketplace add Expedait/expedait-skills"
  echo "  /plugin install expedait-skills@expedait"
}

main "$@"
