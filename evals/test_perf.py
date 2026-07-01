"""Agent-free tests for the latency probe's percentile math."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import perf  # noqa: E402


def test_pct_bounds():
    values = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
    assert perf.pct(values, 100) == 100
    assert perf.pct(values, 0) == 10
    # p95 of 10 samples -> nearest-rank lands on the top sample
    assert perf.pct(values, 95) == 100
    # p50 sits in the lower half for nearest-rank
    assert perf.pct(values, 50) == 50


def test_pct_unsorted_input():
    assert perf.pct([30, 10, 20], 100) == 30


def test_pct_single_and_empty():
    assert perf.pct([42], 95) == 42
    assert perf.pct([], 95) != perf.pct([], 95)  # nan != nan
