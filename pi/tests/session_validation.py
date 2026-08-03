#!/usr/bin/env python3
"""Exercise Pi session identity, resume, and compaction over its RPC protocol."""

from __future__ import annotations

import json
import os
import select
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PI = ROOT / "pi" / "pilot.sh"
PROVIDER = ROOT / "pi" / "tests" / "mock_provider.ts"
EVIDENCE = Path(
    os.environ.get("PI_PILOT_EVIDENCE_DIR", ROOT / "pi" / "evidence")
) / "session-validation.json"
SENTINELS = [
    "pi-global-response-style-parity",
    "256b38fbe0067fb51bde5c275def7eabe3ba2aa0c6e5070572f814c12d2f27ce",
    "canonical repository",
    "concurrency-safe",
    "commit",
    "Codex",
    "Claude",
    "pi/verify.sh",
    "physical-device",
    "fresh Standards/Fidelity review",
]
OPEN_RPCS: list["Rpc"] = []


class Rpc:
    def __init__(self, *args: str):
        env = os.environ.copy()
        env["PI_PILOT_FIXTURE"] = "1"
        self.process = subprocess.Popen(
            [
                str(PI),
                "--mode",
                "rpc",
                "--offline",
                "--extension",
                str(PROVIDER),
                "--model",
                "eddy-fixture/fixture",
                *args,
            ],
            cwd=ROOT,
            env=env,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=False,
            bufsize=0,
        )
        self.sequence = 0
        self.events: list[dict] = []
        OPEN_RPCS.append(self)

    def send(self, command: dict) -> str:
        self.sequence += 1
        request_id = f"request-{self.sequence}"
        command = {"id": request_id, **command}
        assert self.process.stdin
        self.process.stdin.write((json.dumps(command) + "\n").encode("utf-8"))
        self.process.stdin.flush()
        return request_id

    def wait(self, predicate, description: str, timeout: float = 15.0) -> dict:
        assert self.process.stdout
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            ready, _, _ = select.select(
                [self.process.stdout], [], [], max(0, deadline - time.monotonic())
            )
            if not ready:
                break
            line = self.process.stdout.readline()
            if not line:
                break
            event = json.loads(line.decode("utf-8"))
            self.events.append(event)
            if predicate(event):
                return event
        stderr = ""
        if self.process.poll() is not None and self.process.stderr:
            stderr = self.process.stderr.read().decode("utf-8", errors="replace")
        recent = [
            {
                "type": event.get("type"),
                "reason": event.get("reason"),
                "error": event.get("error"),
                "errorMessage": event.get("errorMessage"),
            }
            for event in self.events[-12:]
        ]
        raise RuntimeError(
            f"timed out waiting for {description}: {stderr}; recent={recent}"
        )

    def request(self, command: dict) -> dict:
        request_id = self.send(command)
        return self.wait(
            lambda event: event.get("id") == request_id,
            f"response to {command['type']}",
        )

    def wait_since(self, index: int, predicate, description: str) -> dict:
        for event in self.events[index:]:
            if predicate(event):
                return event
        return self.wait(predicate, description)

    def prompt(self, message: str) -> None:
        start = len(self.events)
        response = self.request({"type": "prompt", "message": message})
        if not response.get("success"):
            raise RuntimeError(f"prompt rejected: {response}")
        self.wait_since(
            start,
            lambda event: event.get("type") == "agent_settled",
            "agent settlement",
        )

    def reload(self) -> None:
        response = self.request({"type": "prompt", "message": "/reload"})
        if not response.get("success"):
            raise RuntimeError(f"reload rejected: {response}")

    def close(self) -> None:
        return_code = None
        stderr = ""
        try:
            if self.process.stdin and not self.process.stdin.closed:
                self.process.stdin.close()
            return_code = self.process.wait(timeout=5)
            if return_code != 0 and self.process.stderr:
                stderr = self.process.stderr.read().decode(
                    "utf-8", errors="replace"
                )
        finally:
            if self in OPEN_RPCS:
                OPEN_RPCS.remove(self)
            if self.process.poll() is None:
                self.process.terminate()
                try:
                    self.process.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    self.process.kill()
                    self.process.wait(timeout=2)
        if return_code != 0:
            raise RuntimeError(f"Pi RPC exited {return_code}: {stderr}")

    def terminate_safely(self) -> None:
        try:
            if self.process.stdin and not self.process.stdin.closed:
                self.process.stdin.close()
        except BrokenPipeError:
            pass
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=2)
        if self in OPEN_RPCS:
            OPEN_RPCS.remove(self)


