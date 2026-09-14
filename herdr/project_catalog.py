#!/usr/bin/env python3
"""Validated, cache-first project catalog for Herdr (Python 3.9 stdlib only)."""
from __future__ import annotations

import argparse
import concurrent.futures
import fcntl
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Tuple

VERSION = 1
FRESH_SECONDS = 600
REFRESH_SECONDS = 5.0
PRUNED = {".build", ".cache", ".runtime", ".tox", ".venv", "build", "node_modules", "target", "vendor", "venv"}


def config_path() -> Path:
    return Path(os.environ.get("HERDR_PROJECT_CATALOG_CONFIG", Path(__file__).with_name("project_catalog.json")))


def cache_path() -> Path:
    configured = os.environ.get("HERDR_PROJECT_CATALOG_CACHE")
    if configured:
        return Path(configured)
    return Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "herdr/project-catalog-v1.json"


def expand_config_path(value: str) -> Path:
    if value == "~":
        return Path.home()
    if value.startswith("~/"):
        return Path.home() / value[2:]
    if "~" in value:
        raise ValueError("~ is accepted only at the start of a configured path")
    return Path(value)


def canonical(path: Path) -> Optional[Path]:
    try:
        resolved = path.resolve(strict=True)
    except (OSError, RuntimeError):
        return None
    return resolved if resolved.is_dir() else None


def display_path(path: Path) -> str:
    home = str(Path.home())
    value = str(path)
    if value == home:
        return "~"
    if value.startswith(home + os.sep):
        return "~/" + value[len(home) + 1 :]
    return value


def read_json(path: Path) -> Any:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def load_config(path: Optional[Path] = None) -> Dict[str, Any]:
    path = path or config_path()
    value = read_json(path)
    if not isinstance(value, dict) or value.get("version") != VERSION:
        raise ValueError("catalog config must be a version 1 object")
    roots = value.get("roots")
    explicit = value.get("explicit_projects")
    pins = value.get("pins")
    if not isinstance(roots, list) or not isinstance(explicit, list) or not isinstance(pins, list):
        raise ValueError("roots, explicit_projects, and pins must be arrays")
    for item in roots:
        if not isinstance(item, dict) or not isinstance(item.get("path"), str):
            raise ValueError("every root needs a string path")
        depth = item.get("max_project_depth")
        if not isinstance(depth, int) or isinstance(depth, bool) or depth < 0:
            raise ValueError("max_project_depth must be a non-negative integer")
        expand_config_path(item["path"])
    for item in explicit:
        if isinstance(item, str):
            expand_config_path(item)
        elif isinstance(item, dict) and isinstance(item.get("path"), str) and ("label" not in item or isinstance(item["label"], str)):
            expand_config_path(item["path"])
        else:
            raise ValueError("explicit projects must be paths or path/label objects")
    if not all(isinstance(item, str) for item in pins):
        raise ValueError("pins must contain paths")
    for item in pins:
        expand_config_path(item)
    return value


def run(command: Sequence[str], timeout: float) -> Optional[str]:
    try:
        result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=max(0.01, timeout), check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return result.stdout if result.returncode == 0 else None


def candidate_sources(config: Dict[str, Any], fast: bool, deadline: float) -> Dict[Path, Dict[str, Any]]:
    found: Dict[Path, Dict[str, Any]] = {}

    def add(path: Path, source: str, rank: int, label: Optional[str] = None, explicit: bool = False) -> None:
        resolved = canonical(path)
        if resolved is None or any(ord(character) < 32 or ord(character) == 127 for character in str(resolved)):
            return
        if label is not None and any(ord(character) < 32 or ord(character) == 127 for character in label):
            return
        item = found.setdefault(resolved, {"aliases": set(), "source_ranks": {}, "explicit": False, "label": None})
        item["aliases"].add(str(path))
        item["source_ranks"][source] = min(rank, item["source_ranks"].get(source, rank))
        item["explicit"] = item["explicit"] or explicit
        item["label"] = item["label"] or label

    for rank, item in enumerate(config["explicit_projects"]):
        value = item if isinstance(item, str) else item["path"]
        label = None if isinstance(item, str) else item.get("label")
        add(expand_config_path(value), "configured", rank, label, True)

    for rank, item in enumerate(config["roots"]):
        root = expand_config_path(item["path"])
        add(root, "configured-root", rank)
        if fast or time.monotonic() >= deadline:
            continue
        scan_root(root, item["max_project_depth"], lambda path: add(path, "configured-root", rank), deadline)

    for rank, path in enumerate(neovim_candidates(deadline)):
        add(path, "neovim", rank)
    for rank, path in enumerate(zoxide_candidates(deadline, 100 if fast else None)):
        add(path, "zoxide", rank)
    return found


