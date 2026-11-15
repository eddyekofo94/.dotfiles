"""Eddy, 2026-11-15: a data record that only runs the hunter on one lane (its Disposition
starts "finetune — runs the hunter on one lane", BS-DATA-TASK-147) builds on Sonnet medium;
every other build stays Opus medium, and HERDR_ALLOW_HIGH=1 still lifts the clamp."""
import os as _os, tempfile as _tempfile  # master plan B6: never find the live master
_os.environ["HERDR_SESSIONS_DIR"] = _tempfile.mkdtemp(prefix="no-master-"); _os.environ["AGENT_STATE_DIR"] = _tempfile.mkdtemp(prefix="state-")
import pathlib, subprocess, unittest

from test_model_route import HERDR, TABLE, env, goal_done_fill, repo

HUNT = "BS-DATA-TASK-147"
CODE = "BS-DATA-TASK-145"


def with_records(root: pathlib.Path) -> pathlib.Path:
    specs = root / "project" / "specs"
    specs.mkdir(parents=True, exist_ok=True)
    (specs / f"{HUNT}-source-hunt-lane-puritan.md").write_text(
        "# Puritan lane\n\n- Disposition: finetune — runs the hunter on one lane; adds a finder only where named below.\n")
    (specs / f"{CODE}-the-source-hunter.md").write_text(
        "# The hunter\n\n- Disposition: new — `tools/library/source_hunt.py`.\n")
    return root


def route(root: pathlib.Path, *args: str, allow_high: bool = False) -> str:
    script = f'. "{HERDR / "model_route.sh"}"; model_route "$1" "${{@:2}}"; echo "$ROUTE_MODEL $ROUTE_EFFORT"'
    run_env = {**env(root), "HERDR_ROUTES_REPO": str(root), "HERDR_ALLOW_HIGH": "1" if allow_high else "0"}
    run = subprocess.run(["bash", "-c", script, "route", str(root), *args], env=run_env,
                         capture_output=True, text=True, timeout=30)
    return run.stdout.strip().splitlines()[-1]


class ModelRoute(unittest.TestCase):
    def test_a_hunt_record_build_opens_sonnet_medium(self):
        self.assertEqual(route(with_records(repo(TABLE)), "build", "--record", HUNT), "sonnet medium")

    def test_a_code_record_build_stays_opus_medium(self):
        root = with_records(repo(TABLE))
        self.assertEqual(route(root, "build", "--record", CODE), "opus medium")
        self.assertEqual(route(root, "build", "app"), "opus medium")

    def test_a_hunt_spec_is_not_touched(self):
        # The stand-in table routes this record's spec Sonnet; the exception is build-only.
        self.assertEqual(route(with_records(repo(TABLE)), "spec", "--record", HUNT), "sonnet medium")

    def test_allow_high_still_lifts_the_clamp(self):
        self.assertEqual(route(with_records(repo(TABLE)), "build", "--record", HUNT, allow_high=True), "opus medium")


def goals(root: pathlib.Path, *args: str) -> str:
    # goals.sh opens a BS-DATA record in the data checkout; point it at the stand-in, and
    # stand in a free group lane so a live data build on this Mac never holds the test.
    lane = root / "bin" / "group-lane"
    lane.write_text("#!/bin/sh\nexit 0\n")
    lane.chmod(0o755)
    run = subprocess.run(["bash", str(HERDR / "goals.sh"), *args, "--dry-run"],
                         env={**env(root), "BS_DATA_DIR": str(root)}, capture_output=True, text=True, cwd=root)
    return run.stdout + run.stderr


class Openers(unittest.TestCase):
    def test_goals_single_build_of_a_hunt_record_opens_sonnet(self):
        out = goals(with_records(repo(TABLE)), "--build", HUNT)
        self.assertIn("launch: claude --model sonnet --effort medium", out)

    def test_goals_single_build_of_a_code_record_opens_opus(self):
        out = goals(with_records(repo(TABLE)), "--build", CODE)
        self.assertIn("launch: claude --model opus --effort medium", out)

    def test_fill_opens_a_hunt_record_on_sonnet(self):
        out = goal_done_fill(with_records(repo(TABLE, {"next": [{"id": HUNT}]})))
        self.assertIn(f'--model sonnet --effort medium --permission-mode auto "/build {HUNT}"', out)

    def test_fill_keeps_a_code_record_on_opus(self):
        out = goal_done_fill(with_records(repo(TABLE, {"next": [{"id": CODE}]})))
        self.assertIn(f'--model opus --effort medium --permission-mode auto "/build {CODE}"', out)


if __name__ == "__main__":
    unittest.main()
