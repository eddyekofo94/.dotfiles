#!/usr/bin/env python3
"""Small raw-terminal composer with Ghostty bracketed-paste support."""

from __future__ import annotations

import os
import select
import subprocess
import sys
import termios
import tty
from pathlib import Path

PASTE_START = b"\x1b[200~"
PASTE_END = b"\x1b[201~"


def safe_display(content: bytes) -> str:
    text = content.decode("utf-8", "replace")
    return "".join(
        character
        if character in "\n\t" or ord(character) >= 32 and ord(character) != 127
        else "\N{SYMBOL FOR SUBSTITUTE FORM TWO}"
        for character in text
    )


def repaint(content: bytes) -> None:
    display = safe_display(content)
    sys.stdout.write(
        "\x1b[2J\x1b[H"
        "Message agent — Cmd-V pastes, Enter inserts without submitting, "
        "Ctrl-U clears, Esc cancels\n"
        "────────────────────────────────────────────────────────────────\n"
        f"{display}\n"
        "────────────────────────────────────────────────────────────────\n"
    )
    sys.stdout.flush()


def read_escape(fd: int) -> bytes:
    sequence = bytearray(b"\x1b")
    while len(sequence) < len(PASTE_START):
        if not select.select([fd], [], [], 0.06)[0]:
            break
        sequence.extend(os.read(fd, 1))
        if sequence == PASTE_START:
            break
        if not PASTE_START.startswith(sequence):
            break
    return bytes(sequence)


def read_paste(fd: int) -> bytes:
    content = bytearray()
    pending = bytearray()
    while True:
        byte = os.read(fd, 1)
        if not byte:
            raise EOFError
        pending.extend(byte)
        if pending == PASTE_END:
            return bytes(content)
        while pending and not PASTE_END.startswith(pending):
            content.append(pending.pop(0))


def remove_character(content: bytearray) -> None:
    if not content:
        return
    start = len(content) - 1
    while start > 0 and content[start] & 0xC0 == 0x80:
        start -= 1
    del content[start:]


def compose(destination: Path) -> int:
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        print("agent-message: composer requires an interactive terminal", file=sys.stderr)
        return 2
    fd = sys.stdin.fileno()
    original = termios.tcgetattr(fd)
    content = bytearray()
    try:
        tty.setraw(fd)
        sys.stdout.write("\x1b[?2004h")
        repaint(content)
        while True:
            byte = os.read(fd, 1)
            if not byte:
                return 1
            if byte == b"\x1b":
                sequence = read_escape(fd)
                if sequence == PASTE_START:
                    content.extend(read_paste(fd))
                    repaint(content)
                    continue
                return 1
            if byte in (b"\r", b"\n"):
                if content:
                    destination.write_bytes(content)
                return 0
            if byte == b"\x03":
                return 1
            if byte == b"\x15":
                content.clear()
            elif byte in (b"\x7f", b"\x08"):
                remove_character(content)
            elif byte == b"\x00":
                continue
            else:
                content.extend(byte)
            repaint(content)
    finally:
        sys.stdout.write("\x1b[?2004l\x1b[2J\x1b[H")
        sys.stdout.flush()
        termios.tcsetattr(fd, termios.TCSADRAIN, original)


def dispatch(message_file: Path) -> int:
    binary = os.environ.get("HERDR_INSERT_BIN", "herdr")
    session = os.environ["HERDR_INSERT_SESSION"]
    pane = os.environ["HERDR_INSERT_PANE"]
    message = message_file.read_bytes()
    if not message:
        return 0
    if b"\x00" in message:
        print("agent-message: NUL bytes are not supported", file=sys.stderr)
        return 2
    bracketed = b"\x1b[200~" + message + b"\x1b[201~"
    result = subprocess.run(
        [os.fsencode(binary), b"--session", os.fsencode(session), b"pane",
         b"send-text", os.fsencode(pane), bracketed],
        check=False,
    )
    return result.returncode


def main() -> int:
    if len(sys.argv) == 3 and sys.argv[1] == "--dispatch":
        return dispatch(Path(sys.argv[2]))
    if len(sys.argv) == 2:
        return compose(Path(sys.argv[1]))
    print("usage: agent_message_composer.py [--dispatch] MESSAGE_FILE", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
