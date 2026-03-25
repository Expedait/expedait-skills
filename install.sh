#!/usr/bin/env bash
set -euo pipefail

# Expedait Skills Installer
# Detects your AI coding agent and installs the appropriate config files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
TARGET_DIR="${TARGET_DIR:-.}"
VERSION="0.1.0"
VERSION_FILE=".expedait-skills-version"
GITHUB_LATEST="https://api.github.com/repos/Expedait/expedait-skills/releases/latest"

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
  --check           Check if installed skills are up to date
  --version         Show installed version
  -h, --help        Show this help

Examples:
  ./install.sh                    # Auto-detect and install
  ./install.sh --agent cursor     # Install for Cursor only
  ./install.sh --all              # Install for all agents
  ./install.sh --target ~/myapp   # Install into a specific project
EOF
}

# --- Version check ---
check_update() {
  local installed="unknown"
  if [[ -f "$TARGET_DIR/$VERSION_FILE" ]]; then
    installed=$(cat "$TARGET_DIR/$VERSION_FILE")
  fi

  local latest
  latest=$(curl -sf "$GITHUB_LATEST" | grep -o '"tag_name":"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/^v//') || true

  if [[ -z "$latest" ]]; then
    warn "Could not reach GitHub API to check for updates"
    echo "  Installed: $installed"
    return
  fi

  if [[ "$installed" == "$latest" ]]; then
    info "Up to date (v$installed)"
  else
    warn "Installed: v$installed, Latest: v$latest"
    echo "  Run: curl -fsSL https://raw.githubusercontent.com/Expedait/expedait-skills/main/install.sh | bash"
  fi
}

write_version() {
  echo "$VERSION" > "$TARGET_DIR/$VERSION_FILE"
}

# --- Claude Code ---
install_claude_code() {
  local dir="$TARGET_DIR/.claude/skills"

  # Copy each skill's SKILL.md from the source
  for skill in expedait-download expedait-comment expedait-review; do
    if [[ ! -f "$SKILLS_DIR/$skill/SKILL.md" ]]; then
      error "Missing skill source: $SKILLS_DIR/$skill/SKILL.md"
      exit 1
    fi
    mkdir -p "$dir/$skill"
    cp "$SKILLS_DIR/$skill/SKILL.md" "$dir/$skill/SKILL.md"
  done

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

Use `uvx expedait-cli` for all Expedait commands — it runs in an isolated environment via uv, so no global install or virtual environment is needed.

## Authentication

The user must authenticate first:
```bash
uvx expedait-cli auth login
uvx expedait-cli auth status  # verify credentials
```

Or via environment variables: `EXPEDAIT_TOKEN`, `EXPEDAIT_API_URL`, `EXPEDAIT_TENANT_ID`.

## Project Setup

Initialize the project directory (creates `.expedait/settings.json`):
```bash
uvx expedait-cli init
```

Settings are resolved in order: CLI flag → environment variable → local config → home directory config.

## Download Project Specs

```bash
uvx expedait-cli projects list
uvx expedait-cli projects download PROJECT_ID
```

Downloaded specs are markdown files organized by phase in `.expedait/context/`.

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

# Resolve or delete a comment
uvx expedait-cli comments resolve PAGE_ID COMMENT_ID
uvx expedait-cli comments delete PAGE_ID COMMENT_ID
```

Compute offsets: `start = content.index(selected_text)`, `end = start + len(selected_text)`.

## Review Code Against Specs

Automatically scopes to branch changes on feature branches, full audit on default branch:

```bash
# Determine scope (feature branch)
MERGE_BASE=$(git merge-base HEAD origin/main)
git diff --name-only "$MERGE_BASE"..HEAD

# Fetch fresh specs — focus on PRD and product vision
uvx expedait-cli projects download PROJECT_ID
```

1. Compare PRD and vision specs against code in scope
2. Produce a local consistency report (Conflicts, Missing, Unspecified, Aligned)
3. Does NOT auto-post comments — use `comments create` for findings worth flagging

Flag: conflicts (spec says X, code does Y), missing requirements, unspecified code.
Skip: naming differences, open implementation details, WIP code.

## Tips

- Output format auto-detects: text for terminal, JSON when piped. Use `--format json` to force JSON output
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

Use `uvx expedait-cli` for all Expedait commands — it runs in an isolated environment via uv, so no global install or virtual environment is needed.

### Authentication

```bash
uvx expedait-cli auth login
uvx expedait-cli auth status  # verify credentials
```

Or set environment variables: `EXPEDAIT_TOKEN`, `EXPEDAIT_API_URL`, `EXPEDAIT_TENANT_ID`.

### Project Setup

Initialize the project directory (creates `.expedait/settings.json`):
```bash
uvx expedait-cli init
```

Settings are resolved in order: CLI flag → environment variable → local config → home directory config.

### Download Project Specs

```bash
uvx expedait-cli projects list
uvx expedait-cli projects download PROJECT_ID
```

Downloads to `.expedait/context/` by default.

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

Scopes automatically to branch changes on feature branches, full audit on default branch:

```bash
MERGE_BASE=$(git merge-base HEAD origin/main)
git diff --name-only "$MERGE_BASE"..HEAD  # scope on feature branches
uvx expedait-cli projects download PROJECT_ID  # fetch fresh specs
```

1. Focus on PRD and product vision specs
2. Produce a local consistency report (Conflicts, Missing, Unspecified, Aligned)
3. Does NOT auto-post comments — use `comments create` for findings worth flagging

### Tips

- Output format auto-detects: text for terminal, JSON when piped. Use `--format json` to force JSON output
- Comments are auto-marked as agent comments
- Use `--source-page-id` to link comments back to your agent's page
- Resolve comments with `uvx expedait-cli comments resolve PAGE_ID COMMENT_ID`
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
      --check)    TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"; check_update; exit 0 ;;
      --version)  echo "$VERSION"; exit 0 ;;
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

  write_version

  echo ""
  echo -e "${BOLD}Next steps:${NC}"
  echo "  1. Authenticate: uvx expedait-cli auth login"
  echo "  2. Initialize project: uvx expedait-cli init"
  echo "  3. Ask your agent to download specs or review code"
  echo ""
  echo -e "${BOLD}Tip:${NC} Claude Code users can also install via plugin:"
  echo "  /plugin marketplace add Expedait/expedait-skills"
  echo "  /plugin install expedait-skills@expedait"
}

main "$@"
