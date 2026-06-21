#!/usr/bin/env bash
#
# bootstrap.sh — one-line entrypoint for "your Mac = Sam's Mac".
#
# Fetched by the pinned-tag one-liner in README.md. Installs Homebrew + chezmoi,
# then hands off to `chezmoi init --apply` which prompts for identity, installs
# the Brewfile, and lays down the dotfiles.
#
# SKELETON (T1/T3). Hardening still pending — tracked in the eng-review tasks:
#   T2  — xcode-select --install + wait; `eval brew shellenv` for Intel vs ARM
#   T15 — re-exec into bash (this file is fetched with `sh`) before bash-isms
#   T7  — destructive defaults (shell change, global gitconfig) behind opt-in
#   T8  — a `restore` companion for rollback
#
set -eu

REPO="${SAM_SETUP_REPO:-sambatia/sam-setup}"

say() { printf '\033[1;35m▸\033[0m %s\n' "$1"; }
die() { printf '\033[1;31m✗\033[0m %s\n' "$1" >&2; exit 1; }

# ── Upfront consent gate (Issue 4): one [y/N], then unattended ───────────────
consent() {
  # Non-interactive runs (CI smoke) pre-approve via SAM_SETUP_YES=1.
  [ "${SAM_SETUP_YES:-0}" = "1" ] && return 0
  cat <<'EOF'
star-setup will, on THIS Mac:
  · install Homebrew (if missing) + the Brewfile tools/apps
  · generate an SSH key if you have none
  · back up (never overwrite) then replace these configs:
      ~/.zshrc  ~/.config/nvim  ~/.config/mise  ~/.config/starship.toml  ~/.tmux.conf
Your name/email are asked next. No secrets of Sam's are installed.
EOF
  printf 'proceed? [y/N] '
  read -r reply
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *) die "aborted — nothing was changed." ;;
  esac
}

main() {
  consent

  if ! command -v brew >/dev/null 2>&1; then
    say "Homebrew missing — installing (official installer)…"
    # T2: precede with xcode-select --install + wait, and source brew shellenv
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
      || die "Homebrew install failed."
    for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      [ -x "$p" ] && eval "$("$p" shellenv)" && break
    done
  fi
  command -v brew >/dev/null 2>&1 || die "brew not on PATH after install (T2: shellenv)."

  command -v chezmoi >/dev/null 2>&1 || { say "Installing chezmoi…"; brew install chezmoi || die "chezmoi install failed."; }

  say "Applying the setup (chezmoi will prompt for name/email)…"
  chezmoi init --apply "$REPO" || die "chezmoi init failed."

  printf '\033[1;32m✓ done.\033[0m If a new SSH key was generated, add it to GitHub:\n'
  printf '    gh ssh-key add ~/.ssh/id_ed25519.pub   # or paste it at github.com/settings/keys\n'
}

main "$@"
