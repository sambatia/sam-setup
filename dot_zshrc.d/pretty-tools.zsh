# ~/.zshrc.d/pretty-tools.zsh — added 2026-07-03 (terminal beauty phase 7).
# Small, guarded quality-of-life aliases for tools that are already installed.
# Every block no-ops if its tool is missing, so this file is safe to keep
# even after tool changes. Loaded from the module list in ~/.zshrc.

# bat: explicit viewers (cat='bat' already exists in .zshrc; pcat = plain cat)
if command -v bat >/dev/null 2>&1; then
  alias view='bat --paging=always'
  alias batp='bat --plain'
fi

# dust: readable disk-usage trees (du stays untouched for scripts)
if command -v dust >/dev/null 2>&1; then
  alias du1='dust -d 1'
  alias du2='dust -d 2'
fi

# duf: pretty df (df stays untouched)
if command -v duf >/dev/null 2>&1; then
  alias dfp='duf'
fi

# glow: quick markdown preview in the terminal
if command -v glow >/dev/null 2>&1; then
  alias md='glow --pager'
fi

# pathcheck: numbered PATH listing, flags duplicates — handy after the
# ownership work in the stabilization project
pathcheck() {
  print -l ${(s.:.)PATH} | nl -ba
  local dupes
  dupes=$(print -l ${(s.:.)PATH} | sort | uniq -d)
  [[ -n "$dupes" ]] && { echo "\nduplicates:"; echo "$dupes" } || echo "\nno duplicate PATH entries"
}

# Explicit Rich viewers. Keep existing commands and global pagers unchanged.
# Dracula is a supported Pygments syntax theme; prose uses Mocha's text color.
if command -v rich >/dev/null 2>&1; then
  rshow() { command rich --theme dracula --style '#cdd6f4' "$@"; }
  rjson() { rshow --json "$@"; }
  rcsv() { rshow --csv "$@"; }
  rmd() { rshow --markdown "$@"; }
fi

# Run the read-only viewer in Textual's own uv environment, never system Python.
tview() {
  local tools_dir
  tools_dir="$(command uv tool dir 2>/dev/null)" || {
    print -u2 -r -- 'tview: uv is unavailable.'
    return 1
  }
  if [[ ! -x "$tools_dir/textual-dev/bin/python" ]]; then
    print -u2 -r -- 'tview: Textual tooling is missing; install textual-dev with uv.'
    return 1
  fi
  "$tools_dir/textual-dev/bin/python" \
    "$HOME/.config/terminal_setup/textual-viewer.py" "$@"
}
