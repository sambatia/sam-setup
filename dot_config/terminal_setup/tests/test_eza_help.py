"""Exercise lhelp with real Zsh processes and disposable pseudo-terminals."""

import errno
import fcntl
import os
from pathlib import Path
import pty
import re
import select
import shlex
import struct
import subprocess
import sys
import tempfile
import termios
import time
import unicodedata
import unittest


SOURCE_ROOT = Path(os.environ.get("TERMINAL_SETUP_SOURCE_ROOT", Path(__file__).resolve().parents[3]))
ALIAS_FILE = Path(os.environ.get("EZA_ALIAS_FILE", SOURCE_ROOT / "dot_config/zsh/aliases/eza.zsh"))
ALIASES = "ls l ll la lla lfull lt ltt ltl ld ltd lg lgt lrepo lnew lold lsize ldu lext lf".split()
ANSI = re.compile(r"\x1b\[[0-9;]*m")


def invoke(arguments=(), *, width=100, terminal=False, extra_env=None, before="", after=""):
    locale = "en_US.UTF-8" if sys.platform == "darwin" else "C.UTF-8"
    env = dict(os.environ, TERM="xterm-256color", LC_ALL=locale, COLUMNS=str(width))
    env.pop("NO_COLOR", None)
    env.update(extra_env or {})
    script = 'source "$1" || exit; shift; ' + before + '\nlhelp "$@"\n' + after
    command = ["/bin/zsh", "-fic", script, "zsh", str(ALIAS_FILE), *arguments]
    if not terminal:
        result = subprocess.run(
            command,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            env=env,
            timeout=10,
            start_new_session=True,
        )
        return result.returncode, result.stdout, result.stderr
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 60, width, 0, 0))
    process = subprocess.Popen(command, stdin=slave, stdout=slave, stderr=slave, env=env, start_new_session=True)
    os.close(slave)
    chunks = []
    deadline = time.monotonic() + 10
    try:
        while time.monotonic() < deadline:
            if select.select([master], [], [], 0.1)[0]:
                try:
                    chunk = os.read(master, 65536)
                except OSError as error:
                    if error.errno == errno.EIO:
                        break
                    raise
                if not chunk:
                    break
                chunks.append(chunk)
        if process.poll() is None:
            process.wait(timeout=1)
    finally:
        if process.poll() is None:
            process.kill()
        process.wait()
        os.close(master)
    return process.returncode, b"".join(chunks).decode().replace("\r\n", "\n"), ""


def cells(text):
    return sum(0 if unicodedata.combining(char) else 2 if unicodedata.east_asian_width(char) in "WF" else 1 for char in text)


