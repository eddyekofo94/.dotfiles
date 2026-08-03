#!/usr/bin/env python3
"""Measure repeatable CLI startup and peak RSS without making provider calls."""

from __future__ import annotations

import json
import os
import re
import statistics
import subprocess
import sys
import time
from pathlib import Path


PI_DIR = Path(__file__).resolve().parent
REPO_ROOT = PI_DIR.parent
EVIDENCE = Path(
    os.environ.get("PI_PILOT_EVIDENCE_DIR", PI_DIR / "evidence")
) / "runtime-benchmark.json"
RUNS = int(os.environ.get("PI_PILOT_BENCHMARK_RUNS", "7"))


def measure(label: str, command: list[str]) -> dict[str, object]:
    samples: list[dict[str, float | int]] = []
    for index in range(RUNS):
        started = time.perf_counter()
        completed = subprocess.run(
            ["/usr/bin/time", "-lp", *command],
            cwd=REPO_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        elapsed = time.perf_counter() - started
        if completed.returncode != 0:
            raise RuntimeError(
                f"{label} failed ({completed.returncode}): {completed.stderr}"
            )
        rss_match = re.search(
            r"^\s*(\d+)\s+maximum resident set size$",
            completed.stderr,
            re.MULTILINE,
        )
        if not rss_match:
            raise RuntimeError(f"{label} did not report maximum RSS")
        samples.append(
            {
                "run": index + 1,
                "cache_class": (
                    "initial_unwarmed_order"
                    if index == 0
                    else "subsequent_warm_candidate"
                ),
                "elapsed_seconds": round(elapsed, 6),
                "maximum_rss_bytes": int(rss_match.group(1)),
            }
        )

    elapsed_values = [float(item["elapsed_seconds"]) for item in samples]
    rss_values = [int(item["maximum_rss_bytes"]) for item in samples]
    warm_elapsed = [float(item["elapsed_seconds"]) for item in samples[1:]]
    warm_rss = [int(item["maximum_rss_bytes"]) for item in samples[1:]]
    return {
        "command": command,
        "runs": RUNS,
        "samples": samples,
        "initial_unwarmed_order_sample": samples[0],
        "subsequent_warm_candidate_median_elapsed_seconds": round(
            statistics.median(warm_elapsed), 6
        ),
        "subsequent_warm_candidate_median_maximum_rss_bytes": int(
            statistics.median(warm_rss)
        ),
        "median_elapsed_seconds": round(statistics.median(elapsed_values), 6),
        "median_maximum_rss_bytes": int(statistics.median(rss_values)),
        "peak_maximum_rss_bytes": max(rss_values),
    }


def main() -> int:
    if RUNS < 3:
        raise ValueError("PI_PILOT_BENCHMARK_RUNS must be at least 3")

    results = {
        "method": (
            "macOS /usr/bin/time -lp around version startup; no provider call; "
            "first ordered sample is distinguished from subsequent warm candidates"
        ),
        "cache_state_controlled": False,
        "cache_note": (
            "The benchmark does not purge macOS filesystem caches, so the first "
            "ordered sample is not claimed to be a controlled cold start."
        ),
        "recorded_at_unix": int(time.time()),
        "platform": {
            "machine": os.uname().machine,
            "release": os.uname().release,
        },
        "pi": measure("pi", [str(PI_DIR / "pilot.sh"), "--version"]),
        "codex": measure("codex", ["codex", "--version"]),
        "claude": measure("claude", ["claude", "--version"]),
    }
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    print(f"Pi runtime benchmark: PASS ({EVIDENCE})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
