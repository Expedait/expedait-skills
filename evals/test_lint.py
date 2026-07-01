"""Agent-free tests: the shipped skills pass Tier 1 lint, and lint catches regressions."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import lint  # noqa: E402


def test_all_shipped_skills_are_clean():
    results = lint.check_all()
    problems = {name: f for name, f in results.items() if f}
    assert not problems, f"lint findings in shipped skills: {problems}"


def test_lint_flags_unqualified_mcp_tool(tmp_path, monkeypatch):
    _run_body_check(tmp_path, monkeypatch,
                    "See the write_deliverable tool for details.",
                    expect_substr="unqualified MCP tool")


def test_lint_flags_time_sensitive(tmp_path, monkeypatch):
    _run_body_check(tmp_path, monkeypatch,
                    "This was formerly a page.",
                    expect_substr="time-sensitive")


def test_lint_allows_qualified_mcp_tool(tmp_path, monkeypatch):
    findings = _run_body_check(tmp_path, monkeypatch,
                               "Use expedait:write_deliverable to write.",
                               expect_substr=None)
    assert not any("MCP tool" in f for f in findings)


def _run_body_check(tmp_path, monkeypatch, body, expect_substr):
    """Write a synthetic skill and lint it, redirecting lint at the temp dir."""
    name = "expedait-download"  # reuse a real name so the name checks pass
    skill_dir = tmp_path / "skills" / name
    skill_dir.mkdir(parents=True)
    (skill_dir / "SKILL.md").write_text(
        f'---\nname: {name}\ndescription: "Third-person description of what it does and when to use it."\n---\n\n# Title\n\n{body}\n'
    )
    monkeypatch.setattr(lint, "SKILLS_DIR", tmp_path / "skills")
    findings = lint.check_skill(name)
    if expect_substr:
        assert any(expect_substr in f for f in findings), findings
    return findings
