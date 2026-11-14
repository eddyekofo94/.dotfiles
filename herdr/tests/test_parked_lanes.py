"""Eddy, 2026-11-14: a parked lane (Bible) opens nothing from the fill."""
import json, pathlib, subprocess, unittest
JQ = pathlib.Path(__file__).resolve().parents[1] / "parked_lanes.jq"

class Parked(unittest.TestCase):
    def run_jq(self, doc):
        out = subprocess.run(["jq", "-c", "--argjson", "p", '["Bible"]', "-f", str(JQ)],
                             input=json.dumps(doc), capture_output=True, text=True, check=True).stdout
        return json.loads(out)
    def test_bible_batch_and_records_leave(self):
        r = self.run_jq({"batch": {"lane": "Bible", "ids": ["A"]},
                         "next": [{"id": "A", "track": "Bible"}, {"id": "H", "track": "Home"}],
                         "resume": [{"id": "B", "track": "Bible"}]})
        self.assertNotIn("batch", r)
        self.assertEqual([x["id"] for x in r["next"]], ["H"])
        self.assertEqual(r["resume"], [])
    def test_home_batch_stays(self):
        r = self.run_jq({"batch": {"lane": "Home", "ids": ["H"]}, "next": [{"id": "H", "track": "Home"}]})
        self.assertEqual(r["batch"]["lane"], "Home")

if __name__ == "__main__":
    unittest.main()
