#!/usr/bin/env bash
set -euo pipefail

# Expedait Skills Installer
# Detects your AI coding agent and installs the appropriate config files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
PLATFORMS_DIR="$SCRIPT_DIR/platforms"
TARGET_DIR="${TARGET_DIR:-.}"
VERSION="0.7.1"
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
                      claude-code, cursor, opencode, codex, gemini, pi,
                      windsurf, copilot, cline, zed, junie, amp
  --all             Install for all detected agents
  --target <dir>    Target project directory (default: current directory)
  --check           Check if installed skills are up to date
  --version         Show installed version
  -h, --help        Show this help

Examples:
  ./install.sh                    # Auto-detect and install
  ./install.sh --agent cursor     # Install for Cursor only
  ./install.sh --agent gemini     # Install for Gemini CLI
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

  for skill in expedait-download expedait-comment expedait-review expedait-author expedait-process expedait-update-skills; do
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
  info "  /expedait-author    — create/edit deliverables (MCP)"
  info "  /expedait-process   — design a project-type template (MCP)"
  info "  /expedait-update-skills — check for and install skill updates"
}

# --- Pi (pi.dev) ---
install_pi() {
  local dir="$TARGET_DIR/.pi/skills"
  local src="$PLATFORMS_DIR/pi/skills"

  for skill in expedait-download expedait-comment expedait-review expedait-author expedait-process expedait-update-skills; do
    mkdir -p "$dir/$skill"
    cp "$src/$skill/SKILL.md" "$dir/$skill/SKILL.md"
  done

  info "Pi: installed skills in $dir/"
  info "  expedait-download  — download project specs"
  info "  expedait-comment   — post a comment on a spec page"
  info "  expedait-review    — review code against specs"
  info "  expedait-author    — create/edit deliverables (MCP)"
  info "  expedait-process   — design a project-type template (MCP)"
  info "  expedait-update-skills — check for and install skill updates"
  info "  Invoke with /skill:expedait-download (or let Pi auto-load by description)"
}

