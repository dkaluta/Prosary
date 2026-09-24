#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Optional PTY checks: uv run --script tests/test_pty.py [./prosary].

Uses temporary state files; not part of the C-only build or ordinary make test.
"""
from __future__ import annotations
import datetime
import fcntl
import locale
import os
from pathlib import Path
import pty
import re
import select
import signal
import struct
import subprocess
import sys
import tempfile
import termios
import time

RIGHT, LEFT, UP, DOWN, END = b"\x1bOC", b"\x1bOD", b"\x1bOA", b"\x1bOB", b"\x1bOF"


def utf8_locale():
    for candidate in ("C.UTF-8", "en_US.UTF-8", "UTF-8"):
        try:
            locale.setlocale(locale.LC_CTYPE, candidate)
            return candidate
        except locale.Error:
            pass
    raise RuntimeError("The PTY checks need an installed UTF-8 locale")


class Terminal:
    def __init__(self, binary, *args):
        self.master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 105, 0, 0))
        self.process = subprocess.Popen([str(binary), *args], stdin=slave, stdout=slave, stderr=slave,
            env={**os.environ, "TERM": "xterm-256color", "LC_ALL": utf8_locale()})
        os.close(slave)
        self.initial = self.read(0.7)
        if b"Prosary" not in self.initial:
            self.close()
            raise AssertionError(f"No initial terminal screen: {self.initial!r}")

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()

    def read(self, duration=0.18):
        output, deadline = b"", time.monotonic() + duration
        while self.master >= 0 and time.monotonic() < deadline:
            if select.select([self.master], [], [], 0.025)[0]:
                try:
                    output += os.read(self.master, 65536)
                except OSError:
                    break
        return output

    def key(self, key):
        os.write(self.master, key)
        return self.read()

    def resize(self, rows, columns):
        fcntl.ioctl(self.master, termios.TIOCSWINSZ, struct.pack("HHHH", rows, columns, 0, 0))
        self.process.send_signal(signal.SIGWINCH)
        self.read()
        assert self.process.poll() is None, "Process exited on resize"

    def quit(self, expected=0):
        output = self.key(b"q")
        self.process.wait(timeout=5)
        output += self.read()
        assert self.process.returncode == expected, (self.process.returncode, output)
        return output

    def close(self):
        if self.master >= 0:
            os.close(self.master)
            self.master = -1
        if self.process.poll() is None:
            try:
                self.process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=3)
                raise AssertionError("Prosary did not exit after its PTY was closed")


def saved(path):
    lines = path.read_text().splitlines()
    assert lines.pop(0) == "prosary-terminal-state 1"
    return dict(line.split(" ", 1) for line in lines)


def date_of(state):
    return datetime.date(int(state["year"]), int(state["month"]), int(state["dayOfMonth"]))


def main():
    binary = Path(sys.argv[1] if len(sys.argv) > 1 else "./prosary").resolve()
    with tempfile.TemporaryDirectory(prefix="prosary-pty-") as directory:
        state = Path(directory) / "state"
        with Terminal(binary, "--pray", "rosary", "--language", "en", "--group", "joyful", "--state", str(state)) as term:
            assert b"Step 1 /" in term.initial and b"Sign of the Cross" in term.initial
            term.key(RIGHT)
            assert saved(state)["step"] == "1"
            term.key(RIGHT)
            assert saved(state)["step"] == "2"
            term.key(LEFT)
            assert saved(state)["step"] == "1"
            term.key(b"\x1b")
            term.key(END)
            term.key(UP)
            screen = term.key(b"\r")
            assert b"Settings" in screen and b"App Language" in screen
            term.key(RIGHT)
            assert saved(state)["interfaceLanguageCode"] == "he"
            term.key(LEFT)
            assert saved(state)["interfaceLanguageCode"] == "en"
            term.key(DOWN)
            term.key(RIGHT)
            assert saved(state)["defaultLanguageCode"] == "he" and saved(state)["step"] == "0"
            term.resize(16, 42)
            term.key(b"\x1b")
            term.key(b"\t")
            assert b"Help" in term.key(b"?")
            term.key(DOWN)
            term.key(b"\x1b")
            term.resize(30, 105)
            term.quit()
        print("PTY: arrows, focus, settings, UI/prayer languages, resize, help, and clean quit passed")
        with Terminal(binary, "--state", str(state)) as term:
            term.key(RIGHT)
            term.quit()
        assert saved(state)["step"] == "1" and saved(state)["defaultLanguageCode"] == "he"
        print("PTY: saved Hebrew session resumed and advanced")
        keyboard_state = Path(directory) / "keyboard-state"
        with Terminal(binary, "--pray", "rosary", "--group", "joyful", "--state", str(keyboard_state)) as term:
            term.key(b" ")
            assert saved(keyboard_state)["step"] == "1"
            term.key(b"\x1b")
            term.key(END)
            term.key(UP)
            term.key(b"\r")
            for _ in range(7):
                term.key(DOWN)
            term.key(RIGHT)  # Space advance, the final setting.
            term.key(UP)
            term.key(RIGHT)  # Arrow navigation.
            prefs = saved(keyboard_state)
            assert prefs["keyboardArrowNavigationEnabled"] == prefs["keyboardSpaceAdvanceEnabled"] == "0"
            assert prefs["step"] == "1", "Changing keyboard settings restarted the prayer"
            term.key(b"\x1b")
            term.key(b"\t")
            term.key(RIGHT)
            term.key(b" ")
            assert saved(keyboard_state)["step"] == "1"
            term.key(b"\r")
            assert saved(keyboard_state)["step"] == "2"
            term.key(b"\x7f")
            assert saved(keyboard_state)["step"] == "1"
            term.quit()
        with Terminal(binary, "--state", str(keyboard_state)) as term:
            term.key(RIGHT)
            term.key(b" ")
            assert saved(keyboard_state)["step"] == "1"
            term.quit()
        print("PTY: keyboard switches preserve progress, gate their keys, and survive relaunch")
        # This historical Easter session must remain Regina Caeli even when the
        # current local date lies outside Eastertide.
        state.write_text("prosary-terminal-state 1\ndevotion angelus\ndefaultLanguageCode en\n"
            "interfaceLanguageCode en\nstep 0\ngroup 0\nvariant -1\nday 0\ncompleted 0\n"
            "year 2026\nmonth 4\ndayOfMonth 5\n")
        today_before = datetime.date.today()
        with Terminal(binary, "--state", str(state)) as term:
            assert b"Step 1 / 1" in term.initial
            assert date_of(saved(state)) == datetime.date(2026, 4, 5)
            term.key(RIGHT)
            assert saved(state)["completed"] == "1"
            term.key(LEFT)
            assert saved(state)["completed"] == "0" and saved(state)["step"] == "0"
            term.key(RIGHT)
            term.key(b"\x1b")
            term.key(b"\r")
            assert saved(state)["completed"] == "0"
            assert date_of(saved(state)) in (today_before, datetime.date.today())
            term.quit()
        # Use a fresh screen; curses can update only the changed counter digit.
        dump = subprocess.run([str(binary), "--dump", "angelus", "--language", "en", "--no-state"], capture_output=True, check=True).stdout
        count = re.search(rb"\((\d+) steps\)", dump).group(1)
        with Terminal(binary, "--state", str(state)) as term:
            assert b"Step 1 / " + count in term.initial
            term.quit()
        print("PTY: date-pinned Easter resume, completion, backtracking, and fresh-date restart passed")
        blocked = Path(directory) / "not-a-directory"
        blocked.write_text("Cannot contain a state file")
        with Terminal(binary, "--state", str(blocked / "state")) as term:
            assert b"Could not save progress" in term.initial
            output = term.quit(expected=2)
            assert b"progress could not be saved" in output.lower(), output
        print("PTY: save failure is visible and returns a failing exit status")
        with Terminal(binary, "--no-state"):
            pass  # close() checks EOF/PTY loss exits rather than spinning.
        print("PTY: closed terminal exits promptly")


if __name__ == "__main__":
    main()
