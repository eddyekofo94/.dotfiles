"""A stand-in routing table for the opener tests (BS-IOS-FEAT-597): tests set
HERDR_ROUTES_REPO here so no test reads the real iOS table."""
import sys

verb, kind = sys.argv[1], sys.argv[-1]
if verb == "spec":
    print("opus xhigh" if kind != "other" else "sonnet high")
else:
    print({"build": "opus medium", "verdict": "sonnet medium"}.get(verb, "sonnet medium"))