def state(rpc: Rpc) -> dict:
    response = rpc.request({"type": "get_state"})
    if not response.get("success"):
        raise RuntimeError(f"get_state failed: {response}")
    return response["data"]

def wait_state(rpc: Rpc, predicate, description: str) -> dict:
    for _ in range(100):
        current = state(rpc)
        if predicate(current):
            return current
        time.sleep(0.02)
    raise RuntimeError(f"timed out waiting for {description}: {current}")


def main() -> int:
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    cleanup_probe = Rpc("--no-session")
    cleanup_pid = cleanup_probe.process.pid
    cleanup_probe.terminate_safely()
    if cleanup_probe.process.poll() is None:
        raise RuntimeError(f"RPC cleanup probe left child {cleanup_pid} running")
    seed = (
        "Active goal pi-compaction-fixture. Preserve dirty work. Do not commit "
        "or push. Keep Codex and Claude fallbacks. Verification is pi/verify.sh. "
        "Physical two-window Ghostty QA remains a human gate. The active skill "
        "is feature-plan. Next stage is fresh Standards and Fidelity review."
    )

    alpha = Rpc("--session-id", "pilot-alpha", "--name", "pilot-alpha")
    alpha.prompt(seed)
    alpha.reload()
    alpha.prompt("Verify the current handoff protocol after extension reload.")
    alpha_state = state(alpha)
    alpha_file = Path(alpha_state["sessionFile"])
    alpha.close()
    alpha_before_entries = [
        json.loads(line)
        for line in alpha_file.read_text(encoding="utf-8").splitlines()
        if line
    ]
    alpha_before_ids = {
        entry["id"] for entry in alpha_before_entries if entry.get("id")
    }

    beta = Rpc("--session-id", "pilot-beta", "--name", "pilot-beta")
    beta.prompt("Independent beta session.")
    beta_state = state(beta)
    beta_file = Path(beta_state["sessionFile"])
    beta.close()

    if alpha_file == beta_file or not alpha_file.is_file() or not beta_file.is_file():
        raise RuntimeError("named sessions are not independent and durable")

    resumed = Rpc("--session", str(alpha_file))
    resumed_state = wait_state(
        resumed,
        lambda current: current.get("sessionName") == "pilot-alpha"
        and current.get("messageCount", 0) >= 2,
        "resumed named session state",
    )
    if resumed_state.get("sessionName") != "pilot-alpha":
        raise RuntimeError(f"named session did not resume: {resumed_state}")
    resumed.request(
        {
            "type": "prompt",
            "message": "/eddy-pilot-fixture-active-skill feature-plan",
        }
    )
    compact_start = len(resumed.events)
    compact_request = resumed.send(
        {"type": "prompt", "message": "/eddy-pilot-fixture-compact"}
    )
    compact_response = resumed.wait(
        lambda event: event.get("id") == compact_request,
        "compaction command response",
    )
    if not compact_response.get("success"):
        raise RuntimeError(f"compaction command rejected: {compact_response}")
    compacted = resumed.wait_since(
        compact_start,
        lambda event: event.get("type") == "compaction_end",
        "manual compaction",
    )
    resumed_after = state(resumed)
    resumed.prompt("Continuation after the first compaction.")
    second_start = len(resumed.events)
    second_request = resumed.send(
        {"type": "prompt", "message": "/eddy-pilot-fixture-compact"}
    )
    second_response = resumed.wait(
        lambda event: event.get("id") == second_request,
        "second compaction command response",
    )
    if not second_response.get("success"):
        raise RuntimeError(f"second compaction command rejected: {second_response}")
    second_compacted = resumed.wait_since(
        second_start,
        lambda event: event.get("type") == "compaction_end",
        "second manual compaction",
    )
    resumed.close()

    result = compacted.get("result") or {}
    summary = result.get("summary", "")
    missing = [sentinel for sentinel in SENTINELS if sentinel not in summary]
    if compacted.get("reason") != "manual" or missing:
        raise RuntimeError(
            f"compaction continuity failed, reason={compacted.get('reason')}, "
            f"missing={missing}"
        )
    second_summary = (second_compacted.get("result") or {}).get("summary", "")
    for required_section in [
        "## Active skill\nfeature-plan",
        "## Validation Plan",
        "physical-device",
        "fresh Standards/Fidelity review",
    ]:
        if required_section not in second_summary:
            raise RuntimeError(
                f"repeated compaction lost structured obligation: {required_section}"
            )
    if resumed_after.get("sessionFile") != str(alpha_file):
        raise RuntimeError("compaction changed the owning session")

    entries = [
        json.loads(line)
        for line in alpha_file.read_text(encoding="utf-8").splitlines()
        if line
    ]
    after_ids = {entry["id"] for entry in entries if entry.get("id")}
    if not alpha_before_ids.issubset(after_ids):
        raise RuntimeError("manual compaction truncated append-only source history")
    if not any(
        entry.get("type") == "message"
        and entry.get("message", {}).get("role") == "user"
        and "pi-compaction-fixture" in json.dumps(entry.get("message"))
        for entry in entries
    ):
        raise RuntimeError("manual compaction lost the original user history")
    before_reasons = [
        entry.get("data", {}).get("reason")
        for entry in entries
        if entry.get("type") == "custom"
        and entry.get("customType") == "eddy-pi-pilot-compaction"
        and entry.get("data", {}).get("phase") == "before"
    ]
    compactions = [entry for entry in entries if entry.get("type") == "compaction"]
    if "manual" not in before_reasons or not compactions:
        raise RuntimeError("manual compaction was not durably recorded")

    threshold = Rpc("--session-id", "pilot-threshold", "--name", "pilot-threshold")
    threshold.prompt(seed)
    for turn in range(12):
        threshold.prompt(
            f"AUTO_THRESHOLD_FILLER turn {turn} "
            + "retain-context " * 300
            + " Keep the established active goal and constraints."
        )
        if any(
            event.get("type") == "compaction_end"
            and event.get("reason") == "threshold"
            and not event.get("aborted")
            for event in threshold.events
        ):
            break
    threshold_events = [
        event
        for event in threshold.events
        if event.get("type") == "compaction_end"
        and event.get("reason") == "threshold"
        and not event.get("aborted")
    ]
    threshold_state = state(threshold)
    threshold_file = Path(threshold_state["sessionFile"])
    threshold.close()
    if not threshold_events:
        raise RuntimeError("temporary threshold did not force automatic compaction")
    threshold_summary = (threshold_events[-1].get("result") or {}).get("summary", "")
    threshold_missing = [
        sentinel for sentinel in SENTINELS if sentinel not in threshold_summary
    ]
    if threshold_missing:
        raise RuntimeError(
            f"threshold compaction lost continuity sentinels: {threshold_missing}"
        )
    threshold_entries = [
        json.loads(line)
        for line in threshold_file.read_text(encoding="utf-8").splitlines()
        if line
    ]
    if not any(
        entry.get("type") == "message"
        and entry.get("message", {}).get("role") == "user"
        and "pi-compaction-fixture" in json.dumps(entry.get("message"))
        for entry in threshold_entries
    ):
        raise RuntimeError("threshold compaction truncated original JSONL history")

    evidence = {
        "status": "PASS",
        "provider": "deterministic offline fixture",
        "named_sessions": {
            "alpha": str(alpha_file),
            "beta": str(beta_file),
            "independent": True,
            "alpha_restored_name": resumed_state.get("sessionName"),
            "resume_locator": "session JSONL path",
        },
        "manual_compaction": {
            "reason": compacted.get("reason"),
            "session_unchanged": True,
            "source_jsonl_retained": alpha_file.is_file(),
            "pre_compaction_entry_ids_retained": True,
            "sentinels": SENTINELS,
            "all_sentinels_preserved": True,
            "repeated_compaction_preserved_active_skill": True,
            "structured_validation_plan_preserved": True,
        },
        "forced_threshold_compaction": {
            "status": "PASS",
            "reason": "threshold",
            "temporary_reserve_tokens": 20000,
            "temporary_keep_recent_tokens": 1,
            "session": str(threshold_file),
            "all_sentinels_preserved": True,
        },
    }
    EVIDENCE.write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
    print(f"Pi session validation: PASS ({EVIDENCE})")
    return 0


if __name__ == "__main__":
    try:
        result_code = main()
    finally:
        for open_rpc in list(OPEN_RPCS):
            open_rpc.terminate_safely()
    sys.exit(result_code)
