from __future__ import annotations

import contextlib
import importlib.util
import json
import os
import statistics
import subprocess
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

MODULE_PATH = Path(__file__).resolve().parents[1] / "project_catalog.py"
SPEC = importlib.util.spec_from_file_location("project_catalog", MODULE_PATH)
pc = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(pc)


class CatalogTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name).resolve()
        self.home = self.root / "home"
        self.home.mkdir()
        self.config = self.root / "catalog.json"
        self.cache = self.root / "cache.json"
        self.nvim = self.root / "nvim.json"
        self.zoxide = self.root / "zoxide.txt"
        self.environment = mock.patch.dict(os.environ, {
            "HOME": str(self.home),
            "HERDR_PROJECT_CATALOG_CONFIG": str(self.config),
            "HERDR_PROJECT_CATALOG_CACHE": str(self.cache),
            "HERDR_PROJECT_NEOVIM_HISTORY": str(self.nvim),
            "HERDR_PROJECT_ZOXIDE_LIST": str(self.zoxide),
        }, clear=False)
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.zoxide.write_text("")
        self.write_config([], [], [])

    def tearDown(self):
        self.temp.cleanup()

    def write_config(self, roots, explicit, pins):
        self.config.write_text(json.dumps({"version": 1, "roots": roots, "explicit_projects": explicit, "pins": pins}))

    def git_repo(self, relative):
        path = self.root / relative
        path.mkdir(parents=True)
        subprocess.run(["git", "init", "-q", str(path)], check=True)
        return path.resolve()

    def refresh(self):
        self.assertEqual(pc.refresh(), 0)
        value = pc.load_cache()
        self.assertIsNotNone(value)
        return value

    def test_config_rejects_schema_errors_and_mid_path_tilde(self):
        self.write_config([{"path": "/tmp/~bad", "max_project_depth": 1}], [], [])
        with self.assertRaisesRegex(ValueError, "only at the start"):
            pc.load_config()
        self.config.write_text('{"version":2}')
        with self.assertRaisesRegex(ValueError, "version 1"):
            pc.load_config()

    def test_aliases_deduplicate_and_linked_worktree_stays_distinct(self):
        main = self.git_repo("projects/main")
        subprocess.run(["git", "-C", str(main), "config", "user.email", "catalog@example.invalid"], check=True)
        subprocess.run(["git", "-C", str(main), "config", "user.name", "Catalog"], check=True)
        (main / "README").write_text("fixture\n")
        subprocess.run(["git", "-C", str(main), "add", "README"], check=True)
        subprocess.run(["git", "-C", str(main), "commit", "-qm", "fixture"], check=True)
        linked = (self.root / "outside/linked").resolve()
        linked.parent.mkdir()
        subprocess.run(["git", "-C", str(main), "worktree", "add", "-qb", "linked", str(linked)], check=True)
        alias = self.root / "alias"
        alias.symlink_to(main)
        self.nvim.write_text(json.dumps([{"path": str(alias), "name": "main alias"}]))
        self.zoxide.write_text("99.0 %s\n" % alias)
        self.write_config([{"path": str(main.parent), "max_project_depth": 1}], [], [])
        records = self.refresh()["records"]
        self.assertEqual({item["path"] for item in records}, {str(main), str(linked)})
        main_record = next(item for item in records if item["path"] == str(main))
        self.assertIn(str(alias), main_record["aliases"])
        self.assertEqual(main_record["kind"], "main")
        linked_record = next(item for item in records if item["path"] == str(linked))
        self.assertEqual(linked_record["kind"], "worktree")
        self.assertEqual(linked_record["main_worktree"], str(main))

    def test_git_identity_omits_prunable_worktrees(self):
        main = self.root / "main"
        linked = self.root / "linked"
        prunable = self.root / "prunable"
        for path in (main, linked, prunable):
            path.mkdir()
        top = subprocess.CompletedProcess([], 0, str(main) + "\n", "")
        listing = "worktree %s\nHEAD 1\n\nworktree %s\nHEAD 2\n\nworktree %s\nHEAD 3\nprunable reason\n" % (main, linked, prunable)
        with mock.patch.object(subprocess, "run", return_value=top), mock.patch.object(pc, "run", return_value=listing):
            identity = pc.git_identity(main, time.monotonic() + 1)
        self.assertEqual(identity, ("main", main, [main, linked]))

    def test_adapters_cannot_admit_nested_or_non_git_candidates(self):
        repo = self.git_repo("repo")
        nested = repo / "nested"
        nested.mkdir()
        ordinary = self.root / "ordinary"
        ordinary.mkdir()
        self.nvim.write_text(json.dumps([str(nested), str(ordinary)]))
        self.zoxide.write_text("8.0 %s\n7.0 %s\n" % (nested, ordinary))
        records = self.refresh()["records"]
        self.assertEqual(records, [])

    def test_explicit_non_git_is_admitted_and_pin_must_be_accepted(self):
        ordinary = self.root / "ordinary"
        ordinary.mkdir()
        self.write_config([], [{"path": str(ordinary), "label": "Notes"}], [str(ordinary)])
        record = self.refresh()["records"][0]
        self.assertEqual((record["label"], record["kind"], record["ranking_reason"]), ("Notes", "explicit-non-git", "pin"))
        self.write_config([], [], [str(ordinary)])
        before = self.cache.read_bytes()
        self.assertEqual(pc.refresh(), 1)
        self.assertEqual(self.cache.read_bytes(), before)

    def test_ranking_precedence_and_selection_recency_survive_refresh(self):
        repos = [self.git_repo(name) for name in ("pin", "chosen", "nvim", "zoxide", "discovered")]
        self.nvim.write_text(json.dumps([str(repos[2])]))
        self.zoxide.write_text("90 %s\n" % repos[3])
        self.write_config([{"path": str(self.root), "max_project_depth": 1}], [], [str(repos[0])])
        cache = self.refresh()
        chosen = next(item for item in cache["records"] if item["path"] == str(repos[1]))
        chosen["selected_at"] = 12345.0
        pc.atomic_write(self.cache, cache)
        records = self.refresh()["records"]
        self.assertEqual([item["path"] for item in records], [str(repos[0]), str(repos[1]), str(repos[2]), str(repos[3]), str(repos[4])])
        self.assertEqual([item["ranking_reason"] for item in records], ["pin", "herdr", "neovim", "zoxide", "discovery"])

    def test_stale_cache_filters_missing_paths_and_config_mtime_invalidates(self):
        repo = self.git_repo("repo")
        self.write_config([{"path": str(repo), "max_project_depth": 0}], [], [])
        cache = self.refresh()
        self.assertFalse(pc.is_stale(cache))
        os.utime(self.config, (cache["generated_at"] + 2, cache["generated_at"] + 2))
        self.assertTrue(pc.is_stale(cache))
        subprocess.run(["rm", "-rf", str(repo)], check=True)
        records, status = pc.immediate_records()
        self.assertEqual(records, [])
        self.assertEqual(status, "stale")

    def test_malformed_or_missing_adapters_fail_independently(self):
        repo = self.git_repo("repo")
        self.nvim.write_text("not json")
        self.zoxide.unlink()
        self.write_config([{"path": str(repo), "max_project_depth": 0}], [], [])
        self.assertEqual([item["path"] for item in self.refresh()["records"]], [str(repo)])

    def test_timeout_and_single_flight_preserve_valid_cache(self):
        repo = self.git_repo("repo")
        self.write_config([{"path": str(repo), "max_project_depth": 0}], [], [])
        self.refresh()
        before = self.cache.read_bytes()
        with mock.patch.dict(os.environ, {"HERDR_PROJECT_REFRESH_TIMEOUT": "0.001"}), mock.patch.object(pc, "candidate_sources", side_effect=lambda *args: time.sleep(0.01) or {}):
            self.assertEqual(pc.refresh(), 1)
        self.assertEqual(self.cache.read_bytes(), before)
        lock = self.cache.with_suffix(self.cache.suffix + ".lock")
        with lock.open("a+") as handle:
            fcnt = __import__("fcntl")
            fcnt.flock(handle, fcnt.LOCK_EX | fcnt.LOCK_NB)
            self.assertEqual(pc.refresh(), 75)

    def test_record_selection_revalidates_and_updates_only_accepted_project(self):
        repo = self.git_repo("repo")
        other = self.git_repo("other")
        outside = self.root / "outside"
        outside.mkdir()
        self.write_config([{"path": str(self.root), "max_project_depth": 1}], [], [])
        self.refresh()
        self.assertEqual(pc.validate_selection(str(repo)), 0)
        self.assertEqual(pc.record_selection(str(outside)), 1)
        self.assertEqual(pc.record_selection(str(repo)), 0)
        record = pc.load_cache()["records"][0]
        self.assertEqual(record["path"], str(repo))
        self.assertEqual(record["ranking_reason"], "herdr")
        self.assertIsInstance(record["selected_at"], float)
        subprocess.run(["rm", "-rf", str(repo)], check=True)
        repo.mkdir()
        self.assertEqual(pc.validate_selection(str(repo)), 1)

    def test_structurally_malformed_cache_falls_back_to_seed(self):
        repo = self.git_repo("repo")
        self.write_config([{"path": str(repo), "max_project_depth": 0}], [], [])
        self.cache.write_text(json.dumps({"version": 1, "generated_at": time.time(), "records": [{"path": str(repo)}]}))
        records, status = pc.immediate_records()
        self.assertEqual([item["path"] for item in records], [str(repo)])
        self.assertEqual(status, "refreshing")

    def test_picker_output_marks_open_without_changing_order(self):
        repo = self.git_repo("repo")
        self.write_config([{"path": str(repo), "max_project_depth": 0}], [], [])
        records = self.refresh()["records"]
        opened = self.root / "opened"
        opened.write_text(str(repo) + "\n")
        output = __import__("io").StringIO()
        with contextlib.redirect_stdout(output):
            pc.emit(records, "picker", "current", opened)
        self.assertIn(" [open] [main", output.getvalue())
        self.assertEqual(records[0]["path"], str(repo))

    def test_twenty_run_latency_budgets_for_cached_and_seed_states(self):
        repo = self.git_repo("repo")
        self.write_config([{"path": str(repo), "max_project_depth": 0}], [], [])
        valid = self.refresh()
        environment = os.environ.copy()

        def measure(prepare):
            timings = []
            for _ in range(20):
                prepare()
                started = time.perf_counter()
                result = subprocess.run(["/usr/bin/python3", str(MODULE_PATH), "list", "--format", "paths"], env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                timings.append((time.perf_counter() - started) * 1000)
                self.assertEqual(result.returncode, 0, result.stderr)
            return timings

        def write_cache(value):
            self.cache.write_text(json.dumps(value))

        warm = measure(lambda: write_cache(valid))
        stale_value = dict(valid, generated_at=time.time() - pc.FRESH_SECONDS - 1)
        stale = measure(lambda: write_cache(stale_value))
        refresh_failure = measure(lambda: write_cache(stale_value))
        cold = measure(lambda: self.cache.unlink(missing_ok=True))
        corrupt = measure(lambda: self.cache.write_text("not json"))
        empty_config = {"version": 1, "roots": [], "explicit_projects": [], "pins": []}
        empty = measure(lambda: (self.config.write_text(json.dumps(empty_config)), self.cache.unlink(missing_ok=True)))
        p95 = lambda values: sorted(values)[18]
        for name, values in (("warm", warm), ("stale", stale), ("refresh-failure", refresh_failure)):
            self.assertLessEqual(p95(values), 250, (name, statistics.median(values), p95(values)))
        for name, values in (("cold", cold), ("corrupt", corrupt), ("empty", empty)):
            self.assertLessEqual(p95(values), 500, (name, statistics.median(values), p95(values)))
        print("catalog latency: " + "; ".join("%s median %.3f ms p95 %.3f ms" % (name, statistics.median(values), p95(values)) for name, values in (("warm", warm), ("stale", stale), ("refresh-failure", refresh_failure), ("cold", cold), ("corrupt", corrupt), ("empty", empty))))


if __name__ == "__main__":
    unittest.main()
