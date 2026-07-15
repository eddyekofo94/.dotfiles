#!/usr/bin/env python3
"""Shared tmux status engine for interactive coding agents."""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time
from typing import Any


SUPPORTED_AGENTS = {"codex", "claude", "opencode", "agy", "gemini"}
AGENT_ALIASES = {"antigravity": "agy"}
STATE_META = {
    "ready": ("", "#a6e3a1"),
    "running": (None, "#89b4fa"),
    "question": ("", "#fab387"),
    "permission": ("", "#f38ba8"),
    "finished": ("", "#a6e3a1"),
    "failed": ("", "#f38ba8"),
}
SPINNER = ("⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷")
OPTION_PREFIX = "@agent_status_"
RENDERED_OPTION = f"{OPTION_PREFIX}rendered"
ANIMATOR_PID_OPTION = f"{OPTION_PREFIX}animator_pid"
ANIMATION_INTERVAL = 1 / 12


def normalize_agent(value: str) -> str:
    name = Path(value).name.lower().removesuffix(".exe")
    name = AGENT_ALIASES.get(name, name)
    return name if name in SUPPORTED_AGENTS else ""


def agent_from_process(command: str, start_command: str = "") -> str:
    agent = normalize_agent(command)
    if agent:
        return agent

    try:
        tokens = shlex.split(start_command)
    except ValueError:
        tokens = start_command.split()
    nested_tokens: list[str] = []
    for token in tokens:
        if any(character.isspace() for character in token):
            try:
                nested_tokens.extend(shlex.split(token))
            except ValueError:
                nested_tokens.extend(token.split())
        else:
            nested_tokens.append(token)
    for token in nested_tokens:
        agent = normalize_agent(token)
        if agent:
            return agent
    return ""


def sanitize_label(value: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "-", value.strip())
    return cleaned.strip("-") or "project"


def truncate_project(value: str, maximum: int = 16) -> str:
    if len(value) <= maximum:
        return value
    return f"{value[:8]}…{value[-7:]}"


def classify_message(message: str) -> str:
    plain_message = re.sub(r"[*_`]", "", message)
    if re.search(r"\bStatus\s*:\s*AWAITING USER APPROVAL\b", plain_message, re.I):
        return "permission"

    without_fences = re.sub(r"```.*?```", "", message, flags=re.S)
    for line in without_fences.splitlines():
        candidate = re.sub(r"^[\s>*#-]+", "", line).strip()
        if candidate.endswith("?"):
            return "question"
    return "finished"


def extract_message(payload: dict[str, Any]) -> str:
    for key in (
        "last_assistant_message",
        "prompt_response",
        "response",
        "assistant_message",
        "message",
    ):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value

    transcript = payload.get("transcript_path") or payload.get("transcriptPath")
    if isinstance(transcript, str):
        return extract_message_from_transcript(Path(os.path.expanduser(transcript)))
    return ""


def extract_message_from_transcript(path: Path) -> str:
    try:
        with path.open("rb") as handle:
            handle.seek(0, os.SEEK_END)
            size = handle.tell()
            handle.seek(max(0, size - 524_288))
            raw = handle.read().decode("utf-8", errors="replace")
    except OSError:
        return ""

    candidates: list[str] = []
    for line in raw.splitlines():
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            continue
        collect_assistant_text(item, candidates)
    return candidates[-1] if candidates else ""


def collect_assistant_text(value: Any, candidates: list[str]) -> None:
    if isinstance(value, dict):
        role = str(value.get("role", "")).lower()
        if role in {"assistant", "model"}:
            for key in ("text", "content", "message"):
                text = value.get(key)
                if isinstance(text, str) and text.strip():
                    candidates.append(text)
        for child in value.values():
            collect_assistant_text(child, candidates)
    elif isinstance(value, list):
        for child in value:
            collect_assistant_text(child, candidates)


def payload_failed(payload: dict[str, Any]) -> bool:
    reason = " ".join(
        str(payload.get(key, ""))
        for key in ("terminationReason", "termination_reason", "reason", "error")
    ).lower()
    return any(
        token in reason
        for token in ("error", "failed", "crash", "auth", "rate_limit", "rate limit", "max_steps")
    )


def state_for_event(event: str, payload: dict[str, Any]) -> str:
    if event in {"start", "session-start"}:
        return "ready"
    if event in {"prompt", "before-agent", "pre-invocation", "running"}:
        return "running"
    if event == "question":
        return "question"
    if event == "permission":
        return "permission"
    if event in {"failure", "error"} or payload_failed(payload):
        return "failed"
    if event in {"stop", "after-agent", "complete"}:
        return classify_message(extract_message(payload))
    if event == "session-end":
        return "ready" if str(payload.get("reason", "")).lower() == "clear" else "finished"
    raise ValueError(f"unknown event: {event}")


