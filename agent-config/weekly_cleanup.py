#!/usr/bin/env python3
"""Weekly disk cleanup: hands the work to BibleStandard's `tools/doctor.py` (FS-430).

Doctor owns what is safe to delete (DerivedData folders by age, stale `BS QA`
simulators, old agent state) and runs hourly as well; this job is the weekly
backstop and no longer wipes DerivedData wholesale. Dry run by default; pass
--apply to delete.
"""

import argparse
import subprocess
import sys
from pathlib import Path

DOCTOR = Path.home() / "Programming/Projects/CanonFidei/biblestandard/ios/tools/doctor.py"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="actually delete (default: dry run)")
    args = ap.parse_args()
    if not DOCTOR.exists():
        print(f"weekly_cleanup: {DOCTOR} not found", file=sys.stderr)
        return 1
    command = [sys.executable, str(DOCTOR), "--storage"] + (["--fix"] if args.apply else [])
    return subprocess.run(command, cwd=DOCTOR.parents[1], check=False).returncode


if __name__ == "__main__":
    sys.exit(main())
