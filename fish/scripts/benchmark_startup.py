#!/usr/bin/env python3

import math
import statistics
import subprocess
import time

RUNS = 30
MEDIAN_LIMIT_MS = 40.0
P95_LIMIT_MS = 55.0

samples = []
for _ in range(RUNS):
    started = time.perf_counter()
    subprocess.run(
        ["fish", "-i", "-c", "exit"],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    samples.append((time.perf_counter() - started) * 1000)

ordered = sorted(samples)
median = statistics.median(samples)
p95 = ordered[math.ceil(0.95 * RUNS) - 1]
print(f"Fish startup benchmark: runs={RUNS} median={median:.3f}ms p95={p95:.3f}ms")

if median > MEDIAN_LIMIT_MS or p95 > P95_LIMIT_MS:
    raise SystemExit(
        "Fish startup benchmark: FAIL "
        f"(limits median<={MEDIAN_LIMIT_MS:.0f}ms p95<={P95_LIMIT_MS:.0f}ms)"
    )

print("Fish startup benchmark: PASS")