def scan_root(root: Path, max_depth: int, accept: Any, deadline: float) -> None:
    resolved = canonical(root)
    if resolved is None or max_depth == 0:
        return
    root_parts = len(resolved.parts)
    for current, directories, files in os.walk(str(resolved), followlinks=False):
        if time.monotonic() >= deadline:
            return
        path = Path(current)
        depth = len(path.parts) - root_parts
        directories[:] = [name for name in directories if name not in PRUNED and not name.startswith("cmake-build-") and not (path / name).is_symlink()]
        if ".git" in directories or ".git" in files:
            accept(path)
            directories[:] = []
        elif depth >= max_depth:
            directories[:] = []


def neovim_candidates(deadline: float) -> List[Path]:
    override = os.environ.get("HERDR_PROJECT_NEOVIM_HISTORY")
    paths = [Path(override)] if override else [
        Path.home() / ".local/share/nvim/project_nvim/project_history.json",
        Path.home() / ".local/share/nvim/project_nvim/project_history",
        Path.home() / ".local/state/nvim/project_nvim/project_history.json",
    ]
    for path in paths:
        if time.monotonic() >= deadline or not path.is_file():
            continue
        try:
            value = read_json(path)
        except (OSError, ValueError, TypeError):
            continue
        if isinstance(value, dict):
            value = value.get("projects", value.get("history", []))
        if isinstance(value, list):
            result = []
            for item in value:
                candidate = item if isinstance(item, str) else item.get("path") if isinstance(item, dict) else None
                if isinstance(candidate, str):
                    result.append(Path(candidate))
            return result
    return []


def zoxide_candidates(deadline: float, seed_limit: Optional[int] = None) -> List[Path]:
    fixture = os.environ.get("HERDR_PROJECT_ZOXIDE_LIST")
    if fixture is not None:
        try:
            text = Path(fixture).read_text(encoding="utf-8")
        except OSError:
            return []
    else:
        remaining = min(0.5, deadline - time.monotonic())
        if remaining <= 0:
            return []
        text = run([os.environ.get("HERDR_PROJECT_ZOXIDE", "zoxide"), "query", "-ls"], remaining)
        if text is None:
            return []
    result = []
    limit = seed_limit
    override_limit = os.environ.get("HERDR_PROJECT_ZOXIDE_LIMIT")
    if override_limit is not None:
        limit = int(override_limit)
    if limit is not None and limit <= 0:
        return []
    for line in text.splitlines():
        fields = line.strip().split(maxsplit=1)
        if len(fields) == 2:
            result.append(Path(fields[1]))
            if limit is not None and len(result) >= limit:
                break
    return result


