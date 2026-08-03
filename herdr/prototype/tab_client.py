#!/usr/bin/env python3
"""Drive real Herdr prefix bindings through a fixed-size disposable PTY."""

from __future__ import annotations

import fcntl
import os
import pty
import select
import struct
import subprocess
import sys
import termios
import time


KEYS = {
    "create": b"\x01c",
    # Ghostty/Kitty CSI-u: n with Alt+Ctrl (1 + Alt 2 + Ctrl 4 = modifier 7).
    "alt-ctrl-new-tab": b"\x1b[110;7u",
    "alt-t": b"\x1b[116;3u",
    "next": b"\x01n",
    "previous": b"\x01p",
    "index1": b"\x011",
    "index2": b"\x012",
    "index3": b"\x013",
    "index4": b"\x014",
    "index7": b"\x017",
    "last": b"\x01\t",
    "move-left": b"\x01{",
    "move-right": b"\x01}",
    "close": b"\x01X",
    "close-others": b"\x01\x18",
    "close-other-panes": b"\x01o",
    "equalize-panes": b"\x01=",
    "quit": b"\x01q",
}


def drain(master: int, duration: float) -> None:
    deadline = time.monotonic() + duration
    while time.monotonic() < deadline:
        readable, _, _ = select.select([master], [], [], 0.05)
        if not readable:
            continue
        try:
            os.read(master, 65_536)
        except OSError:
            return


def main() -> int:
    if len(sys.argv) != 6:
        print(
            "usage: tab_client.py HERDR XDG_CONFIG_HOME CONFIG SESSION PROTOTYPE",
            file=sys.stderr,
        )
        return 2

    herdr, config_home, config, session, prototype = sys.argv[1:]
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 100, 0, 0))
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
        [herdr, "--session", session],
        stdin=slave,
        stdout=slave,
        stderr=slave,
        env=env,
        start_new_session=True,
        close_fds=True,
    )
    os.close(slave)
    try:
        drain(master, 0.8)
        print("READY", flush=True)
        for raw_action in sys.stdin:
            action = raw_action.strip()
            if action not in KEYS:
                print(f"unknown tab client action: {action}", file=sys.stderr)
                return 2
            os.write(master, KEYS[action])
            drain(master, 0.4)
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
