#!/usr/bin/env python3
"""Drive and capture the Herdr navigator through a disposable PTY client."""

from __future__ import annotations

import codecs
import fcntl
import os
import pty
import select
import signal
import struct
import subprocess
import sys
import termios
import time
import unicodedata


KEYS = {
    "workspace": b"\x01w",
    "goto": b"\x01f",
    "enter": b"\r",
    "esc": b"\x1b",
    "up": b"\x1b[A",
    "down": b"\x1b[B",
    "home": b"\x1b[H",
    "end": b"\x1b[F",
    "clear": b"\x15",
    "blocked": b"b",
    "working": b"w",
    "idle": b"i",
    "done": b"d",
    "all": b"a",
    "search": b"/",
    "scratch-popup": b"\x01\r",
    "lazygit-popup": b"\x01g",
    "layout-menu": b"\x01 ",
    "pane-transfer": b"\x01P",
    "manage-objects": b"\x01F",
    "visible-references": b"\x01R",
    "history-export": b"\x01U",
    "first-tab": b"\x01^",
    "last-tab": b"\x01$",
    "interrupt": b"\x03",
    "copy-mode": b"\x01s",
    "copy-half-up": b"\x15",
    "copy-half-down": b"\x04",
    "copy-page-up": b"\x1b[5~",
    "copy-page-down": b"\x1b[6~",
    "copy-quit": b"q",
    "open-url": b"\x01u",
    "previous-workspace": b"\x01(",
    "next-workspace": b"\x01)",
    "last-pane-direct": b"\x1e",
    "quit": b"\x01q",
    "snapshot": b"",
}


def character_width(char: str) -> int:
    if unicodedata.combining(char):
        return 0
    return 2 if unicodedata.east_asian_width(char) in {"W", "F"} else 1


