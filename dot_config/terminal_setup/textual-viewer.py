"""An explicit, read-only UTF-8 file viewer using the uv-owned Textual runtime."""

import argparse
from pathlib import Path
import sys

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.widgets import Footer, Header, Input, Static, TextArea


MAX_BYTES = 8 * 1024 * 1024


def read_text(file: Path) -> str:
    """Bound memory use and reject binary data before opening a terminal UI."""
    with file.open("rb") as stream:
        data = stream.read(MAX_BYTES + 1)
    if len(data) > MAX_BYTES:
        raise ValueError("file exceeds 8 MiB; use ov or lnav for larger files")
    if b"\x00" in data:
        raise ValueError("binary files are not supported")
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError as error:
        raise ValueError("file must be UTF-8 text") from error


class FileViewer(App):
    """Scroll, search and select text without providing any write operation."""

    CSS = """
    #details { height: 1; padding: 0 1; color: $text-muted; }
    #search { height: 3; margin: 0 1; }
    #content { height: 1fr; margin: 0 1; border: round $primary; }
    """
    BINDINGS = [
        Binding("ctrl+q", "quit", "Quit", priority=True),
        Binding("ctrl+f", "search", "Find", priority=True),
        Binding("f3", "find_next", "Next match", priority=True),
        Binding("alt+w", "toggle_wrap", "Wrap", priority=True),
        Binding("escape", "focus_content", "Read", show=False),
    ]

    def __init__(self, file: Path, text: str):
        super().__init__()
        self.file = file
        self.contents = text
        self.search_term = ""
        self.search_from = 0
        self.theme = "catppuccin-mocha"
        self.title = "File viewer"
        self.sub_title = "Read only"

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static(str(self.file), id="details", markup=False)
        yield Input(placeholder="Find text (case sensitive)", id="search")
        yield TextArea(
            self.contents, read_only=True, show_line_numbers=True,
            soft_wrap=False, id="content",
        )
        yield Footer()

    def on_mount(self) -> None:
        self.action_focus_content()

    def action_focus_content(self) -> None:
        self.query_one(TextArea).focus()

    def action_search(self) -> None:
        self.query_one(Input).focus()

    def on_input_submitted(self, event: Input.Submitted) -> None:
        self.search_term = event.value
        self.search_from = 0
        self.action_find_next()
        self.action_focus_content()

    def action_find_next(self) -> None:
        if not self.search_term:
            self.action_search()
            return
        position = self.contents.find(self.search_term, self.search_from)
        if position < 0:
            position = self.contents.find(self.search_term)
        if position < 0:
            self.notify("No matching text", severity="warning")
            return
        prefix = self.contents[:position]
        row = prefix.count("\n")
        column = position - (prefix.rfind("\n") + 1)
        self.query_one(TextArea).move_cursor((row, column), center=True)
        self.search_from = position + len(self.search_term)

    def action_toggle_wrap(self) -> None:
        area = self.query_one(TextArea)
        area.soft_wrap = not area.soft_wrap


def main() -> int:
    parser = argparse.ArgumentParser(description="Read-only, searchable Textual file viewer")
    parser.add_argument("file", type=Path, help="UTF-8 text file, up to 8 MiB")
    args = parser.parse_args()
    try:
        text = read_text(args.file)
    except (OSError, ValueError) as error:
        print(f"tview: {error}", file=sys.stderr)
        return 1
    if not (sys.stdin.isatty() and sys.stdout.isatty()):
        print("tview: use an interactive terminal; use rshow for piped output", file=sys.stderr)
        return 1
    FileViewer(args.file, text).run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
