#!/usr/bin/env python3
"""Focus the next or previous agent in Herdr's emitted sidebar order."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from typing import Any


def fail(message: str) -> "NoReturn":
    raise SystemExit(f"agent-cycle: {message}")


def cli(*args: str) -> dict[str, Any]:
    command = [os.environ.get("HERDR_BIN_PATH", "herdr")]
    session = os.environ.get("HERDR_SESSION")
    if session:
        command.extend(("--session", session))
    command.extend(args)
    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True)
        value = json.loads(result.stdout)
    except subprocess.CalledProcessError as error:
        detail = error.stderr.strip() or error.stdout.strip() or str(error)
        fail(f"Herdr command failed: {' '.join(args)} ({detail})")
    except (OSError, json.JSONDecodeError) as error:
        fail(f"Herdr command failed: {' '.join(args)} ({error})")
    if not isinstance(value, dict):
        fail("Herdr returned a malformed response")
    return value


def result_array(response: dict[str, Any], name: str) -> list[dict[str, Any]]:
    result = response.get("result")
    values = result.get(name) if isinstance(result, dict) else None
    if not isinstance(values, list) or not all(isinstance(item, dict) for item in values):
        fail(f"Herdr returned a malformed {name} list")
    return values


def agent_identity(agent: dict[str, Any]) -> tuple[str, str, str, Any]:
    terminal = agent.get("terminal_id")
    pane = agent.get("pane_id")
    label = agent.get("agent")
    session = agent.get("agent_session")
    if not all(isinstance(value, str) and value for value in (terminal, pane, label)):
        fail("agent identity is incomplete")
    if session is not None and not isinstance(session, dict):
        fail("agent session identity is malformed")
    return terminal, pane, label, session


def choose(direction: str, agents: list[dict[str, Any]], tabs: list[dict[str, Any]]) -> dict[str, Any] | None:
    if not agents:
        return None

    identities = [agent_identity(agent)[0] for agent in agents]
    if len(set(identities)) != len(identities):
        fail("agent identities are not unique")

    focused_agents = [index for index, agent in enumerate(agents) if agent.get("focused") is True]
    if len(focused_agents) > 1:
        fail("more than one agent is focused")
    step = 1 if direction == "next" else -1
    if focused_agents:
        return agents[(focused_agents[0] + step) % len(agents)]

    focused_tabs = [index for index, tab in enumerate(tabs) if tab.get("focused") is True]
    if len(focused_tabs) != 1:
        fail("unable to identify the focused non-agent tab")
    tab_positions: dict[str, int] = {}
    for index, tab in enumerate(tabs):
        tab_id = tab.get("tab_id")
        if not isinstance(tab_id, str) or not tab_id or tab_id in tab_positions:
            fail("tab identities are incomplete or duplicated")
        tab_positions[tab_id] = index

    current = focused_tabs[0]
    candidates: list[tuple[int, dict[str, Any]]] = []
    for agent in agents:
        tab_id = agent.get("tab_id")
        if not isinstance(tab_id, str) or tab_id not in tab_positions:
            fail("agent tab is absent from the native tab list")
        candidates.append((tab_positions[tab_id], agent))

    if direction == "next":
        return next((agent for position, agent in candidates if position > current), agents[0])
    return next((agent for position, agent in reversed(candidates) if position < current), agents[-1])


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in {"next", "previous"}:
        print("usage: agent_cycle.py next|previous", file=sys.stderr)
        return 2
    direction = sys.argv[1]
    agents = result_array(cli("agent", "list"), "agents")
    tabs = result_array(cli("tab", "list"), "tabs")
    target = choose(direction, agents, tabs)
    if target is None:
        return 0

    expected_identity = agent_identity(target)
    pane = expected_identity[1]
    fresh_agents = result_array(cli("agent", "list"), "agents")
    matches = [agent for agent in fresh_agents if agent_identity(agent) == expected_identity]
    if len(matches) != 1:
        fail("target agent changed or disappeared")

    # Pane IDs are the stable session-scoped focus target for both reported and
    # detected agents; terminal ID remains part of the stale-target identity.
    response = cli("agent", "focus", pane)
    result = response.get("result")
    focused = result.get("agent") if isinstance(result, dict) else None
    if not isinstance(focused, dict) or agent_identity(focused) != expected_identity:
        fail("focus response does not match the selected agent")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
