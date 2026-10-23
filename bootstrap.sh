#!/usr/bin/env bash
#
# bootstrap.sh — zero-friction, one-line workstation setup for macOS.
#
# Usage:
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/sambatia/sam-setup/main/bootstrap.sh)"
#
# Installs:
#   1. Xcode Command Line Tools + Homebrew (if missing)
#   2. Chezmoi dotfiles engine
#   3. Curated Brewfile (modern CLI tools, Ghostty, JetBrains Mono Nerd Font, casks)
#   4. Language runtimes via mise (Node.js LTS, pnpm, Python tools via uv)
#   5. Pre-configured Neovim LazyVim stack & tmux plugins (TPM)
#   6. Herdr multi-agent multiplexer integration
#   7. Fresh SSH key generation (only if none exists)
#
# Pre-existing configurations are automatically backed up to <path>.bak-<timestamp>.
# Safe, idempotent, and reversible via: sam-setup-restore

if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -euo pipefail

REPO="${SAM_SETUP_REPO:-sambatia/sam-setup}"
PROFILE="${SAM_SETUP_PROFILE:-full}"
for a in "${@:-}"; do
  case "$a" in
    --core)      PROFILE="core" ;;
    --full)      PROFILE="full" ;;
    --yes|-y)    export SAM_SETUP_YES=1 ;;
    -h|--help)
      cat <<'EOF'
bootstrap.sh — zero-friction, one-line workstation setup for macOS.

Usage:
  bootstrap.sh [options]

Options:
  --full       Install full workstation stack (default: cloud, k8s, AI agents, databases, dev runtimes)
  --core       Install core terminal stack only (shell, Ghostty, LazyVim, multiplexers, modern CLIs)
  --yes, -y    Skip upfront confirmation prompt
  --help, -h   Show this help
EOF
      exit 0
      ;;
  esac
done
export SAM_SETUP_PROFILE="$PROFILE"

if [ -t 1 ]; then
  C_B=$'\033[1m'; C_G=$'\033[32m'; C_Y=$'\033[33m'; C_M=$'\033[35m'; C_C=$'\033[36m'; C_R=$'\033[31m'; C_D=$'\033[2m'; C_RST=$'\033[0m'
else
  C_B=""; C_G=""; C_Y=""; C_M=""; C_C=""; C_R=""; C_D=""; C_RST=""
fi

say()  { printf '%s▸%s %s\n' "$C_M" "$C_RST" "$1"; }
step() { printf '\n%s==>%s %s%s%s\n' "$C_C" "$C_RST" "$C_B" "$1" "$C_RST"; }
ok()   { printf '%s✓%s %s\n' "$C_G" "$C_RST" "$1"; }
warn() { printf '%s!%s %s\n' "$C_Y" "$C_RST" "$1"; }
die()  { printf '%s✗%s %s\n' "$C_R" "$C_RST" "$1" >&2; exit 1; }

