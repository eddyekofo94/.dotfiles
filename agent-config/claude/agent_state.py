#!/usr/bin/env python3
"""Stop and Notification hook: one status file per agent session (master plan 1a).

`~/.local/state/agents/<session>.json` (override: `AGENT_STATE_DIR`) holds what
the master, `board` and, later, the reaper and Rex's badges read about a
worker, so none of them has to parse a transcript or scrape a pane:

  session, event, state, updated   who, which hook, and when
  state                            `idle` after a Stop, `blocked` on a permission
                                   prompt or a question dialog
  status, next_move                the closeout's Status word and Next move
  repo, branch, record, cwd        where it works (`repo` is the main checkout)
  context_tokens, model            the last turn's context size and model
  herdr                            session, socket, tab and pane ids, when in herdr
  role                             `master` for the master seat (`AGENT_ROLE`)
  name                             the session's `--name` (`AGENT_NAME`), which the
                                   master's `notify_when_idle` notice names

Fast and silent: one git call, a bounded transcript tail, and any error exits 0
without writing, so a broken payload never holds a turn.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

STATUS = re.compile(r"\*\*Status:\*\*\s*([A-Z][A-Z ]*[A-Z])")
NEXT_MOVE = re.compile(r"\*\*Next move:\*\*\s*(.+)")
RECORD = re.compile(r"\b((?:bs-)?[a-z]+-(?:feat|bug|task)-\d+)\b", re.I)
BLOCKING = {"permission_prompt", "elicitation_dialog"}  # idle_prompt is a wait, not a block
TAIL = 1 << 20


def state_dir() -> Path:
    return Path(os.environ.get("AGENT_STATE_DIR", Path.home() / ".local/state/agents"))


def git_place(cwd: str) -> tuple[str, str]:
    """(main checkout, branch) in one git call; empty strings outside a repo."""
    try:
        out = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--path-format=absolute", "--git-common-dir",
             "--abbrev-ref", "HEAD"],
            capture_output=True, text=True, timeout=2).stdout.split("\n")
    except (OSError, subprocess.SubprocessError):
        return "", ""
    if len(out) < 2 or not out[0]:
        return "", ""
    common = Path(out[0])
    repo = str(common.parent) if common.name == ".git" else str(common)
    return repo, out[1].strip()


def last_usage(transcript: str) -> tuple[int, str]:
    """(context tokens, model) of the newest main-thread assistant message."""
    try:
        with open(transcript, "rb") as handle:
            handle.seek(0, os.SEEK_END)
            handle.seek(max(handle.tell() - TAIL, 0))
            lines = handle.read().decode("utf-8", "replace").splitlines()
    except OSError:
        return 0, ""
    for line in reversed(lines):
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get("type") != "assistant" or event.get("isSidechain"):
            continue
        message = event.get("message") or {}
        usage = message.get("usage") or {}
        tokens = sum(int(usage.get(k) or 0) for k in
                     ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"))
        if tokens:
            return tokens, str(message.get("model") or "")
    return 0, ""


def build(payload: dict, previous: dict) -> dict:
    event = payload.get("hook_event_name") or ""
    cwd = payload.get("cwd") or os.getcwd()
    repo, branch = git_place(cwd)
    found = RECORD.search(branch) or RECORD.search(Path(cwd).name)
    record = found.group(1).upper() if found else previous.get("record", "")
    entry = dict(previous)
    entry.update({
        "session": payload.get("session_id", ""),
        "event": event,
        "updated": round(time.time(), 3),
        "cwd": cwd,
        "repo": repo,
        "branch": branch,
        "record": record,
        "role": os.environ.get("AGENT_ROLE", previous.get("role", "")),
        "name": os.environ.get("AGENT_NAME", previous.get("name", "")),
        "transcript": payload.get("transcript_path", ""),
    })
    herdr = {k: os.environ[v] for k, v in (("session", "HERDR_SESSION"), ("socket", "HERDR_SOCKET_PATH"),
                                            ("tab", "HERDR_TAB_ID"), ("pane", "HERDR_PANE_ID"))
             if os.environ.get(v)}
    if herdr:
        entry["herdr"] = herdr
    if event == "Stop":
        message = payload.get("last_assistant_message") or ""
        status = STATUS.findall(message)
        entry["state"] = "idle"
        entry["status"] = status[-1] if status else ""
        moves = NEXT_MOVE.findall(message)
        entry["next_move"] = moves[-1].strip() if moves else ""
        entry.pop("notice", None)
    elif event == "Notification":
        kind = payload.get("notification_type") or ""
        if kind not in BLOCKING:
            return {}
        entry["state"] = "blocked"
        entry["notice"] = {"type": kind, "message": payload.get("message", "")}
    else:
        return {}
    tokens, model = last_usage(entry["transcript"]) if entry["transcript"] else (0, "")
    if tokens:
        entry["context_tokens"], entry["model"] = tokens, model
    return entry


def main() -> int:
    try:
        payload = json.load(sys.stdin)
        session = payload.get("session_id") or ""
        if not re.fullmatch(r"[A-Za-z0-9-]+", session):
            return 0
        directory = state_dir()
        target = directory / f"{session}.json"
        try:
            previous = json.loads(target.read_text())
        except (OSError, ValueError):
            previous = {}
        entry = build(payload, previous)
        if not entry:
            return 0
        directory.mkdir(parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=directory, prefix=".", suffix=".tmp")
        with os.fdopen(fd, "w") as handle:
            json.dump(entry, handle, indent=1)
        os.replace(tmp, target)
    except Exception:  # noqa: BLE001 — a status file must never hold a turn
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
