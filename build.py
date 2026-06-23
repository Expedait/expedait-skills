#!/usr/bin/env python3
"""Build platform-specific skill files from canonical SKILL.md sources.

Usage:
    uv run build.py          # generate all platform outputs
    uv run build.py --check  # exit 1 if platforms/ is out of sync
"""

import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).parent
SKILLS_DIR = ROOT / "skills"
PLATFORMS_DIR = ROOT / "platforms"

SKILL_NAMES = [
    "expedait-author",
    "expedait-comment",
    "expedait-download",
    "expedait-process",
    "expedait-review",
]


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------

def parse_skill_md(path: Path) -> dict:
    """Parse a SKILL.md file into frontmatter fields and body."""
    text = path.read_text()
    parts = text.split("---", 2)
    if len(parts) < 3:
        raise ValueError(f"Could not parse frontmatter in {path}")

    frontmatter_raw = parts[1].strip()
    body = parts[2].lstrip("\n")

    frontmatter = {}
    for line in frontmatter_raw.splitlines():
        match = re.match(r'^([\w-]+):\s*(.+)$', line)
        if match:
            key = match.group(1)
            value = match.group(2).strip().strip('"')
            frontmatter[key] = value

    return {
        "name": frontmatter.get("name", ""),
        "description": frontmatter.get("description", ""),
        "user-invocable": frontmatter.get("user-invocable", "true"),
        "allowed-tools": frontmatter.get("allowed-tools", ""),
        "argument-hint": frontmatter.get("argument-hint", ""),
        "body": body,
    }


# ---------------------------------------------------------------------------
# Generators
# ---------------------------------------------------------------------------

def build_codex(skill: dict, out_dir: Path):
    """Codex uses the same SKILL.md format. $ARGUMENTS works natively."""
    name = skill["name"]
    dest = out_dir / "codex" / "skills" / name / "SKILL.md"
    dest.parent.mkdir(parents=True, exist_ok=True)

    lines = [
        "---",
        f'name: {name}',
        f'description: "{skill["description"]}"',
    ]
    if skill["user-invocable"]:
        lines.append(f'user-invocable: {skill["user-invocable"]}')
    if skill["allowed-tools"]:
        lines.append(f'allowed-tools: {skill["allowed-tools"]}')
    if skill["argument-hint"]:
        lines.append(f'argument-hint: {skill["argument-hint"]}')
    lines.append("---")
    lines.append("")
    lines.append(skill["body"])

    dest.write_text("\n".join(lines))


def build_pi(skill: dict, out_dir: Path):
    """Pi (pi.dev) follows the Agent Skills standard: .pi/skills/<name>/SKILL.md.

    Pi's frontmatter recognizes name, description, and allowed-tools; user-invocable
    and argument-hint are not Pi fields, so they are omitted. $ARGUMENTS works natively.
    """
    name = skill["name"]
    dest = out_dir / "pi" / "skills" / name / "SKILL.md"
    dest.parent.mkdir(parents=True, exist_ok=True)

    lines = [
        "---",
        f'name: {name}',
        f'description: "{skill["description"]}"',
    ]
    if skill["allowed-tools"]:
        lines.append(f'allowed-tools: {skill["allowed-tools"]}')
    lines.append("---")
    lines.append("")
    lines.append(skill["body"])

    dest.write_text("\n".join(lines))


def build_opencode(skill: dict, out_dir: Path):
    """OpenCode uses .md with YAML frontmatter. $ARGUMENTS works natively."""
    name = skill["name"]
    dest = out_dir / "opencode" / "commands" / f"{name}.md"
    dest.parent.mkdir(parents=True, exist_ok=True)

    lines = [
        "---",
        f'description: "{skill["description"]}"',
        "subtask: true",
        "---",
        "",
        skill["body"],
    ]

    dest.write_text("\n".join(lines))