# ── Upfront Consent ──────────────────────────────────────────────────────────
consent() {
  [ "${SAM_SETUP_YES:-0}" = "1" ] && return 0
  cat <<'EOF'
sam-setup will configure a modern, AI-engineering macOS terminal environment:
  · Xcode Command Line Tools + Homebrew (if missing)
  · Modern CLI tools: eza, bat, ripgrep, zoxide, atuin, fzf, yazi, btop, just, etc.
  · Ghostty terminal + JetBrains Mono Nerd Font
  · Neovim (LazyVim distribution) + tmux (Ctrl-A prefix, TPM) + Herdr multiplexer
  · Node.js LTS, pnpm, and Python runtimes via mise & uv
  · Generate a fresh ed25519 SSH key (ONLY if you have none)
  · Back up any pre-existing configs to ~/.config/*.bak-<timestamp>

Your identity stays yours. None of Sam's personal credentials or secrets are copied.
EOF
  printf 'Proceed with installation? [y/N] '
  read -r reply
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *) die "Installation aborted. Nothing was modified." ;;
  esac
}

# ── Compatibility Checks ─────────────────────────────────────────────────────
MIN_MACOS=13
MIN_DISK_GB=10

ensure_macos() {
  [ "$(uname -s)" = "Darwin" ] || die "This setup script targets macOS only."
  local major
  major="$(sw_vers -productVersion 2>/dev/null | cut -d. -f1)"
  case "$major" in
    ''|*[!0-9]*) say "Could not determine exact macOS version — continuing." ;;
    *) [ "$major" -ge "$MIN_MACOS" ] || die "macOS $major is below minimum required (${MIN_MACOS}). Please update first." ;;
  esac
}

ensure_disk_space() {
  local free_gb
  free_gb="$(df -g /System/Volumes/Data 2>/dev/null | awk 'NR==2 {print $4}')" || free_gb="$(df -g / 2>/dev/null | awk 'NR==2 {print $4}')" || return 0
  case "$free_gb" in
    ''|*[!0-9]*) return 0 ;;
    *)
      if [ "$free_gb" -lt "$MIN_DISK_GB" ]; then
        die "Insufficient disk space: ${free_gb} GB available. At least ${MIN_DISK_GB} GB is required for tools and runtimes."
      fi
      ok "Disk space: ${free_gb} GB available"
      ;;
  esac
}

ensure_power() {
  command -v pmset >/dev/null 2>&1 || return 0
  if pmset -g batt 2>/dev/null | grep -q "Battery Power"; then
    local pct
    pct="$(pmset -g batt 2>/dev/null | grep -o '[0-9]\+%' | head -1 | tr -d '%')"
    case "$pct" in
      ''|*[!0-9]*) ;;
      *)
        if [ "$pct" -lt 30 ]; then
          warn "Running on battery (${pct}%). Please connect AC power to prevent Mac sleep during setup."
        fi
        ;;
    esac
  fi
}

keep_sudo_alive() {
  if sudo -n true 2>/dev/null; then
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    local sudo_pid=$!
    trap 'kill '"$sudo_pid"' 2>/dev/null || true' EXIT
  fi
}

ensure_rosetta() {
  [ "$(uname -m)" = "arm64" ] || return 0
  /usr/bin/pgrep -q oahd 2>/dev/null && return 0
  say "Installing Rosetta 2 for any Intel-only binaries…"
  softwareupdate --install-rosetta --agree-to-license >/dev/null 2>&1 || warn "Rosetta install skipped."
}

# ── Foundational Prerequisites ───────────────────────────────────────────────
ensure_clt() {
  xcode-select -p >/dev/null 2>&1 && return 0
  say "Installing Xcode Command Line Tools (a system prompt may appear — click Install)…"
  xcode-select --install >/dev/null 2>&1 || true
  local tries=0 max=240
  until xcode-select -p >/dev/null 2>&1; do
    tries=$((tries + 1))
    [ "$tries" -ge "$max" ] && die "Command Line Tools installation timed out after 20 minutes."
    sleep 5
  done
  ok "Xcode Command Line Tools installed"
}

ensure_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    say "Installing Homebrew package manager…"
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
      || die "Homebrew installation failed."
  fi
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$p" ] && eval "$("$p" shellenv)" && break
  done
  command -v brew >/dev/null 2>&1 || die "Homebrew not found on PATH after install."
  ok "Homebrew ready"
}

# ── Main Lifecycle ───────────────────────────────────────────────────────────
main() {
  printf '\n%s🚀 Starting Workstation Bootstrap%s\n\n' "$C_B" "$C_RST"
  ensure_macos
  consent
  ensure_disk_space
  ensure_power
  keep_sudo_alive
  ensure_rosetta
  ensure_clt
  ensure_brew

  # Install Chezmoi
  step "1/6: Installing dotfiles management engine (chezmoi)"
  if ! command -v chezmoi >/dev/null 2>&1; then
    brew install chezmoi || die "Failed to install chezmoi."
  fi
  ok "chezmoi installed"

  # Apply Dotfiles and Packages
  step "2/6: Applying dotfiles and packages (Homebrew Bundle)"
  say "Chezmoi will now prompt for your name and email (used for git commits)."
  chezmoi init --apply "$REPO" || die "chezmoi apply failed."
  ok "Dotfiles applied and packages installed"

  # Setup Language Runtimes & Node Globals
  step "3/6: Initializing runtimes and global tools via mise"
  if command -v mise >/dev/null 2>&1; then
    say "Installing Node.js LTS and pnpm…"
    mise install --yes || warn "mise install finished with warnings."
    say "Seeding developer CLI utilities…"
    mise run node-globals || warn "node-globals task finished with warnings."
    ok "mise runtimes and CLI tools configured"
  else
    warn "mise not found on PATH; skipping runtime installation."
  fi

  # Setup Neovim LazyVim
  step "4/6: Initializing Neovim LazyVim plugins"
  if command -v nvim >/dev/null 2>&1; then
    say "Pre-syncing plugins headlessly…"
    nvim --headless '+Lazy! sync' +qa >/dev/null 2>&1 || true
    ok "Neovim plugins synchronized"
  fi

  # Setup Tmux TPM & Herdr
  step "5/6: Configuring terminal multiplexers (Tmux & Herdr)"
  if [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
    "$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null 2>&1 || true
    ok "Tmux plugins installed"
  fi
  if command -v herdr >/dev/null 2>&1; then
    for integ in claude codex omp cursor opencode; do
      herdr integration install "$integ" >/dev/null 2>&1 || true
    done
    ok "Herdr integrations registered"
  fi

  # Post-Install Verification
  step "6/6: Verifying workstation health"
  if [ -x "$HOME/.local/bin/sam-setup-check" ]; then
    "$HOME/.local/bin/sam-setup-check" || warn "Some checks reported warnings (review above)."
  else
    ok "Installation complete."
  fi

  printf '\n%s🎉 Workstation replication complete!%s\n\n' "$C_B" "$C_RST"
  printf 'Next steps to start using your new environment:\n'
  printf '  1. %sRestart your terminal%s (or open Ghostty: /Applications/Ghostty.app)\n' "$C_B" "$C_RST"
  printf '  2. If an SSH key was generated, copy your public key to GitHub:\n'
  printf '     %sgh ssh-key add ~/.ssh/id_ed25519.pub%s\n' "$C_C" "$C_RST"
  printf '  3. Sign in to your AI coding agents:\n'
  printf '     %sclaude login%s\n' "$C_C" "$C_RST"
  printf '     %scodex%s\n' "$C_C" "$C_RST"
  printf '  4. View your full terminal cheatsheet anytime:\n'
  printf '     %ssam-setup-help%s\n' "$C_C" "$C_RST"
  printf '  5. To update your entire system in the future, simply run:\n'
  printf '     %supdate-all%s\n\n' "$C_C" "$C_RST"
  printf 'To undo or rollback these changes at any time, run: %ssam-setup-restore%s\n\n' "$C_D" "$C_RST"

  if [ -d "/Applications/Ghostty.app" ] && [ -t 0 ] && [ "${SAM_SETUP_YES:-0}" != "1" ]; then
    printf 'Launch Ghostty now to experience your new terminal? [Y/n] '
    read -r launch_ghostty
    case "$launch_ghostty" in
      n|N|no|NO) ;;
      *) open -a Ghostty ;;
    esac
  fi
}

if [ "${BASH_SOURCE[0]:-$0}" = "${0}" ]; then main "$@"; fi
