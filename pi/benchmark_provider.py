#!/usr/bin/env python3
"""Run the same bounded, no-tool task through native Codex and isolated Pi."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PI_DIR = ROOT / "pi"
TASK = (PI_DIR / "provider-task.txt").read_text(encoding="utf-8")
EVIDENCE_DIR = Path(os.environ.get("PI_PILOT_EVIDENCE_DIR", PI_DIR / "evidence"))


def json_lines(output: str) -> list[dict]:
    events = []
    for line in output.splitlines():
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            events.append(value)
    return events


def json_object(text: str) -> dict:
    start = text.find("{")
    end = text.rfind("}")
    if start < 0 or end <= start:
        raise ValueError("assistant output did not contain a JSON object")
    value = json.loads(text[start : end + 1])
    if not isinstance(value, dict):
        raise ValueError("assistant output was not a JSON object")
    return value


def score(answer: dict) -> dict:
    result_ok = answer.get("result") == ["a", "b"]
    fix_text = str(answer.get("fix", "")).lower()
    bug_text = str(answer.get("bug", "")).lower()
    fix_ok = (
        "seen.add" in fix_text
        and "selected.append" in fix_text
        and "inside" in fix_text
        and "if block" in fix_text
    )
    bug_ok = (
        "disabled" in bug_text
        and ("seen" in bug_text or "block" in bug_text or "prevent" in bug_text)
    )
    time_ok = str(answer.get("time_complexity", "")).replace(" ", "") == "O(n)"
    space_ok = str(answer.get("space_complexity", "")).replace(" ", "") == "O(n)"
    checks = {
        "correct_result": result_ok,
        "correct_fix": fix_ok,
        "correct_bug": bug_ok,
        "time_complexity": time_ok,
        "space_complexity": space_ok,
    }
    return {"checks": checks, "passed": sum(checks.values()), "possible": len(checks)}


def run(command: list[str], timeout: int = 180) -> tuple[str, float]:
    started = time.monotonic()
    completed = subprocess.run(
        command,
        cwd=ROOT,
        input=TASK,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
        check=False,
    )
    elapsed = time.monotonic() - started
    if completed.returncode != 0:
        raise RuntimeError(
            f"{command[0]} exited {completed.returncode}: {completed.stderr.strip()}"
        )
    return completed.stdout, elapsed


def pi_result(output: str, elapsed: float) -> dict:
    events = json_lines(output)
    assistants = [
        event["message"]
        for event in events
        if event.get("type") == "message_end"
        and event.get("message", {}).get("role") == "assistant"
    ]
    if not assistants:
        raise RuntimeError("Pi emitted no final assistant message")
    message = assistants[-1]
    text = "".join(
        item.get("text", "")
        for item in message.get("content", [])
        if item.get("type") == "text"
    )
    answer = json_object(text)
    return {
        "model": {
            "provider": message.get("provider"),
            "id": message.get("model"),
        },
        "elapsed_seconds": round(elapsed, 6),
        "usage": message.get("usage"),
        "answer": answer,
        "score": score(answer),
    }


def codex_result(output: str, elapsed: float) -> dict:
    events = json_lines(output)
    messages = [
        event.get("item", {})
        for event in events
        if event.get("type") == "item.completed"
        and event.get("item", {}).get("type") == "agent_message"
    ]
    if not messages:
        raise RuntimeError("Codex emitted no final agent message")
    answer = json_object(str(messages[-1].get("text", "")))
    completed = next(
        (event for event in reversed(events) if event.get("type") == "turn.completed"),
        {},
    )
    return {
        "model": "native Codex configured model",
        "elapsed_seconds": round(elapsed, 6),
        "usage": completed.get("usage"),
        "monetary_cost": "not exposed by native Codex JSON stream",
        "answer": answer,
        "score": score(answer),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--run",
        action="store_true",
        help="authorize the two provider calls after Pi login is configured",
    )
    parser.add_argument(
        "--rescore",
        action="store_true",
        help="rescore existing raw provider streams without making provider calls",
    )
    parser.add_argument(
        "--pi-model",
        help="optional Pi provider/model pattern; otherwise use its configured default",
    )
    args = parser.parse_args()

    if args.run and args.rescore:
        raise ValueError("choose either --run or --rescore")

    if args.rescore:
        comparison_path = EVIDENCE_DIR / "provider-comparison.json"
        previous = json.loads(comparison_path.read_text(encoding="utf-8"))
        pi_output = (EVIDENCE_DIR / "provider-pi.jsonl").read_text(encoding="utf-8")
        codex_output = (EVIDENCE_DIR / "provider-codex.jsonl").read_text(
            encoding="utf-8"
        )
        comparison = {
            "status": "PASS",
            "task": str(PI_DIR / "provider-task.txt"),
            "method": "same no-tool prompt; native JSON streams; one run each",
            "rescore": {
                "provider_calls_repeated": False,
                "reason": "The original scorer incorrectly required the word enabled in an otherwise exact fix-placement answer.",
            },
            "pi": pi_result(pi_output, previous["pi"]["elapsed_seconds"]),
            "codex": codex_result(
                codex_output, previous["codex"]["elapsed_seconds"]
            ),
        }
        if comparison["pi"]["score"]["passed"] < comparison["pi"]["score"]["possible"]:
            comparison["status"] = "FAIL"
        if (
            comparison["codex"]["score"]["passed"]
            < comparison["codex"]["score"]["possible"]
        ):
            comparison["status"] = "FAIL"
        comparison_path.write_text(
            json.dumps(comparison, indent=2) + "\n", encoding="utf-8"
        )
        print(f"Provider comparison rescore: {comparison['status']} ({comparison_path})")
        return 0 if comparison["status"] == "PASS" else 1

    if not args.run:
        print("Provider benchmark is dry-run by default.")
        print("After ./pi/pilot.sh /login, run: ./pi/benchmark_provider.py --run")
        return 0

    models = subprocess.run(
        [str(PI_DIR / "pilot.sh"), "--list-models"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if models.returncode != 0 or "No models available" in models.stdout:
        raise RuntimeError(
            "isolated Pi has no authenticated provider; run ./pi/pilot.sh and /login"
        )

    pi_command = [
        str(PI_DIR / "pilot.sh"),
        "--mode",
        "json",
        "--print",
        "--no-session",
        "--no-tools",
    ]
    if args.pi_model:
        pi_command.extend(["--model", args.pi_model])
    pi_output, pi_elapsed = run(pi_command)

    codex_output, codex_elapsed = run(
        [
            "codex",
            "exec",
            "--json",
            "--ephemeral",
            "--sandbox",
            "read-only",
            "--skip-git-repo-check",
            "-",
        ]
    )

    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    (EVIDENCE_DIR / "provider-pi.jsonl").write_text(
        pi_output, encoding="utf-8"
    )
    (EVIDENCE_DIR / "provider-codex.jsonl").write_text(
        codex_output, encoding="utf-8"
    )
    comparison = {
        "status": "PASS",
        "task": str(PI_DIR / "provider-task.txt"),
        "method": "same no-tool prompt; native JSON streams; one run each",
        "pi": pi_result(pi_output, pi_elapsed),
        "codex": codex_result(codex_output, codex_elapsed),
    }
    if comparison["pi"]["score"]["passed"] < comparison["pi"]["score"]["possible"]:
        comparison["status"] = "FAIL"
    if (
        comparison["codex"]["score"]["passed"]
        < comparison["codex"]["score"]["possible"]
    ):
        comparison["status"] = "FAIL"
    path = EVIDENCE_DIR / "provider-comparison.json"
    path.write_text(json.dumps(comparison, indent=2) + "\n", encoding="utf-8")
    print(f"Provider comparison: {comparison['status']} ({path})")
    return 0 if comparison["status"] == "PASS" else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"provider-benchmark: {error}", file=sys.stderr)
        sys.exit(1)