def git_identity(path: Path, deadline: float) -> Optional[Tuple[str, Path, List[Path]]]:
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        return None
    try:
        top_result = subprocess.run(
            ["git", "-C", str(path), "rev-parse", "--show-toplevel"],
            text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            timeout=min(0.75, remaining), check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if top_result.returncode != 0:
        return None if (path / ".git").exists() else ("non-git", path, [])
    top = canonical(Path(top_result.stdout.strip()))
    if top is None or top != path:
        return None
    listing = run(
        ["git", "-C", str(top), "worktree", "list", "--porcelain"],
        min(0.75, max(0.01, deadline - time.monotonic())),
    )
    if listing is None:
        return None
    worktrees = []
    for block in listing.strip().split("\n\n"):
        lines = block.splitlines()
        if any(line == "prunable" or line.startswith("prunable ") for line in lines):
            continue
        worktree_line = next((line for line in lines if line.startswith("worktree ")), None)
        if worktree_line is not None:
            candidate = canonical(Path(worktree_line[9:]))
            if candidate is not None:
                worktrees.append(candidate)
    if not worktrees:
        return None
    main = worktrees[0]
    return ("main" if top == main else "worktree", main, worktrees)


def make_records(config: Dict[str, Any], fast: bool, previous: Dict[str, Dict[str, Any]], deadline: float) -> List[Dict[str, Any]]:
    candidates = candidate_sources(config, fast, deadline)
    queue = list(candidates)
    identities: Dict[Path, Optional[Tuple[str, Path, List[Path]]]] = {}
    worker_count = min(24, max(1, len(queue)))
    with concurrent.futures.ThreadPoolExecutor(max_workers=worker_count) as executor:
        results = executor.map(lambda candidate: git_identity(candidate, deadline), queue)
        identities.update(zip(queue, results))
    records: Dict[str, Dict[str, Any]] = {}
    index = 0
    while index < len(queue) and time.monotonic() < deadline:
        path = queue[index]
        info = candidates[path]
        index += 1
        identity = identities.get(path)
        if identity is None:
            continue
        kind, main, worktrees = identity
        if kind == "non-git":
            if not info["explicit"]:
                continue
            kind, main = "explicit-non-git", None
        else:
            for worktree in worktrees:
                if worktree not in candidates:
                    candidates[worktree] = {"aliases": {str(worktree)}, "source_ranks": {"git-worktree": 0}, "explicit": False, "label": None}
                    queue.append(worktree)
                identities.setdefault(worktree, ("main" if worktree == main else "worktree", main, worktrees))
        key = str(path)
        old = previous.get(key, {})
        records[key] = {
            "path": key,
            "display_path": display_path(path),
            "label": info["label"] or path.name or key,
            "kind": kind,
            "main_worktree": str(main) if main else None,
            "aliases": sorted(info["aliases"] | {key}),
            "sources": sorted(info["source_ranks"]),
            "source_ranks": info["source_ranks"],
            "selected_at": old.get("selected_at"),
            "validated_at": time.time(),
        }

    return rank_records(list(records.values()), config)


def rank_records(records: List[Dict[str, Any]], config: Dict[str, Any]) -> List[Dict[str, Any]]:
    accepted = {record["path"] for record in records}
    pins = []
    for value in config["pins"]:
        resolved = canonical(expand_config_path(value))
        key = str(resolved) if resolved else ""
        if key not in accepted:
            raise ValueError("pin is missing or not an accepted project: " + value)
        pins.append(key)
    for record in records:
        path = record["path"]
        ranks = record["source_ranks"]
        if path in pins:
            record["ranking_reason"] = "pin"
            record["_sort"] = (0, pins.index(path))
        elif record["selected_at"] is not None:
            record["ranking_reason"] = "herdr"
            record["_sort"] = (1, -float(record["selected_at"]), record["label"].casefold(), path.casefold())
        elif "neovim" in ranks:
            record["ranking_reason"] = "neovim"
            record["_sort"] = (2, ranks["neovim"], record["label"].casefold(), path.casefold())
        elif "zoxide" in ranks:
            record["ranking_reason"] = "zoxide"
            record["_sort"] = (3, ranks["zoxide"], record["label"].casefold(), path.casefold())
        else:
            record["ranking_reason"] = "discovery"
            record["_sort"] = (4, record["label"].casefold(), path.casefold())
    return sorted(records, key=lambda item: item.pop("_sort"))


def valid_cache(value: Any) -> bool:
    if not isinstance(value, dict) or value.get("version") != VERSION or not isinstance(value.get("generated_at"), (int, float)) or not isinstance(value.get("records"), list):
        return False
    paths = []
    for item in value["records"]:
        if not isinstance(item, dict):
            return False
        required_strings = ("path", "display_path", "label", "kind", "ranking_reason")
        if not all(isinstance(item.get(field), str) for field in required_strings):
            return False
        if item["kind"] not in ("main", "worktree", "explicit-non-git"):
            return False
        if not isinstance(item.get("aliases"), list) or not all(isinstance(alias, str) for alias in item["aliases"]):
            return False
        if not isinstance(item.get("sources"), list) or not all(isinstance(source, str) for source in item["sources"]):
            return False
        if not isinstance(item.get("source_ranks"), dict) or not all(isinstance(key, str) and isinstance(rank, int) for key, rank in item["source_ranks"].items()):
            return False
        if item.get("selected_at") is not None and not isinstance(item["selected_at"], (int, float)):
            return False
        if not isinstance(item.get("validated_at"), (int, float)):
            return False
        if item.get("main_worktree") is not None and not isinstance(item["main_worktree"], str):
            return False
        paths.append(item["path"])
    return len(paths) == len(set(paths))


def load_cache(path: Optional[Path] = None) -> Optional[Dict[str, Any]]:
    try:
        value = read_json(path or cache_path())
    except (OSError, ValueError, TypeError):
        return None
    return value if valid_cache(value) else None


def is_stale(cache: Optional[Dict[str, Any]], config: Optional[Path] = None, now: Optional[float] = None) -> bool:
    if cache is None:
        return True
    now = time.time() if now is None else now
    generated = cache.get("generated_at")
    if not isinstance(generated, (int, float)) or now - generated > FRESH_SECONDS:
        return True
    try:
        return (config or config_path()).stat().st_mtime > generated
    except OSError:
        return True


def atomic_write(path: Path, value: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=path.name + ".", dir=str(path.parent))
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(value, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def refresh() -> int:
    path = cache_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    lock = path.with_suffix(path.suffix + ".lock")
    with lock.open("a+") as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return 75
        deadline = time.monotonic() + float(os.environ.get("HERDR_PROJECT_REFRESH_TIMEOUT", REFRESH_SECONDS))
        old = load_cache(path)
        previous = {item["path"]: item for item in old["records"]} if old else {}
        try:
            config = load_config()
            records = make_records(config, False, previous, deadline)
            if time.monotonic() >= deadline:
                raise TimeoutError("catalog refresh exceeded its deadline")
            value = {"version": VERSION, "generated_at": time.time(), "records": records}
            if not valid_cache(value):
                raise ValueError("generated cache is invalid")
            atomic_write(path, value)
        except (OSError, ValueError, TimeoutError) as error:
            print("project catalog refresh failed: " + str(error), file=sys.stderr)
            return 1
    return 0


def refresh_status() -> str:
    path = cache_path()
    lock = path.with_suffix(path.suffix + ".lock")
    lock.parent.mkdir(parents=True, exist_ok=True)
    with lock.open("a+") as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return "refreshing"
    cache = load_cache(path)
    return "missing" if cache is None else "stale" if is_stale(cache) else "current"


def immediate_records() -> Tuple[List[Dict[str, Any]], str]:
    cache = load_cache()
    if cache is not None:
        records = [item for item in cache["records"] if canonical(Path(item["path"])) is not None]
        return records, "stale" if is_stale(cache) else "current"
    config = load_config()
    deadline = time.monotonic() + float(os.environ.get("HERDR_PROJECT_SEED_TIMEOUT", "0.45"))
    return make_records(config, True, {}, deadline), "refreshing"


def validate_selection(path_value: str) -> int:
    selected = canonical(Path(path_value))
    cache = load_cache()
    if selected is None or cache is None:
        return 1
    matches = [item for item in cache["records"] if item["path"] == str(selected)]
    if len(matches) != 1:
        return 1
    record = matches[0]
    if record["kind"] == "explicit-non-git":
        return 0
    identity = git_identity(selected, time.monotonic() + 1.5)
    if identity is None or identity[0] != record["kind"]:
        return 1
    return 0 if str(identity[1]) == record.get("main_worktree") else 1


def record_selection(path_value: str) -> int:
    selected = canonical(Path(path_value))
    path = cache_path()
    if selected is None:
        return 1
    path.parent.mkdir(parents=True, exist_ok=True)
    lock = path.with_suffix(path.suffix + ".lock")
    with lock.open("a+") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        cache = load_cache(path)
        if cache is None:
            return 1
        matches = [item for item in cache["records"] if item["path"] == str(selected)]
        if len(matches) != 1:
            return 1
        record = matches[0]
        if record.get("kind") != "explicit-non-git":
            identity = git_identity(selected, time.monotonic() + 1.5)
            if identity is None or identity[0] != record.get("kind") or str(identity[1]) != record.get("main_worktree"):
                return 1
        matches[0]["selected_at"] = time.time()
        try:
            cache["records"] = rank_records(cache["records"], load_config())
        except (OSError, ValueError):
            return 1
        atomic_write(path, cache)
    return 0


def emit(records: List[Dict[str, Any]], output: str, status: str, open_paths: Optional[Path] = None) -> None:
    if output == "json":
        json.dump({"status": status, "records": records}, sys.stdout, separators=(",", ":"))
        print()
    elif output == "paths":
        for item in records:
            print(item["path"])
    else:
        opened = set()
        if open_paths is not None:
            try:
                opened = set(open_paths.read_text(encoding="utf-8").splitlines())
            except OSError:
                pass
        for item in records:
            searchable = " ".join(item.get("aliases", []))
            annotation = "%s %s" % (item.get("kind", "project"), ",".join(item.get("sources", [])))
            open_annotation = " [open]" if item["path"] in opened else ""
            print("%s\t%s%s [%s]\t%s\t%s" % (item["label"], item["display_path"], open_annotation, annotation, item["path"], searchable))


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="operation", required=True)
    listing = subparsers.add_parser("list")
    listing.add_argument("--format", choices=("picker", "paths", "json"), default="picker")
    listing.add_argument("--open-paths", type=Path)
    subparsers.add_parser("refresh")
    subparsers.add_parser("status")
    validating = subparsers.add_parser("validate")
    validating.add_argument("path")
    selected = subparsers.add_parser("record-selection")
    selected.add_argument("path")
    args = parser.parse_args()
    try:
        if args.operation == "refresh":
            return refresh()
        if args.operation == "record-selection":
            return record_selection(args.path)
        if args.operation == "validate":
            return validate_selection(args.path)
        if args.operation == "status":
            print(refresh_status())
            return 0
        records, status = immediate_records()
        emit(records, args.format, status, args.open_paths)
        return 0
    except (OSError, ValueError) as error:
        print("project catalog: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
