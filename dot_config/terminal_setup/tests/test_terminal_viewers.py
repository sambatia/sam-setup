"""Behavior checks for the explicit Rich helpers and read-only Textual viewer."""

import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from textual.widgets import Input, TextArea


SETUP_ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = SETUP_ROOT.parents[1]
VIEWER_PATH = SETUP_ROOT / "textual-viewer.py"


def load_viewer():
    spec = importlib.util.spec_from_file_location("terminal_viewer", VIEWER_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FileSafetyTests(unittest.TestCase):
    def setUp(self):
        self.viewer = load_viewer()
        self.directory = tempfile.TemporaryDirectory(prefix="terminal-viewer-")
        self.addCleanup(self.directory.cleanup)
        self.file = Path(self.directory.name) / "a file.txt"

    def test_reads_utf8_without_modifying_the_file(self):
        self.file.write_text("café\nhello\n", encoding="utf-8")
        before = self.file.read_bytes()
        self.assertEqual(self.viewer.read_text(self.file), "café\nhello\n")
        self.assertEqual(self.file.read_bytes(), before)

    def test_rejects_binary_and_oversized_input(self):
        self.file.write_bytes(b"binary\x00data")
        with self.assertRaises(ValueError):
            self.viewer.read_text(self.file)
        with self.file.open("wb") as stream:
            stream.truncate(8 * 1024 * 1024 + 1)
        with self.assertRaises(ValueError):
            self.viewer.read_text(self.file)

    def test_missing_file_and_non_terminal_invocation_fail_cleanly(self):
        missing = self.file.with_name("missing.txt")
        for file in [missing, self.file]:
            if file == self.file:
                file.write_text("hello", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(VIEWER_PATH), str(file)],
                capture_output=True, text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("Traceback", result.stderr)
            self.assertNotIn("\x1b", result.stdout)


class ViewerInteractionTests(unittest.IsolatedAsyncioTestCase):
    async def test_search_wrap_and_read_only_navigation(self):
        viewer = load_viewer()
        text = "first line\nneedle here\nlast needle\n"
        app = viewer.FileViewer(Path("fixture.txt"), text)
        async with app.run_test(size=(100, 28)) as pilot:
            area = app.query_one(TextArea)
            self.assertEqual(app.theme, "catppuccin-mocha")
            self.assertTrue(area.read_only)
            await pilot.press("x")
            self.assertEqual(area.text, text)
            await pilot.press("ctrl+f")
            app.query_one(Input).value = "needle"
            await pilot.press("enter")
            self.assertEqual(area.cursor_location, (1, 0))
            await pilot.press("f3")
            self.assertEqual(area.cursor_location, (2, 5))
            await pilot.press("alt+w")
            self.assertTrue(area.soft_wrap)
            await pilot.press("ctrl+q")


class RichHelperTests(unittest.TestCase):
    def test_rich_helpers_render_files_with_spaces_and_plain_pipes(self):
        fixtures = [
            ("rjson", "data.json", '{"message":"fixture-value"}', "fixture-value"),
            ("rcsv", "data.csv", "name,value\nfixture-value,42\n", "42"),
            ("rmd", "data.md", "# fixture-value\n", "fixture-value"),
            ("rshow", "data.txt", "fixture-value\n", "fixture-value"),
        ]
        with tempfile.TemporaryDirectory(prefix="rich-viewer-") as directory:
            for command, name, content, expected in fixtures:
                with self.subTest(command=command):
                    file = Path(directory) / ("space " + name)
                    file.write_text(content, encoding="utf-8")
                    result = subprocess.run(
                        ["zsh", "-fc", 'source "$1"; "$2" "$3"', "zsh",
                         str(SOURCE_ROOT / "dot_zshrc.d/pretty-tools.zsh"),
                         command, str(file)],
                        capture_output=True, text=True, env=dict(os.environ, NO_COLOR="1"),
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn(expected, result.stdout)
                    self.assertNotIn("\x1b", result.stdout)


if __name__ == "__main__":
    unittest.main()