# --- Cursor ---
install_cursor() {
  local dir="$TARGET_DIR/.cursor/rules"
  local src="$PLATFORMS_DIR/cursor/rules"
  mkdir -p "$dir"

  # Remove old monolithic rule if present
  if [[ -f "$dir/expedait.mdc" ]]; then
    rm "$dir/expedait.mdc"
    info "Cursor: removed old combined expedait.mdc (replaced by per-skill files)"
  fi

  for mdc in "$src"/*.mdc; do
    local name
    name=$(basename "$mdc")
    cp "$mdc" "$dir/$name"
  done

  info "Cursor: installed rules in $dir/"
  info "  expedait-download.mdc"
  info "  expedait-comment.mdc"
  info "  expedait-review.mdc"
  info "  expedait-author.mdc"
  info "  expedait-process.mdc"
}

# --- OpenCode ---
install_opencode() {
  local dir="$TARGET_DIR/.opencode/commands"
  local src="$PLATFORMS_DIR/opencode/commands"
  mkdir -p "$dir"

  for cmd in "$src"/*.md; do
    local name
    name=$(basename "$cmd")
    cp "$cmd" "$dir/$name"
  done

  info "OpenCode: installed commands in $dir/"
  info "  /expedait-download  — download project specs"
  info "  /expedait-comment   — post a comment on a spec page"
  info "  /expedait-review    — review code against specs"
  info "  /expedait-author    — create/edit deliverables (MCP)"
  info "  /expedait-process   — design a project-type template (MCP)"
  info "  /expedait-update-skills — check for and install skill updates"
}

# --- Codex ---
install_codex() {
  local dir="$TARGET_DIR/.codex/skills"
  local src="$PLATFORMS_DIR/codex/skills"

  for skill in expedait-download expedait-comment expedait-review expedait-author expedait-process expedait-update-skills; do
    mkdir -p "$dir/$skill"
    cp "$src/$skill/SKILL.md" "$dir/$skill/SKILL.md"
  done

  info "Codex: installed skills in $dir/"
  info "  expedait-download  — download project specs"
  info "  expedait-comment   — post a comment on a spec page"
  info "  expedait-review    — review code against specs"
  info "  expedait-author    — create/edit deliverables (MCP)"
  info "  expedait-process   — design a project-type template (MCP)"
  info "  expedait-update-skills — check for and install skill updates"
}

# --- Gemini CLI ---
install_gemini() {
  local dir="$TARGET_DIR/.gemini/commands"
  local src="$PLATFORMS_DIR/gemini/commands"
  mkdir -p "$dir"

  for toml in "$src"/*.toml; do
    local name
    name=$(basename "$toml")
    cp "$toml" "$dir/$name"
  done

  info "Gemini CLI: installed commands in $dir/"
  info "  /expedait-download  — download project specs"
  info "  /expedait-comment   — post a comment on a spec page"
  info "  /expedait-review    — review code against specs"
  info "  /expedait-author    — create/edit deliverables (MCP)"
  info "  /expedait-process   — design a project-type template (MCP)"
  info "  /expedait-update-skills — check for and install skill updates"
}

# --- Windsurf ---
install_windsurf() {
  local dir="$TARGET_DIR/.windsurf/rules"
  local src="$PLATFORMS_DIR/windsurf/rules"
  mkdir -p "$dir"

  for md in "$src"/*.md; do
    cp "$md" "$dir/$(basename "$md")"
  done

  info "Windsurf: installed rules in $dir/"
  info "  Each rule uses 'trigger: manual' — reference one with @expedait-download (etc.)"
}

# --- GitHub Copilot ---
install_copilot() {
  local dir="$TARGET_DIR/.github/prompts"
  local src="$PLATFORMS_DIR/copilot/prompts"
  mkdir -p "$dir"

  for md in "$src"/*.prompt.md; do
    cp "$md" "$dir/$(basename "$md")"
  done

  info "GitHub Copilot: installed prompt files in $dir/"
  info "  Run them in chat as /expedait-download, /expedait-comment, etc."
}

# --- Cline ---
install_cline() {
  local dir="$TARGET_DIR/.clinerules/workflows"
  local src="$PLATFORMS_DIR/cline/workflows"
  mkdir -p "$dir"

  for md in "$src"/*.md; do
    cp "$md" "$dir/$(basename "$md")"
  done

  info "Cline: installed workflows in $dir/"
  info "  Invoke a workflow by typing /expedait-download.md (etc.) in chat"
}

# --- Zed ---
install_zed() {
  local dir="$TARGET_DIR/.agents/skills"
  local src="$PLATFORMS_DIR/zed/skills"

  for skill in expedait-download expedait-comment expedait-review expedait-author expedait-process expedait-update-skills; do
    mkdir -p "$dir/$skill"
    cp "$src/$skill/SKILL.md" "$dir/$skill/SKILL.md"
  done

  info "Zed: installed Agent Skills in $dir/"
  info "  Invoke with /expedait-download or @expedait-download, or let Zed auto-load by description"
}

# --- JetBrains Junie ---
install_junie() {
  local dir="$TARGET_DIR/.junie/commands"
  local src="$PLATFORMS_DIR/junie/commands"
  mkdir -p "$dir"

  for md in "$src"/*.md; do
    cp "$md" "$dir/$(basename "$md")"
  done

  info "JetBrains Junie: installed slash commands in $dir/"
  info "  Invoke them as /expedait-download, /expedait-review, etc."
}

# --- Amp (Sourcegraph) ---
install_amp() {
  local dir="$TARGET_DIR/.agents/commands"
  local src="$PLATFORMS_DIR/amp/commands"
  mkdir -p "$dir"

  for md in "$src"/*.md; do
    cp "$md" "$dir/$(basename "$md")"
  done

  info "Amp: installed slash commands in $dir/"
  info "  Invoke them as /expedait-download, /expedait-review, etc."
}

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
  # OpenCode: check for .opencode dir or opencode command
  if [[ -d "$TARGET_DIR/.opencode" ]] || command -v opencode &>/dev/null; then
    agents+=("opencode")
  fi
  # Codex: check for .codex dir or codex command
  if [[ -d "$HOME/.codex" ]] || command -v codex &>/dev/null; then
    agents+=("codex")
  fi
  # Gemini CLI: check for .gemini dir or gemini command
  if [[ -d "$HOME/.gemini" ]] || command -v gemini &>/dev/null; then
    agents+=("gemini")
  fi
  # Pi (pi.dev): check for .pi dir or pi command
  if [[ -d "$TARGET_DIR/.pi" ]] || [[ -d "$HOME/.pi" ]] || command -v pi &>/dev/null; then
    agents+=("pi")
  fi
  # Windsurf: check for .windsurf dir
  if [[ -d "$TARGET_DIR/.windsurf" ]]; then
    agents+=("windsurf")
  fi
  # GitHub Copilot: check for existing prompt/instructions dirs
  if [[ -d "$TARGET_DIR/.github/prompts" ]] || [[ -f "$TARGET_DIR/.github/copilot-instructions.md" ]]; then
    agents+=("copilot")
  fi
  # Cline: check for .clinerules dir
  if [[ -d "$TARGET_DIR/.clinerules" ]]; then
    agents+=("cline")
  fi
  # Zed: check for .zed dir or zed command
  if [[ -d "$TARGET_DIR/.zed" ]] || command -v zed &>/dev/null; then
    agents+=("zed")
  fi
  # JetBrains Junie: check for .junie dir
  if [[ -d "$TARGET_DIR/.junie" ]]; then
    agents+=("junie")
  fi
  # Amp (Sourcegraph): check for .amp dir or amp command
  if [[ -d "$TARGET_DIR/.amp" ]] || command -v amp &>/dev/null; then
    agents+=("amp")
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
    gemini)      install_gemini ;;
    pi)          install_pi ;;
    windsurf)    install_windsurf ;;
    copilot)     install_copilot ;;
    cline)       install_cline ;;
    zed)         install_zed ;;
    junie)       install_junie ;;
    amp)         install_amp ;;
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
    install_opencode
    install_codex
    install_gemini
    install_pi
    install_windsurf
    install_copilot
    install_cline
    install_zed
    install_junie
    install_amp
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
