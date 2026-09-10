#!/usr/bin/env python3
"""Repository-local, compatible named worktree lifecycle.

This manager deliberately owns no project IDs, capacity, agent, or delivery
policy. Repositories opt in by providing this interface themselves.
"""
from __future__ import annotations

import argparse
import fcntl
import json
import re
import subprocess
import sys
from contextlib import contextmanager
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SLUG = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\Z")


def git(*args: str, cwd: Path = ROOT) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *args], cwd=cwd, text=True, capture_output=True)


def die(message: str) -> None:
    raise SystemExit(f"session-worktree: {message}")


def common_dir() -> Path:
    result = git("rev-parse", "--path-format=absolute", "--git-common-dir")
    if result.returncode:
        die("not a git checkout")
    return Path(result.stdout.strip())


def state_path() -> Path:
    return common_dir() / "named-worktree-claims.json"


@contextmanager
def claims_lock():
    path = common_dir() / "named-worktree-claims.lock"
    with path.open("a+") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        yield


def load_claims() -> dict[str, list[str]]:
    path = state_path()
    if not path.exists():
        return {}
    try:
        value = json.loads(path.read_text())
    except (OSError, ValueError):
        die(f"invalid claim state: {path}")
    if not isinstance(value, dict) or not all(isinstance(v, list) for v in value.values()):
        die(f"invalid claim state: {path}")
    return {str(k): sorted(map(str, v)) for k, v in value.items()}


def save_claims(claims: dict[str, list[str]]) -> None:
    path = state_path()
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(claims, indent=2, sort_keys=True) + "\n")
    tmp.replace(path)


def validate(slug: str, paths: list[str]) -> list[str]:
    if not SLUG.fullmatch(slug):
        die("goal must be lower-case kebab-case")
    if not paths:
        die("at least one tracked --path is required")
    out = []
    for path in paths:
        candidate = Path(path)
        if candidate.is_absolute() or ".." in candidate.parts or not path:
            die(f"path escapes repository root: {path}")
        normalized = candidate.as_posix()
        if normalized == ".":
            normalized = "."
        if git("ls-files", "--error-unmatch", "--", normalized).returncode:
            die(f"path is not tracked: {path}")
        out.append(normalized)
    return sorted(set(out))


def paths_overlap(left: str, right: str) -> bool:
    if left == "." or right == ".":
        return True
    left_path = Path(left)
    right_path = Path(right)
    return left_path == right_path or left_path in right_path.parents or right_path in left_path.parents


def overlapping(paths: list[str], owned: list[str]) -> list[str]:
    return sorted({path for path in paths for existing in owned if paths_overlap(path, existing)})


def worktree(slug: str) -> Path:
    return ROOT.parent / f"{ROOT.name}-sessions" / slug


def open_goal(slug: str, paths: list[str]) -> None:
    paths = validate(slug, paths)
    with claims_lock():
        if git("status", "--porcelain").stdout.strip():
            die("shared checkout is dirty")
        claims = load_claims()
        existing = claims.get(slug)
        if existing is not None and existing != paths:
            die(f"{slug} already owns a different path set")
        for owner, owned in claims.items():
            overlap = overlapping(paths, owned)
            if owner != slug and overlap:
                die(f"paths owned by {owner}: {', '.join(overlap)}; use transfer")
        target = worktree(slug)
        branch = f"feature/{slug}"
        if target.exists():
            current = git("-C", str(target), "branch", "--show-current")
            registered = git("worktree", "list", "--porcelain")
            worktree_paths = {
                Path(line.removeprefix("worktree ")).resolve()
                for line in registered.stdout.splitlines()
                if line.startswith("worktree ")
            }
            if (current.returncode or current.stdout.strip() != branch
                    or target.resolve() not in worktree_paths):
                die(f"worktree mismatch: {target}")
        else:
            if git("show-ref", "--verify", "--quiet", f"refs/heads/{branch}").returncode == 0:
                die(f"branch exists without expected worktree: {branch}")
            target.parent.mkdir(parents=True, exist_ok=True)
            result = git("worktree", "add", "-b", branch, str(target), "main")
            if result.returncode:
                die(result.stderr.strip() or "git worktree add failed")
        claims[slug] = paths
        save_claims(claims)
    print(target)


def transfer(source: str, target: str, paths: list[str]) -> None:
    paths = validate(target, paths)
    with claims_lock():
        claims = load_claims()
        if source not in claims or target not in claims:
            die("both source and target goals must be open")
        if not set(paths) <= set(claims[source]):
            die("source does not own every transferred path")
        if overlapping(paths, claims[target]):
            die("target already owns an overlapping transferred path")
        claims[source] = sorted(set(claims[source]) - set(paths))
        claims[target] = sorted(set(claims[target]) | set(paths))
        save_claims(claims)


def close_goal(slug: str) -> None:
    if not SLUG.fullmatch(slug):
        die("goal must be lower-case kebab-case")
    with claims_lock():
        target = worktree(slug)
        if not target.exists():
            die(f"no worktree for {slug}")
        if git("status", "--porcelain", cwd=target).stdout.strip():
            die("worktree is dirty")
        branch = git("branch", "--show-current", cwd=target).stdout.strip()
        if branch != f"feature/{slug}" or git("merge-base", "--is-ancestor", branch, "main").returncode:
            die("worktree branch is not contained in main")
        result = git("worktree", "remove", str(target))
        if result.returncode:
            die(result.stderr.strip() or "git worktree remove failed")
        claims = load_claims()
        claims.pop(slug, None)
        save_claims(claims)


def shared_status() -> None:
    branch = git("branch", "--show-current").stdout.strip()
    dirty = bool(git("status", "--porcelain").stdout.strip())
    print(json.dumps({"branch": branch, "dirty": dirty}, sort_keys=True))


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    for command in ("open", "create"):
        opening = sub.add_parser(command)
        opening.add_argument("goal")
        opening.add_argument("--goal")
        opening.add_argument("--path", action="append", default=[])
    moving = sub.add_parser("transfer")
    moving.add_argument("source")
    moving.add_argument("target")
    moving.add_argument("--path", action="append", required=True)
    for command in ("close", "remove"):
        closing = sub.add_parser(command)
        closing.add_argument("goal")
    sub.add_parser("shared-status")
    sub.add_parser("status")
    args = parser.parse_args()
    if args.command in {"open", "create"}: open_goal(args.goal, args.path)
    elif args.command == "transfer": transfer(args.source, args.target, args.path)
    elif args.command in {"close", "remove"}: close_goal(args.goal)
    elif args.command == "shared-status": shared_status()
    else: print(json.dumps(load_claims(), indent=2, sort_keys=True))

if __name__ == "__main__":
    main()
