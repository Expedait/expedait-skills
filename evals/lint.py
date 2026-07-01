#!/usr/bin/env python3
"""Tier 1 static checks for the Expedait skills — no agent, no network.

Encodes Anthropic's skill-authoring rules so a regression (an over-long description, a
first-person voice, an unqualified MCP tool name) fails CI in seconds. Runs on every PR.

    python3 evals/lint.py        # prints findings, exits non-zero if any

Frontmatter parsing mirrors build.py (regex, no PyYAML dependency).
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = ROOT / "skills"

SKILL_NAMES = [
    "expedait-author", "expedait-comment", "expedait-download",
    "expedait-process", "expedait-review",
]

# Bare MCP tool names that must be qualified as `expedait:<tool>` (best-practices doc:
# "always use fully qualified tool names").
MCP_TOOLS = [
    "write_deliverable", "write_process", "write_role", "get_deliverable",
    "list_projects", "list_deliverables", "get_project_workspace",
    "get_objective_overview", "get_deliverable_context", "list_comments",
    "create_comment", "resolve_comment", "list_processes", "get_process",
    "list_roles", "list_review_issues", "mute_review_issue",
]

# Phrasing the best-practices doc calls out as time-sensitive / migration cruft.
# (Deliberately narrow: "no longer" is excluded because "the span is no longer present"
# is legitimate runtime wording, not migration cruft.)
TIME_SENSITIVE = [
    r"\bas of (?:cli )?\d+\.\d+", r"\bformerly\b", r"\bused to be called\b",
    r"\bbefore \w+ 20\d\d\b", r"\bafter \w+ 20\d\d\b",
]

# A Windows-style path separator: a path segment, a backslash, then a filename with an
# extension (e.g. scripts\helper.py). Narrow enough to skip JSON "\n"/"\t" escapes.
WINDOWS_PATH = re.compile(r"\b[\w-]+\\[\w-]+\.(?:py|md|json|sh|js|ts|txt|ya?ml|toml)\b")

FIRST_OR_SECOND_PERSON = [r"\bI can\b", r"\bI'll\b", r"\bI will\b", r"\byou can use this\b"]


def parse_frontmatter(path: Path) -> tuple[dict, str]:
    text = path.read_text()
    parts = text.split("---", 2)
    if len(parts) < 3:
        raise ValueError(f"no frontmatter in {path}")
    fm = {}
    for line in parts[1].strip().splitlines():
        m = re.match(r"^([\w-]+):\s*(.+)$", line)
        if m:
            fm[m.group(1)] = m.group(2).strip().strip('"')
    return fm, parts[2].lstrip("\n")


def check_skill(name: str) -> list[str]:
    """Return a list of finding strings for one skill (empty = clean)."""
    path = SKILLS_DIR / name / "SKILL.md"
    findings: list[str] = []
    fm, body = parse_frontmatter(path)

    # name
    nm = fm.get("name", "")
    if nm != name:
        findings.append(f"name '{nm}' != directory '{name}'")
    if not re.fullmatch(r"[a-z0-9-]+", nm):
        findings.append(f"name '{nm}' must be lowercase letters/numbers/hyphens only")
    if len(nm) > 64:
        findings.append(f"name is {len(nm)} chars (max 64)")
    if re.search(r"anthropic|claude", nm, re.I):
        findings.append(f"name '{nm}' contains a reserved word (anthropic/claude)")

    # description
    desc = fm.get("description", "")
    if not desc:
        findings.append("description is empty")
    if len(desc) > 1024:
        findings.append(f"description is {len(desc)} chars (max 1024)")
    if "<" in desc and re.search(r"<[a-zA-Z/]", desc):
        findings.append("description appears to contain an XML/HTML tag")
    for pat in FIRST_OR_SECOND_PERSON:
        if re.search(pat, desc):
            findings.append(f"description not third-person (matched /{pat}/)")

    # body length (best practice: < 500 lines)
    n_lines = len(body.splitlines())
    if n_lines >= 500:
        findings.append(f"body is {n_lines} lines (keep under 500)")

    # forward slashes only
    if WINDOWS_PATH.search(body):
        findings.append("body appears to use a Windows-style backslash path")

    # time-sensitive phrasing
    for pat in TIME_SENSITIVE:
        for m in re.finditer(pat, body, re.I):
            line_no = body[: m.start()].count("\n") + 1
            findings.append(f"time-sensitive phrasing '{m.group(0)}' (body line {line_no})")

    # unqualified MCP tool names
    alt = "|".join(map(re.escape, MCP_TOOLS))
    for m in re.finditer(rf"(?<![:\w])({alt})\b", body):
        # allowed when preceded by 'expedait:'
        start = m.start()
        if body[max(0, start - 9):start].endswith("expedait:"):
            continue
        line_no = body[:start].count("\n") + 1
        findings.append(f"unqualified MCP tool '{m.group(1)}' (body line {line_no}); use expedait:{m.group(1)}")

    return findings


def check_all() -> dict[str, list[str]]:
    return {name: check_skill(name) for name in SKILL_NAMES}


def main() -> int:
    results = check_all()
    total = 0
    for name, findings in results.items():
        if findings:
            print(f"FAIL  {name}")
            for f in findings:
                print(f"        - {f}")
            total += len(findings)
        else:
            print(f"OK    {name}")
    if total:
        print(f"\n{total} finding(s)")
        return 1
    print("\nall skills clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
