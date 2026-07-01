"""Agent-free unit tests for the deterministic grader. Run: pytest evals/."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import grade  # noqa: E402


def log(*argvs):
    return [{"argv": list(a)} for a in argvs]


def test_must_call_pass_and_fail():
    commands = log(["projects", "download", "1", "--output-dir", "ctx"])
    res = grade.grade_commands(commands, {"must_call": [{"args_contain": ["projects", "download"]}]})
    assert grade.passed_all(res)

    res = grade.grade_commands(commands, {"must_call": [{"args_contain": ["projects", "list"]}]})
    assert not grade.passed_all(res)
    assert "no match" in res[0]["evidence"]


def test_must_not_call():
    commands = log(["deliverables", "get", "5"], ["deliverables", "delete", "5"])
    res = grade.grade_commands(commands, {"must_not_call": [{"args_contain": ["deliverables", "delete"]}]})
    assert not grade.passed_all(res)

    clean = log(["deliverables", "get", "5"])
    res = grade.grade_commands(clean, {"must_not_call": [{"args_contain": ["deliverables", "delete"]}]})
    assert grade.passed_all(res)


def test_order_subsequence():
    commands = log(
        ["deliverables", "get", "5"],
        ["something", "else"],
        ["comments", "create", "5", "--text", "x"],
    )
    ok = grade.grade_commands(commands, {"order": [
        {"args_contain": ["deliverables", "get", "5"]},
        {"args_contain": ["comments", "create"]},
    ]})
    assert grade.passed_all(ok)

    reversed_log = log(
        ["comments", "create", "5"],
        ["deliverables", "get", "5"],
    )
    bad = grade.grade_commands(reversed_log, {"order": [
        {"args_contain": ["deliverables", "get", "5"]},
        {"args_contain": ["comments", "create"]},
    ]})
    assert not grade.passed_all(bad)


def test_args_subseq_matcher():
    commands = log(["deliverables", "get", "5", "--include", "content"])
    res = grade.grade_commands(commands, {"must_call": [
        {"args_subseq": ["deliverables", "get", "--include"]},
    ]})
    assert grade.passed_all(res)
    # tokens out of order fail a subseq matcher
    res = grade.grade_commands(commands, {"must_call": [
        {"args_subseq": ["--include", "get"]},
    ]})
    assert not grade.passed_all(res)


def test_validate_assertions():
    assert grade.validate_assertions({"must_call": [{"args_contain": ["a"]}]}) == []
    errs = grade.validate_assertions({"must_call": [{"nope": ["a"]}]})
    assert errs and "args_contain" in errs[0]
