#!/usr/bin/env bash
#
# bootstrap.sh — one-line entrypoint for "your Mac = Sam's Mac".
#
# Fetched by the pinned-tag one-liner in README.md (with `sh`, hence the re-exec
# below). Installs Xcode CLT + Homebrew + chezmoi, then hands off to
# `chezmoi init --apply`, which prompts for identity, backs up existing config,
# installs the Brewfile, lays down dotfiles, and generates an SSH key.
#
# T15: re-exec into bash so the bash-isms below are safe even when fetched via sh.
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -euo pipefail

REPO="${SAM_SETUP_REPO:-sambatia/sam-setup}"

say() { printf '\033[1;35m▸\033[0m %s\n' "$1"; }
die() { printf '\033[1;31m✗\033[0m %s\n' "$1" >&2; exit 1; }

# ── Upfront consent gate (Issue 4): one [y/N], then unattended ───────────────
consent() {
  [ "${SAM_SETUP_YES:-0}" = "1" ] && return 0   # CI/non-interactive pre-approve
  cat <<'EOF'
star-setup will, on THIS Mac:
  · install Xcode Command Line Tools + Homebrew (if missing)
  · install the Brewfile tools/apps
  · generate an SSH key ONLY if you have none
  · back up (never silently overwrite) then replace:
      ~/.zshrc  ~/.gitconfig  ~/.tmux.conf
      ~/.config/nvim  ~/.config/mise  ~/.config/starship.toml
You'll be asked your name + email next. None of Sam's secrets are installed.
EOF
  printf 'proceed? [y/N] '
  read -r reply
  case "$reply" in y|Y|yes|YES) return 0 ;; *) die "aborted — nothing was changed." ;; esac
}

# T2: Xcode Command Line Tools — required by Homebrew. Triggers a GUI dialog on a
# factory Mac; wait for it (it provides git/cc) before continuing.
ensure_clt() {
  xcode-select -p >/dev/null 2>&1 && return 0
  say "Installing Xcode Command Line Tools (a dialog may pop up — click Install)…"
  xcode-select --install >/dev/null 2>&1 || true
  until xcode-select -p >/dev/null 2>&1; do sleep 5; done
  say "Command Line Tools ready."
}

# T2: Homebrew + the all-important shellenv (Apple Silicon vs Intel prefix).
ensure_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    say "Installing Homebrew (official installer)…"
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
      || die "Homebrew install failed."
  fi
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$p" ] && eval "$("$p" shellenv)" && break
  done
  command -v brew >/dev/null 2>&1 || die "brew not on PATH after install (shellenv)."
}

main() {
  consent
  ensure_clt
  ensure_brew
  command -v chezmoi >/dev/null 2>&1 || { say "Installing chezmoi…"; brew install chezmoi || die "chezmoi install failed."; }
  say "Applying the setup (chezmoi will prompt for name/email)…"
  chezmoi init --apply "$REPO" || die "chezmoi init failed."
  printf '\033[1;32m✓ done.\033[0m If a new SSH key was generated, add it to GitHub:\n'
  printf '    gh ssh-key add ~/.ssh/id_ed25519.pub   # or paste it at github.com/settings/keys\n'
  printf 'Undo everything with:  sam-setup-restore\n'
}

# Source-guard: tests source this file and call consent()/ensure_* in isolation.
if [ "${BASH_SOURCE[0]:-$0}" = "${0}" ]; then main "$@"; fi
