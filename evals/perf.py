#!/usr/bin/env python3
"""Latency probe: how fast can a deliverable ("page") be retrieved?

Part of the eval battery's fidelity tier. A big part of the Expedait aha-moment is that
pulling a spec into the agent's context is *fast* — so this times the real read commands
against the live backend and reports p50/p95. Unlike runner.py it does NOT use the mock:
mock latency is meaningless. It needs real auth (`uvx --from expedait-cli expedait auth
login`) and network, so it is opt-in — run it locally or in a secret-gated nightly job,
never on the PR path.

    python3 evals/perf.py --deliverable 5
    python3 evals/perf.py --deliverable 5 --runs 10 --budget-ms 1500
    python3 evals/perf.py --deliverable 5 --context   # also time `context get`

Exit code is non-zero if p95 exceeds --budget-ms (when a budget is given).
"""

import argparse
import math
import statistics
import subprocess
import sys
import time

CLI = ["uvx", "--from", "expedait-cli", "expedait"]


def time_command(args: list[str], runs: int) -> tuple[list[float], str | None]:
    """Run `expedait <args>` `runs` times, return (durations_ms, error)."""
    durations: list[float] = []
    for i in range(runs):
        start = time.perf_counter()
        proc = subprocess.run(CLI + args, capture_output=True, text=True)
        elapsed_ms = (time.perf_counter() - start) * 1000
        if proc.returncode != 0:
            return durations, f"`expedait {' '.join(args)}` exited {proc.returncode}: {proc.stderr.strip()[:200]}"
        durations.append(elapsed_ms)
    return durations, None


def pct(values: list[float], p: float) -> float:
    """Nearest-rank percentile (values need not be sorted)."""
    if not values:
        return float("nan")
    s = sorted(values)
    rank = math.ceil(p / 100 * len(s))          # 1-based rank
    k = max(1, min(len(s), rank)) - 1           # clamp, then to 0-based index
    return s[k]


def report(label: str, durations: list[float]) -> None:
    print(f"{label:<32} n={len(durations):<3} "
          f"p50={statistics.median(durations):7.1f}ms  "
          f"p95={pct(durations, 95):7.1f}ms  "
          f"min={min(durations):7.1f}ms  max={max(durations):7.1f}ms")


def main() -> int:
    ap = argparse.ArgumentParser(description="Expedait deliverable retrieval latency probe")
    ap.add_argument("--deliverable", required=True, help="deliverable id to fetch")
    ap.add_argument("--runs", type=int, default=8, help="samples per command (default 8)")
    ap.add_argument("--budget-ms", type=float, help="fail if p95 exceeds this")
    ap.add_argument("--context", action="store_true", help="also time `context get`")
    ap.add_argument("--warmup", action="store_true", help="discard the first (cold) sample")
    args = ap.parse_args()

    probes = [("deliverables get (content)",
               ["deliverables", "get", args.deliverable, "--include", "content"])]
    if args.context:
        probes.append(("context get", ["context", "get", args.deliverable]))

    worst_p95 = 0.0
    for label, cmd in probes:
        durations, err = time_command(cmd, args.runs + (1 if args.warmup else 0))
        if err:
            print(f"ERROR: {err}", file=sys.stderr)
            return 2
        if args.warmup and durations:
            durations = durations[1:]
        report(label, durations)
        worst_p95 = max(worst_p95, pct(durations, 95))

    if args.budget_ms is not None:
        ok = worst_p95 <= args.budget_ms
        print(f"\n{'PASS' if ok else 'FAIL'}: worst p95 {worst_p95:.1f}ms "
              f"{'<=' if ok else '>'} budget {args.budget_ms:.1f}ms")
        return 0 if ok else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
