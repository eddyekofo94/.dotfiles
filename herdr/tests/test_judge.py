"""Master plan B7: a green /build never lands itself. It marks itself ready
(`ready mark ID`), the master wakes with `judge: NAME RECORD` (exit 3), and answers
`land` or `sent back: <why>`; the board shows Working / Ready / Sent back / Done with wait time."""
import contextlib, io, json, os, pathlib, subprocess, sys, tempfile, time, unittest

HERE = pathlib.Path(__file__).resolve().parents[1]


class Judge(unittest.TestCase):
    def setUp(self):
        self.state = pathlib.Path(tempfile.mkdtemp(prefix="judge-"))
        self.env = {**os.environ, "AGENT_STATE_DIR": str(self.state), "AGENT_NAME": "bs-ios-feat-9"}

    def ready(self, *args, name=True):
        env = self.env if name else {k: v for k, v in self.env.items() if k != "AGENT_NAME"}
        done = subprocess.run([sys.executable, str(HERE / "ready.py"), *args], env=env,
                              capture_output=True, text=True, timeout=30)
        return done.returncode, done.stdout.strip(), done.stderr.strip()

    def wake(self, name="bs-ios-feat-9"):
        done = subprocess.run([sys.executable, str(HERE / "board.py"), "--wake", name], env=self.env,
                              capture_output=True, text=True, timeout=30)
        return done.returncode, done.stdout.strip()

    def test_mark_wake_back_mark_land_clear(self):
        code, out, _ = self.ready("mark", "BS-IOS-FEAT-9")
        self.assertEqual(code, 0)
        self.assertIn("do not land", out)
        self.assertEqual(self.wake(), (3, "judge: bs-ios-feat-9 BS-IOS-FEAT-9 (waited 0m)"))

        self.assertEqual(self.ready("judge", "bs-ios-feat-9", "back", "the empty state shows no copy")[:2],
                         (0, "sent back: the empty state shows no copy"))
        self.assertNotEqual(self.wake()[0], 3)  # sent back: no second judge wake
        self.assertEqual(self.ready("judge", "bs-ios-feat-9", "land")[0], 1)  # not waiting

        self.ready("mark", "BS-IOS-FEAT-9")
        self.assertEqual(self.wake()[0], 3)
        self.assertEqual(self.ready("judge", "bs-ios-feat-9", "land")[:2], (0, "land"))
        self.assertEqual(json.loads(self.ready("show", "bs-ios-feat-9")[1])["state"], "landing")
        self.assertEqual(self.ready("clear")[0], 0)
        self.assertEqual(self.ready("show", "bs-ios-feat-9")[0], 1)

    def test_back_needs_a_why_and_a_waiting_tab(self):
        self.assertEqual(self.ready("judge", "nobody", "land")[0], 1)
        self.ready("mark", "BS-IOS-FEAT-9")
        self.assertEqual(self.ready("judge", "bs-ios-feat-9", "back")[0], 2)
        self.assertEqual(json.loads(self.ready("show", "bs-ios-feat-9")[1])["state"], "ready")

    def test_mark_needs_a_name(self):
        self.assertNotEqual(self.ready("mark", "BS-IOS-FEAT-9", name=False)[0], 0)
        self.assertEqual(self.ready("mark", "BS-IOS-FEAT-9", "--name", "ios-home", name=False)[0], 0)

    def test_list_shows_the_wait_oldest_first(self):
        ready_dir = self.state / "ready"
        ready_dir.mkdir()
        now = time.time()
        for name, ago in (("ios-home", 600), ("bs-api-feat-2", 2 * 3600 + 5 * 60)):
            (ready_dir / f"{name}.json").write_text(json.dumps(
                {"name": name, "record": name.upper(), "state": "ready", "why": "", "at": now - ago, "cwd": "/"}))
        rows = self.ready("list")[1].splitlines()
        self.assertTrue(rows[0].startswith("ready") and "bs-api-feat-2" in rows[0] and rows[0].endswith("2h05m"), rows)
        self.assertTrue("ios-home" in rows[1] and rows[1].endswith("10m"), rows)
        self.assertEqual([e["waited"] for e in json.loads(self.ready("list", "--json")[1])], ["2h05m", "10m"])
        empty = pathlib.Path(tempfile.mkdtemp())
        self.env["AGENT_STATE_DIR"] = str(empty)
        self.assertEqual(self.ready("list")[1], "nobody waiting on a judge")

    def test_the_board_column(self):
        sys.path.insert(0, str(HERE))
        import board  # noqa: E402
        row = dict(window="w1", label="2 x", record="BS-IOS-FEAT-9", herdr_state="idle", state="idle",
                   status="", updated=time.time(), next_move="")
        tabs = [dict(row, name="a", herdr_state="working", state=""), dict(row, name="b"),
                dict(row, name="c"), dict(row, name="d", status="DONE")]
        judge = {"b": {"state": "ready", "waited": "4m"}, "c": {"state": "sent_back", "waited": "1m"}}
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            board.print_board({"machine": {"may_open": True, "pressure": "normal", "load": 1, "cores": 8,
                                           "simulators": 0}, "lanes": {}, "tabs": tabs, "judge": judge})
        lines = out.getvalue().splitlines()[-4:]
        for line, want in zip(lines, ("Working", "Ready 4m", "Sent back 1m", "Done")):
            self.assertIn(f" {want} ", line + " ")


if __name__ == "__main__":
    unittest.main()
