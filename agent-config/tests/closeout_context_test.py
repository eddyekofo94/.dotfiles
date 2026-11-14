"""closeout.sh context: full contract on prompt 1 and every 8th, one line between."""
import json, os, subprocess, tempfile
HOOK = os.path.join(os.path.dirname(__file__), "..", "claude", "closeout.sh")

def run(state, sid="s1"):
    out = subprocess.run(["sh", HOOK, "context"], input=json.dumps({"session_id": sid}),
                         capture_output=True, text=True, env={**os.environ, "CLOSEOUT_STATE": state}).stdout
    return json.loads(out)["hookSpecificOutput"]["additionalContext"]

with tempfile.TemporaryDirectory() as d:
    sizes = [len(run(d)) for _ in range(9)]
    assert sizes[0] > 1500 and sizes[8] > 1500, sizes
    assert all(s < 400 for s in sizes[1:8]), sizes
    assert "Enforced Closeout" in run(d, "other"), "a new session starts with the full contract"
print("closeout context cadence: PASS")