class Screen:
    """Small VT screen model covering the control sequences Ratatui emits."""

    def __init__(self, rows: int, cols: int) -> None:
        self.rows = rows
        self.cols = cols
        self.grid = [[" "] * cols for _ in range(rows)]
        self.row = 0
        self.col = 0
        self.saved = (0, 0)
        self.decoder = codecs.getincrementaldecoder("utf-8")("replace")
        self.state = "text"
        self.sequence = ""

    def clear(self) -> None:
        self.grid = [[" "] * self.cols for _ in range(self.rows)]
        self.row = 0
        self.col = 0

    def feed(self, data: bytes) -> None:
        for char in self.decoder.decode(data):
            if self.state == "osc":
                if char == "\a":
                    self.state = "text"
                elif char == "\x1b":
                    self.state = "osc-esc"
                continue
            if self.state == "osc-esc":
                self.state = "text" if char == "\\" else "osc"
                continue
            if self.state == "esc":
                if char == "[":
                    self.state = "csi"
                    self.sequence = ""
                elif char == "]":
                    self.state = "osc"
                else:
                    self.handle_escape(char)
                    self.state = "text"
                continue
            if self.state == "csi":
                self.sequence += char
                if "@" <= char <= "~":
                    self.handle_csi(self.sequence)
                    self.state = "text"
                continue
            if char == "\x1b":
                self.state = "esc"
            elif char == "\r":
                self.col = 0
            elif char == "\n":
                self.row = min(self.rows - 1, self.row + 1)
            elif char == "\b":
                self.col = max(0, self.col - 1)
            elif char == "\t":
                self.col = min(self.cols - 1, (self.col // 8 + 1) * 8)
            elif char >= " ":
                self.put(char)

    def put(self, char: str) -> None:
        width = character_width(char)
        if width == 0:
            if self.col > 0:
                self.grid[self.row][self.col - 1] += char
            return
        if self.col >= self.cols:
            self.col = 0
            self.row = min(self.rows - 1, self.row + 1)
        self.grid[self.row][self.col] = char
        if width == 2 and self.col + 1 < self.cols:
            self.grid[self.row][self.col + 1] = " "
        self.col += width

    def handle_escape(self, final: str) -> None:
        if final == "7":
            self.saved = (self.row, self.col)
        elif final == "8":
            self.row, self.col = self.saved
        elif final == "c":
            self.clear()
        elif final == "D":
            self.row = min(self.rows - 1, self.row + 1)
        elif final == "M":
            self.row = max(0, self.row - 1)
        elif final == "E":
            self.row = min(self.rows - 1, self.row + 1)
            self.col = 0

    def handle_csi(self, sequence: str) -> None:
        final = sequence[-1]
        raw = sequence[:-1]
        private = raw.startswith("?")
        if private:
            raw = raw[1:]
        params = []
        for value in raw.split(";") if raw else []:
            try:
                params.append(int(value or "0"))
            except ValueError:
                params.append(0)

        def param(index: int, default: int = 1) -> int:
            if index >= len(params) or params[index] == 0:
                return default
            return params[index]

        if final in {"H", "f"}:
            self.row = min(self.rows - 1, max(0, param(0) - 1))
            self.col = min(self.cols - 1, max(0, param(1) - 1))
        elif final == "A":
            self.row = max(0, self.row - param(0))
        elif final in {"B", "e"}:
            self.row = min(self.rows - 1, self.row + param(0))
        elif final in {"C", "a"}:
            self.col = min(self.cols - 1, self.col + param(0))
        elif final == "D":
            self.col = max(0, self.col - param(0))
        elif final == "G":
            self.col = min(self.cols - 1, max(0, param(0) - 1))
        elif final == "d":
            self.row = min(self.rows - 1, max(0, param(0) - 1))
        elif final == "J":
            mode = params[0] if params else 0
            if mode in {2, 3}:
                self.clear()
            elif mode == 0:
                for col in range(self.col, self.cols):
                    self.grid[self.row][col] = " "
                for row in range(self.row + 1, self.rows):
                    self.grid[row] = [" "] * self.cols
        elif final == "K":
            mode = params[0] if params else 0
            if mode == 0:
                start, end = self.col, self.cols
            elif mode == 1:
                start, end = 0, self.col + 1
            else:
                start, end = 0, self.cols
            for col in range(start, end):
                self.grid[self.row][col] = " "
        elif final == "s":
            self.saved = (self.row, self.col)
        elif final == "u":
            self.row, self.col = self.saved
        elif final in {"h", "l"} and private and 1049 in params:
            self.clear()

    def render(self) -> str:
        return "\n".join("".join(row).rstrip() for row in self.grid).rstrip() + "\n"


def drain_until_quiet(
    master: int,
    screen: Screen,
    *,
    timeout: float = 3.0,
    quiet_period: float = 0.2,
) -> None:
    """Capture until semantic screen content is stable for a full window."""
    deadline = time.monotonic() + timeout
    quiet_deadline = time.monotonic() + quiet_period
    stable_render = semantic_render(screen)
    while time.monotonic() < deadline:
        remaining = min(deadline, quiet_deadline) - time.monotonic()
        if remaining <= 0:
            return
        readable, _, _ = select.select([master], [], [], remaining)
        if not readable:
            if time.monotonic() >= quiet_deadline:
                return
            continue
        try:
            screen.feed(os.read(master, 65_536))
        except OSError:
            return
        current_render = semantic_render(screen)
        if current_render != stable_render:
            stable_render = current_render
            quiet_deadline = time.monotonic() + quiet_period
    raise TimeoutError("Herdr PTY did not become quiet before the capture deadline")


def semantic_render(screen: Screen) -> str:
    """Normalize animation-only Braille spinner cells for stability checks."""
    return "".join(
        "⠀" if "⠀" <= char <= "⣿" else char for char in screen.render()
    )


def write_snapshot(path: str, screen: Screen) -> None:
    temporary = f"{path}.tmp"
    with open(temporary, "w", encoding="utf-8") as handle:
        handle.write(screen.render())
    os.replace(temporary, path)


def main() -> int:
    if len(sys.argv) != 7:
        print(
            "usage: picker_client.py HERDR XDG_CONFIG_HOME CONFIG SESSION PROTOTYPE SCREEN",
            file=sys.stderr,
        )
        return 2

    herdr, config_home, config, session, prototype, screen_path = sys.argv[1:]
    rows, cols = 40, 120
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
    env = os.environ.copy()
    env.update(
        {
            "TERM": "xterm-256color",
            "XDG_CONFIG_HOME": config_home,
            "HERDR_CONFIG_PATH": config,
            "HERDR_PROTOTYPE_DIR": prototype,
        }
    )
    process = subprocess.Popen(
        [herdr, "session", "attach", session],
        stdin=slave,
        stdout=slave,
        stderr=slave,
        env=env,
        start_new_session=True,
        close_fds=True,
    )
    os.close(slave)
    screen = Screen(rows, cols)

    def stop_on_signal(signum: int, _frame: object) -> None:
        raise SystemExit(128 + signum)

    signal.signal(signal.SIGINT, stop_on_signal)
    signal.signal(signal.SIGTERM, stop_on_signal)
    try:
        drain_until_quiet(master, screen)
        write_snapshot(screen_path, screen)
        print("READY", flush=True)
        for raw_action in sys.stdin:
            action = raw_action.rstrip("\n")
            if action.startswith("type:"):
                payload = action.removeprefix("type:").encode()
            elif action in KEYS:
                payload = KEYS[action]
            else:
                print(f"unknown picker client action: {action}", file=sys.stderr)
                return 2
            if payload:
                os.write(master, payload)
            drain_until_quiet(master, screen)
            write_snapshot(screen_path, screen)
            print(f"SENT {action}", flush=True)
            if action == "quit":
                return 0
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=1)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        os.close(master)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
