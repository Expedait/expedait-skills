#!/usr/bin/env python3
"""Local eval battery for the Expedait skills.

For each eval it builds a throwaway workspace, installs the skill under
`.claude/skills/`, puts the mock CLI (evals/mock) first on PATH so `uvx --from
expedait-cli expedait ...` hits the fake, runs Claude Code headless (`claude -p`), then
grades the recorded command log with grade.py. Grading is deterministic — it asserts on
which `expedait` commands the agent chose, not on prose.

Usage:
    python3 evals/runner.py                     # run every skill's evals with the agent
    python3 evals/runner.py --skill expedait-download
    python3 evals/runner.py --model claude-haiku-4-5-20251001
    python3 evals/runner.py --dry-run           # validate schema + mock wiring, no agent
    python3 evals/runner.py --keep              # keep workspaces under evals/.results/
    python3 evals/runner.py --json out.json     # also write machine-readable results

Exit code is non-zero if any eval fails (agent runs) or any schema/mock check fails
(dry run). If the `claude` CLI isn't on PATH, agent runs are skipped and the battery
exits 0 (so an unconfigured CI job stays green — gate the real battery on a secret).
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

EVALS_DIR = Path(__file__).resolve().parent
ROOT = EVALS_DIR.parent
SKILLS_DIR = ROOT / "skills"
MOCK_DIR = EVALS_DIR / "mock"

sys.path.insert(0, str(EVALS_DIR))
import grade  # noqa: E402

# Tools the skills declare in their frontmatter; nothing else is needed.
ALLOWED_TOOLS = "Bash Read Glob Grep Write"
# `--strict-mcp-config` with no `--mcp-config` loads ZERO MCP servers, so an
# Expedait MCP connector attached to the developer's session can't shadow the mock CLI —
# the battery must exercise the CLI path only. bypassPermissions lets the headless agent
# run the mock without prompting.
DEFAULT_CLAUDE_FLAGS = os.environ.get(
    "EVAL_CLAUDE_FLAGS", "--permission-mode bypassPermissions --strict-mcp-config"
).split()


def discover(skill_filter: str | None) -> list[Path]:
    paths = sorted(EVALS_DIR.glob("*/evals.json"))
    if skill_filter:
        paths = [p for p in paths if p.parent.name == skill_filter]
    return paths


def build_workspace(skill_name: str, eval_case: dict, ws: Path) -> None:
    """Populate a fresh workspace: the skill, any input files, optional git repo."""
    dest = ws / ".claude" / "skills" / skill_name
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(SKILLS_DIR / skill_name, dest)

    for rel, content in (eval_case.get("files") or {}).items():
        fp = ws / rel
        fp.parent.mkdir(parents=True, exist_ok=True)
        fp.write_text(content)

    if (eval_case.get("setup") or {}).get("git"):
        _init_git_repo(ws)


def _init_git_repo(ws: Path) -> None:
    env = {
        **os.environ,
        "GIT_AUTHOR_NAME": "eval", "GIT_AUTHOR_EMAIL": "eval@example.com",
        "GIT_COMMITTER_NAME": "eval", "GIT_COMMITTER_EMAIL": "eval@example.com",
    }
    run = lambda *a: subprocess.run(a, cwd=ws, env=env, check=True,
                                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    run("git", "init", "-q", "-b", "main")
    (ws / "README.md").write_text("# project\n")
    run("git", "add", "-A")
    run("git", "commit", "-qm", "initial")
    # A feature branch with a change, so the review skill's merge-base scoping has work.
    run("git", "checkout", "-q", "-b", "feature/auth")
    run("git", "commit", "-q", "--allow-empty", "-m", "wip auth")


def run_agent(prompt: str, ws: Path, model: str | None) -> tuple[bool, str]:
    """Invoke Claude Code headless in the workspace. Returns (ran_ok, detail)."""
    env = {
        **os.environ,
        "PATH": f"{MOCK_DIR}{os.pathsep}{os.environ['PATH']}",
        "EXPEDAIT_MOCK_LOG": str(ws / "commands.jsonl"),
    }
    cmd = ["claude", "-p", prompt, "--output-format", "json",
           "--allowedTools", ALLOWED_TOOLS, *DEFAULT_CLAUDE_FLAGS]
    if model:
        cmd += ["--model", model]
    try:
        proc = subprocess.run(cmd, cwd=ws, env=env, capture_output=True, text=True,
                              timeout=int(os.environ.get("EVAL_TIMEOUT", "300")))
    except subprocess.TimeoutExpired:
        return False, "agent timed out"
    if proc.returncode != 0:
        return False, f"claude exited {proc.returncode}: {proc.stderr.strip()[:400]}"
    return True, ""


def load_command_log(ws: Path) -> list[dict]:
    log = ws / "commands.jsonl"
    if not log.exists():
        return []
    out = []
    for line in log.read_text().splitlines():
        line = line.strip()
        if line:
            out.append(json.loads(line))
    return out


def grade_case(eval_case: dict, commands: list[dict]) -> list[dict]:
    assertions = eval_case.get("command_assertions") or {}
    return grade.grade_commands(commands, assertions)


def validate_case(eval_case: dict) -> list[str]:
    errors = []
    if "id" not in eval_case:
        errors.append("missing id")
    if not eval_case.get("prompt"):
        errors.append("missing prompt")
    ca = eval_case.get("command_assertions")
    if ca is None:
        errors.append("missing command_assertions (deterministic grading needs it)")
    else:
        errors += grade.validate_assertions(ca)
    return errors


def main() -> int:
    ap = argparse.ArgumentParser(description="Expedait skills eval battery")
    ap.add_argument("--skill", help="only this skill (e.g. expedait-download)")
    ap.add_argument("--model", help="model id passed to claude --model")
    ap.add_argument("--dry-run", action="store_true",
                    help="validate schema + mock wiring only, no agent")
    ap.add_argument("--discover", action="store_true",
                    help="use the raw prompt and rely on auto-trigger by description "
                         "(measures discovery); default invokes the skill explicitly as "
                         "/<skill>, matching how user-invocable skills are actually used")
    ap.add_argument("--keep", action="store_true",
                    help="keep workspaces under evals/.results/")
    ap.add_argument("--json", dest="json_out", help="write results JSON to this path")
    args = ap.parse_args()

    suites = discover(args.skill)
    if not suites:
        print("no evals found", file=sys.stderr)
        return 1

    have_claude = shutil.which("claude") is not None
    if not args.dry_run and not have_claude:
        print("NOTE: `claude` CLI not found on PATH — skipping agent runs (exit 0).")
        print("      Run with --dry-run to validate schema and mock wiring.")
        return 0

    results_root = None
    if args.keep:
        results_root = EVALS_DIR / ".results"
        if results_root.exists():
            shutil.rmtree(results_root)
        results_root.mkdir(parents=True)

    all_results = []
    total = passed = 0

    for suite_path in suites:
        suite = json.loads(suite_path.read_text())
        skill_name = suite["skill_name"]
        for case in suite["evals"]:
            total += 1
            cid = case.get("id")
            label = f"{skill_name}#{cid}"

            schema_errors = validate_case(case)
            if schema_errors:
                print(f"FAIL  {label}  (schema)")
                for e in schema_errors:
                    print(f"        - {e}")
                all_results.append({"eval": label, "passed": False, "schema_errors": schema_errors})
                continue

            if args.dry_run:
                passed += 1
                print(f"OK    {label}  (schema valid)")
                all_results.append({"eval": label, "passed": True, "dry_run": True})
                continue

            ctx = tempfile.mkdtemp(prefix=f"eval-{skill_name}-{cid}-")
            ws = Path(ctx)
            try:
                build_workspace(skill_name, case, ws)
                # Default: invoke the skill explicitly (`/<skill> ...`), matching how a
                # user actually runs a user-invocable skill. --discover uses the raw
                # prompt to measure auto-trigger-by-description instead.
                prompt = case["prompt"] if args.discover else f"/{skill_name} {case['prompt']}"
                started = time.perf_counter()
                ran_ok, detail = run_agent(prompt, ws, args.model)
                duration_ms = round((time.perf_counter() - started) * 1000)
                commands = load_command_log(ws)
                if not ran_ok:
                    print(f"FAIL  {label}  (agent: {detail})")
                    checks = [{"text": "agent run", "passed": False, "evidence": detail}]
                else:
                    checks = grade_case(case, commands)
                case_passed = ran_ok and grade.passed_all(checks)
                passed += int(case_passed)
                mark = "PASS" if case_passed else "FAIL"
                print(f"{mark}  {label}  ({len(commands)} cmd(s), {duration_ms}ms)")
                for c in checks:
                    if not c["passed"]:
                        print(f"        x {c['text']} — {c['evidence']}")
                all_results.append({
                    "eval": label, "passed": case_passed, "duration_ms": duration_ms,
                    "commands": commands, "checks": checks,
                })
                if results_root:
                    shutil.copytree(ws, results_root / f"{skill_name}-{cid}")
            finally:
                if not results_root:
                    shutil.rmtree(ws, ignore_errors=True)

    mode = "dry run" if args.dry_run else ("discover" if args.discover else "invoke")
    print(f"\n{passed}/{total} passed  [{mode} mode]")
    if args.json_out:
        Path(args.json_out).write_text(json.dumps(all_results, indent=2))
        print(f"wrote {args.json_out}")

    return 0 if passed == total else 1


if __name__ == "__main__":
    sys.exit(main())
