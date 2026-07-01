"""Deterministic grading of an agent's mock-CLI command log.

The battery evaluates what these skills exist to do: pick the right `expedait`
commands, flags, and order — and avoid destructive ones. When an eval runs, the mock
CLI (evals/mock/expedait) records every invocation to a JSONL log. This module grades
that log against an eval's `command_assertions`, with no LLM in the loop, so results are
deterministic and cheap.

A command log is a list of `{"argv": [...]}` dicts, one per mock `expedait` call.

`command_assertions` supports three keys, all optional:
  - must_call:     each matcher MUST match >= 1 logged command
  - must_not_call: each matcher MUST match 0 logged commands
  - order:         matchers must appear as a relative subsequence across the log

A matcher is one of:
  - {"args_contain": [tokens...]}  every token is a member of the command's argv
                                   (order-insensitive; robust to flag placement)
  - {"args_subseq":  [tokens...]}  tokens appear as an ordered subsequence of argv

Results use the field names {text, passed, evidence} so they line up with Anthropic's
skill-creator eval viewer if we ever pipe results into it.
"""

from __future__ import annotations


def _is_subseq(needles: list, hay: list) -> bool:
    """True if `needles` appear in `hay` in order (not necessarily contiguously)."""
    it = iter(hay)
    return all(any(n == h for h in it) for n in needles)


def _matches(argv: list, matcher: dict) -> bool:
    if "args_contain" in matcher:
        return all(tok in argv for tok in matcher["args_contain"])
    if "args_subseq" in matcher:
        return _is_subseq(matcher["args_subseq"], argv)
    raise ValueError(f"unknown matcher (need args_contain or args_subseq): {matcher!r}")


def _describe(matcher: dict) -> str:
    tokens = matcher.get("args_contain") or matcher.get("args_subseq") or []
    return " ".join(str(t) for t in tokens)


def validate_assertions(assertions: dict) -> list[str]:
    """Return a list of schema errors (empty if valid). Used by the runner's --dry-run."""
    errors: list[str] = []
    if not isinstance(assertions, dict):
        return [f"command_assertions must be an object, got {type(assertions).__name__}"]
    for key in ("must_call", "must_not_call", "order"):
        matchers = assertions.get(key, [])
        if not isinstance(matchers, list):
            errors.append(f"{key} must be a list")
            continue
        for m in matchers:
            if not isinstance(m, dict) or not ("args_contain" in m or "args_subseq" in m):
                errors.append(f"{key} matcher needs args_contain or args_subseq: {m!r}")
    return errors


def grade_commands(commands: list[dict], assertions: dict) -> list[dict]:
    """Grade a command log against command_assertions.

    Returns a list of {text, passed, evidence} dicts, one per assertion.
    """
    argvs = [c.get("argv", []) for c in commands]
    results: list[dict] = []

    for m in assertions.get("must_call", []):
        hits = [a for a in argvs if _matches(a, m)]
        results.append({
            "text": f"must call: {_describe(m)}",
            "passed": len(hits) > 0,
            "evidence": (
                f"matched {len(hits)} command(s), e.g. {hits[0]}" if hits
                else f"no match among {len(argvs)} logged command(s)"
            ),
        })

    for m in assertions.get("must_not_call", []):
        hits = [a for a in argvs if _matches(a, m)]
        results.append({
            "text": f"must NOT call: {_describe(m)}",
            "passed": len(hits) == 0,
            "evidence": "not called" if not hits else f"unexpectedly called {len(hits)}x: {hits[:2]}",
        })

    order = assertions.get("order")
    if order:
        positions: list[int] = []
        search_from = 0
        missing = None
        for m in order:
            found = None
            for i in range(search_from, len(argvs)):
                if _matches(argvs[i], m):
                    found = i
                    break
            if found is None:
                missing = m
                break
            positions.append(found)
            search_from = found + 1
        results.append({
            "text": "order: " + " -> ".join(_describe(m) for m in order),
            "passed": missing is None,
            "evidence": (
                f"appeared in order at positions {positions}" if missing is None
                else f"missing or out of order: {_describe(missing)} (matched so far: {positions})"
            ),
        })

    return results


def passed_all(results: list[dict]) -> bool:
    return all(r["passed"] for r in results)