def project_from_payload(payload: dict[str, Any]) -> str:
    cwd = payload.get("cwd")
    if not isinstance(cwd, str):
        workspaces = payload.get("workspacePaths")
        if isinstance(workspaces, list) and workspaces and isinstance(workspaces[0], str):
            cwd = workspaces[0]
    if not isinstance(cwd, str) or not cwd:
        cwd = os.getcwd()
    return sanitize_label(Path(cwd).resolve().name)


def tmux_command(*args: str, capture: bool = False) -> str:
    command = [os.environ.get("TMUX_BIN", "tmux"), *args]
    result = subprocess.run(
        command,
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.stdout.rstrip("\n") if capture else ""


def set_pane_status(agent: str, state: str, payload: dict[str, Any]) -> None:
    pane = os.environ.get("TMUX_PANE")
    if not os.environ.get("TMUX") or not pane:
        return

    current_agent = get_pane_option(pane, "agent")
    project = get_pane_option(pane, "project")
    if current_agent != agent or not project:
        project = project_from_payload(payload)

    for key, value in (("agent", agent), ("project", project), ("state", state)):
        tmux_command("set-option", "-p", "-t", pane, f"{OPTION_PREFIX}{key}", value)


def get_pane_option(pane: str, name: str) -> str:
    try:
        return tmux_command(
            "show-options",
            "-p",
            "-v",
            "-t",
            pane,
            f"{OPTION_PREFIX}{name}",
            capture=True,
        )
    except subprocess.CalledProcessError:
        return ""


def state_icon(state: str, frame: int) -> tuple[str, str]:
    icon, color = STATE_META[state]
    return (SPINNER[frame % len(SPINNER)] if icon is None else icon, color)


def render_entries_with_activity(
    panes: list[dict[str, str]], frame: int, fallback: str
) -> tuple[str, bool]:
    rendered: list[str] = []
    running = False
    for pane in panes:
        command_agent = agent_from_process(
            pane.get("command", ""), pane.get("start_command", "")
        )
        stored_agent = normalize_agent(pane.get("agent", ""))
        state = pane.get("state", "")

        if command_agent:
            if command_agent == stored_agent and state in STATE_META:
                agent = stored_agent
                project = pane.get("project", "")
                running = running or state == "running"
            else:
                agent = command_agent
                project = Path(pane.get("path", "project")).name
                state = "ready"
        elif stored_agent and state in {"failed", "running"}:
            agent = stored_agent
            project = pane.get("project", "")
            state = "failed"
        else:
            continue

        project = truncate_project(sanitize_label(project))
        icon, color = state_icon(state, frame)
        rendered.append(
            f"#[fg=#cdd6f4]{agent}:{project} "
            f"#[fg={color}]#[bold]{icon}#[nobold]"
        )

    return ("#[fg=#6c7086] · ".join(rendered) if rendered else fallback, running)


def render_entries(panes: list[dict[str, str]], frame: int, fallback: str) -> str:
    rendered, _ = render_entries_with_activity(panes, frame, fallback)
    return rendered


def render_window(window: str, fallback: str) -> str:
    panes = panes_for_window(window)
    return render_entries(panes, int(time.time()), sanitize_label(fallback))


def panes_for_window(window: str) -> list[dict[str, str]]:
    fields = "|".join(
        (
            "#{pane_current_command}",
            "#{pane_start_command}",
            "#{pane_current_path}",
            f"#{{{OPTION_PREFIX}agent}}",
            f"#{{{OPTION_PREFIX}project}}",
            f"#{{{OPTION_PREFIX}state}}",
        )
    )
    output = tmux_command("list-panes", "-t", window, "-F", fields, capture=True)
    panes = []
    for line in output.splitlines():
        command, start_command, path, agent, project, state = (
            line.split("|", 5) + ["", "", "", "", "", ""]
        )[:6]
        panes.append(
            {
                "command": command,
                "start_command": start_command,
                "path": path,
                "agent": agent,
                "project": project,
                "state": state,
            }
        )
    return panes


def window_snapshots() -> dict[str, dict[str, Any]]:
    separator = "\x1f"
    fields = separator.join(
        (
            "#{window_id}",
            "#{window_name}",
            "#{pane_id}",
            "#{pane_current_command}",
            "#{pane_start_command}",
            "#{pane_current_path}",
            f"#{{{OPTION_PREFIX}agent}}",
            f"#{{{OPTION_PREFIX}project}}",
            f"#{{{OPTION_PREFIX}state}}",
            f"#{{{RENDERED_OPTION}}}",
        )
    )
    output = tmux_command("list-panes", "-a", "-F", fields, capture=True)
    snapshots: dict[str, dict[str, Any]] = {}
    for line in output.splitlines():
        values = (line.split(separator, 9) + [""] * 10)[:10]
        (
            window,
            fallback,
            pane,
            command,
            start_command,
            path,
            agent,
            project,
            state,
            cached,
        ) = values
        if not window or not pane:
            continue
        snapshot = snapshots.setdefault(
            window, {"fallback": fallback, "cached": cached, "panes": {}}
        )
        snapshot["panes"][pane] = {
            "command": command,
            "start_command": start_command,
            "path": path,
            "agent": agent,
            "project": project,
            "state": state,
        }
    return snapshots


def tmux_commands(commands: list[tuple[str, ...]]) -> None:
    arguments: list[str] = []
    for command in commands:
        if arguments:
            arguments.append(";")
        arguments.extend(command)
    if arguments:
        tmux_command(*arguments)


def sync_cached_status(frame: int) -> bool:
    any_running = False
    updates: list[tuple[str, ...]] = []
    for window, snapshot in window_snapshots().items():
        rendered, running = render_entries_with_activity(
            list(snapshot["panes"].values()),
            frame,
            "",
        )
        if rendered != snapshot["cached"]:
            updates.append(
                ("set-option", "-wq", "-t", window, RENDERED_OPTION, rendered)
            )
        any_running = any_running or running
    if updates:
        tmux_commands(updates)
        try:
            tmux_command("refresh-client", "-S")
        except subprocess.CalledProcessError:
            pass
    return any_running


def animator_lock_path() -> Path:
    tmux_server = ",".join(os.environ.get("TMUX", "").split(",")[:2])
    identity = hashlib.sha256(tmux_server.encode()).hexdigest()[:16]
    runtime = Path(
        os.environ.get("XDG_RUNTIME_DIR")
        or os.environ.get("TMPDIR")
        or "/tmp"
    )
    directory = runtime / f"tmux-agent-status-{os.getuid()}"
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    return directory / f"{identity}.lock"


def start_animator() -> None:
    subprocess.Popen(
        [sys.executable, str(Path(__file__).resolve()), "animate"],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def run_animator() -> int:
    with animator_lock_path().open("a+") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return 0

        pid = str(os.getpid())
        try:
            tmux_command("set-option", "-gq", ANIMATOR_PID_OPTION, pid)
            frame = 0
            while sync_cached_status(frame):
                frame = (frame + 1) % len(SPINNER)
                time.sleep(ANIMATION_INTERVAL)
        except subprocess.CalledProcessError:
            pass
        finally:
            try:
                owner = tmux_command(
                    "show-options", "-gqv", ANIMATOR_PID_OPTION, capture=True
                )
                if owner == pid:
                    tmux_command("set-option", "-gu", ANIMATOR_PID_OPTION)
                    tmux_command("refresh-client", "-S")
            except subprocess.CalledProcessError:
                pass
    return 0


def sync_and_animate() -> None:
    if sync_cached_status(0):
        try:
            start_animator()
        except OSError:
            pass


def read_payload() -> dict[str, Any]:
    try:
        value = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        return {}
    return value if isinstance(value, dict) else {}


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    hook = subparsers.add_parser("hook")
    hook.add_argument("--agent", required=True, choices=sorted(SUPPORTED_AGENTS))
    hook.add_argument("--event", required=True)

    render = subparsers.add_parser("render-window")
    render.add_argument("window")
    render.add_argument("fallback")

    subparsers.add_parser("sync")
    subparsers.add_parser("animate")

    args = parser.parse_args()
    if args.command == "render-window":
        if not os.environ.get("TMUX"):
            print(sanitize_label(args.fallback), end="")
            return 0
        print(render_window(args.window, args.fallback), end="")
        return 0

    if args.command == "animate":
        if not os.environ.get("TMUX"):
            return 0
        return run_animator()

    if args.command == "sync":
        if os.environ.get("TMUX"):
            try:
                sync_and_animate()
            except subprocess.CalledProcessError:
                pass
        return 0

    payload = read_payload()
    try:
        state = state_for_event(args.event, payload)
        set_pane_status(args.agent, state, payload)
        sync_and_animate()
    except (ValueError, subprocess.CalledProcessError):
        pass
    print("{}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
