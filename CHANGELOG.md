# Changelog

All notable changes to sam-setup. Format: [Keep a Changelog](https://keepachangelog.com).
The install one-liner pins to a release tag — bump it here when you cut one.

## [Unreleased]

### Added
- One-line `bootstrap.sh`: upfront consent gate, macOS version guard, Rosetta,
  Xcode CLT wait (bounded), Homebrew + `brew shellenv`, chezmoi handoff.
- `Brewfile` (generated via `brew bundle dump`; App-Store + VS Code entries stripped).
- chezmoi dotfiles: zsh, zshenv, gitconfig (identity-templated), tmux, Starship,
  Ghostty, plus the ported Neovim + mise configs.
- chezmoi scripts: backup-before-apply (first run), `brew bundle` install
  (re-runs when the Brewfile changes), SSH keygen (guarded), tpm clone.
- `sam-setup-restore` rollback command (installed to `~/.local/bin`).
- Unit tests (consent decline, keygen guard, restore, template render) + CI
  (shellcheck, gitleaks, tests on Ubuntu + macOS).
- `justfile` for lint/test/check/brewfile-refresh/preview/release.

### Security
- No secrets shipped. Identity is prompted on first run; secrets belong in the
  macOS Keychain. The install one-liner pins to a release tag, never `main`.