def build_gemini(skill: dict, out_dir: Path):
    """Gemini CLI uses TOML with description and prompt fields."""
    name = skill["name"]
    dest = out_dir / "gemini" / "commands" / f"{name}.toml"
    dest.parent.mkdir(parents=True, exist_ok=True)

    # Escape description for TOML double-quoted string
    desc_escaped = skill["description"].replace("\\", "\\\\").replace('"', '\\"')

    # Convert $ARGUMENTS to {{args}} for Gemini
    body = skill["body"].replace("$ARGUMENTS", "{{args}}")

    # Ensure body doesn't contain """ which would break TOML
    if '"""' in body:
        body = body.replace('"""', '""\\"')

    content = f'description = "{desc_escaped}"\n\nprompt = """\n{body}"""\n'
    dest.write_text(content)


def build_cursor(skill: dict, out_dir: Path):
    """Cursor uses .mdc rules — no argument substitution, strip $ARGUMENTS."""
    name = skill["name"]
    dest = out_dir / "cursor" / "rules" / f"{name}.mdc"
    dest.parent.mkdir(parents=True, exist_ok=True)

    # Cursor rules don't support argument placeholders — rewrite references
    body = skill["body"].replace("$ARGUMENTS", "the user's input")

    lines = [
        "---",
        f'description: "{skill["description"]}"',
        "alwaysApply: false",
        "---",
        "",
        body,
    ]

    dest.write_text("\n".join(lines))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def build_all():
    """Generate all platform outputs from SKILL.md sources."""
    # Clean previous output
    if PLATFORMS_DIR.exists():
        shutil.rmtree(PLATFORMS_DIR)

    for name in SKILL_NAMES:
        source = SKILLS_DIR / name / "SKILL.md"
        if not source.exists():
            print(f"ERROR: Missing {source}", file=sys.stderr)
            sys.exit(1)

        skill = parse_skill_md(source)
        build_codex(skill, PLATFORMS_DIR)
        build_pi(skill, PLATFORMS_DIR)
        build_opencode(skill, PLATFORMS_DIR)
        build_gemini(skill, PLATFORMS_DIR)
        build_cursor(skill, PLATFORMS_DIR)

    print(f"Generated platform files in {PLATFORMS_DIR}/")
    for platform in sorted(PLATFORMS_DIR.iterdir()):
        files = sorted(platform.rglob("*"))
        files = [f for f in files if f.is_file()]
        print(f"  {platform.name}/: {len(files)} files")


def check_sync():
    """Check if platforms/ is in sync with skills/. Exit 1 if not."""
    import tempfile

    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_platforms = Path(tmpdir) / "platforms"

        # Save current platforms
        if PLATFORMS_DIR.exists():
            shutil.copytree(PLATFORMS_DIR, tmp_platforms)

        # Rebuild
        build_all()

        # Compare
        if not tmp_platforms.exists():
            print("ERROR: platforms/ did not exist before. Run 'python build.py' and commit.")
            sys.exit(1)

        import filecmp
        dcmp = filecmp.dircmp(PLATFORMS_DIR, tmp_platforms)
        diffs = _find_diffs(dcmp)

        # Restore original
        shutil.rmtree(PLATFORMS_DIR)
        shutil.copytree(tmp_platforms, PLATFORMS_DIR)

        if diffs:
            print("ERROR: platforms/ is out of sync with skills/:")
            for d in diffs:
                print(f"  {d}")
            sys.exit(1)
        else:
            print("OK: platforms/ is in sync with skills/")


def _find_diffs(dcmp) -> list:
    """Recursively find differences in a dircmp result."""
    diffs = []
    for name in dcmp.left_only:
        diffs.append(f"new: {dcmp.left}/{name}")
    for name in dcmp.right_only:
        diffs.append(f"removed: {dcmp.right}/{name}")
    for name in dcmp.diff_files:
        diffs.append(f"changed: {name}")
    for sub_dcmp in dcmp.subdirs.values():
        diffs.extend(_find_diffs(sub_dcmp))
    return diffs


if __name__ == "__main__":
    if "--check" in sys.argv:
        check_sync()
    else:
        build_all()