class EzaHelpTests(unittest.TestCase):
    def output(self, *args, **kwargs):
        rc, out, err = invoke(*args, **kwargs)
        self.assertEqual(rc, 0, out + err)
        self.assertEqual(err, "")
        return out

    def test_all_twenty_alias_rows_once(self):
        text = self.output(["--plain"])
        for name in ALIASES:
            self.assertEqual(len(re.findall(r"^  " + name + r"(?:\s|$)", text, re.M)), 1, name)
        for title in ["Everyday File Listing", "Directory Trees", "Git & Development", "Sorting & Analysis"]:
            self.assertIn(title, text)

    def test_redirected_output_is_plain_ascii(self):
        text = self.output()
        self.assertNotIn("\x1b", text)
        self.assertTrue(text.isascii())

    def test_terminal_has_color_and_icons(self):
        text = self.output(terminal=True)
        self.assertIn("\x1b[38;2;", text)
        self.assertIn("\uf07c", text)
        for icon in ["📁", "🌳", "🔀", "📊"]:
            self.assertIn(icon, text)
        self.assertNotIn("\x1b[2J", text)

    def test_plain_suppresses_all_decorations_in_terminal(self):
        text = self.output(["--plain"], terminal=True)
        self.assertNotIn("\x1b", text)
        self.assertTrue(text.isascii())

    def test_no_color_is_respected_even_when_empty(self):
        for value in ["1", ""]:
            with self.subTest(value=value):
                text = self.output(terminal=True, extra_env={"NO_COLOR": value})
                self.assertNotIn("\x1b", text)

    def test_dumb_terminal_is_plain(self):
        text = self.output(terminal=True, extra_env={"TERM": "dumb"})
        self.assertNotIn("\x1b", text)
        self.assertTrue(text.isascii())

    def test_non_unicode_locale_has_ascii_fallback(self):
        text = self.output(terminal=True, extra_env={"LC_ALL": "C"})
        self.assertTrue(ANSI.sub("", text).isascii())

    def test_widths_do_not_overflow(self):
        for width in [16, 24, 40, 60, 80, 100, 120]:
            for terminal in [False, True]:
                with self.subTest(width=width, terminal=terminal):
                    text = ANSI.sub("", self.output(width=width, terminal=terminal))
                    for line in text.splitlines():
                        self.assertLessEqual(cells(line), width, repr(line))

    def test_wide_examples_share_one_column(self):
        text = ANSI.sub("", self.output(terminal=True, width=100))
        positions = []
        for line in text.splitlines():
            match = re.match(r"^  (ls|l|ll|la|lla|lfull|ld|lf|lt|ltt|ltl|ltd|lg|lgt|lrepo|lnew|lold|lsize|ldu|lext)\s+", line)
            if match:
                name = match.group(1)
                positions.append(line.rfind(name + " "))
        self.assertEqual(len(positions), 20)
        self.assertEqual(len(set(positions)), 1, positions)

    def test_help_and_usage_error(self):
        text = self.output(["--help"])
        self.assertIn("Usage: lhelp", text)
        self.assertIn("--plain", text)
        self.assertIn("NO_COLOR", text)
        rc, out, err = invoke(["--bogus"])
        self.assertEqual(rc, 2)
        self.assertEqual(out, "")
        self.assertIn("Usage: lhelp", err)
        self.assertNotIn("\x1b", err)

    def test_corrected_sort_and_git_descriptions(self):
        text = self.output(["--plain"])
        self.assertRegex(text, r"(?m)^  lnew\s+Newest modified first")
        self.assertRegex(text, r"(?m)^  lold\s+Oldest modified first")
        self.assertRegex(text, r"(?m)^  lsize\s+Largest first")
        self.assertRegex(text, r"(?m)^  ldu\s+Recursive sizes; largest first")
        self.assertRegex(text, r"(?m)^  lrepo\s+Repository status; includes other entries")
        self.assertRegex(text, r"(?m)^  lgt\s+Tree, depth 3; respects .gitignore")

    def test_live_alias_changes_update_description(self):
        text = self.output(["--plain"], before="alias lnew='eza --long --sort=modified'")
        self.assertRegex(text, r"(?m)^  lnew\s+Oldest modified first")
        self.assertNotRegex(text, r"(?m)^  lnew\s+Newest")

    def test_array_changes_are_reflected(self):
        text = self.output(["--plain"], before="EZA_BASE+=(--all)")
        self.assertRegex(text, r"(?m)^  ls\s+Compact listing; hidden")

    def test_literal_array_references_are_not_expanded(self):
        definitions = [
            "eza '${EZA_BASE[@]}' --oneline",
            r'eza \${EZA_BASE[@]} --oneline',
            r'eza "\${EZA_BASE[@]}" --oneline',
        ]
        for definition in definitions:
            with self.subTest(definition=definition):
                before = "EZA_BASE+=(--all); alias ls=" + shlex.quote(definition)
                text = self.output(["--plain"], before=before)
                self.assertRegex(text, r"(?m)^  ls\s+Custom options; inspect definition")

    def test_missing_alias_is_explicit(self):
        text = self.output(["--plain"], before="unalias lf")
        self.assertRegex(text, r"(?m)^  lf\s+Not defined in this shell")
        self.assertIn("19 live aliases", text)

    def test_custom_alias_is_not_misdescribed(self):
        text = self.output(["--plain"], before="alias lg=lazygit")
        self.assertRegex(text, r"(?m)^  lg\s+Custom alias; inspect definition")

    def test_alias_expansion_never_executes_commands(self):
        with tempfile.TemporaryDirectory(prefix="lhelp-safety-") as tmp:
            marker = Path(tmp) / "should-not-exist"
            definition = 'eza $(touch ' + shlex.quote(str(marker)) + ')'
            text = self.output(["--plain"], before="alias ll=" + shlex.quote(definition))
            self.assertFalse(marker.exists())
            self.assertRegex(text, r"(?m)^  ll\s+Custom options; inspect definition")

    def test_invocation_preserves_aliases_arrays_options_and_path(self):
        before = 'saved_aliases=$(alias); saved_base=${(j:|:)EZA_BASE}; saved_long=${(j:|:)EZA_LONG}; saved_path=$PATH; saved_options=$(setopt)'
        after = '''[[ $saved_aliases == "$(alias)" && $saved_base == ${(j:|:)EZA_BASE} &&
          $saved_long == ${(j:|:)EZA_LONG} && $saved_path == $PATH && $saved_options == "$(setopt)" ]] || exit 90'''
        self.output(["--plain"], before=before, after=after)

    def test_repeat_source_is_silent_and_idempotent(self):
        before = 'saved=$(functions lhelp); source ' + shlex.quote(str(ALIAS_FILE)) + '; [[ $saved == "$(functions lhelp)" ]] || exit 91'
        self.output(["--plain"], before=before)


if __name__ == "__main__":
    unittest.main()
