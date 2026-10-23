# Changelog

All notable changes to sam-setup. Format: [Keep a Changelog](https://keepachangelog.com).
The install one-liner pins to a release tag — bump it here when you cut one.

## [v0.2.1] - 2026-10-23

### Added
- **Exhaustive Toolset Manifest**: Documented all 120+ tools across Homebrew, mise, uv, and npm in README.
- **TUI & File Management Stack**: Added `btop` system monitor to `Brewfile`, bundled all 12 Yazi plugins (`yatline`, `git`, `full-border`, `smart-filter`, `smart-enter`, `jump-to-char`, `toggle-pane`, `augment-command`, `clipboard-sync`, `pref-by-location`), and added full documentation for `superfile` (`spf`) and `tuios` workspace hub.
- **AI Coding Agent Ecosystem**: Deep documentation and health verification for Anthropic Claude Code (cask), OpenAI Codex CLI (mise), Google Antigravity CLI (`agy` v1.4.6), and `llm` stream pipelines.
- **LazyVim Complete Suite**: Exhaustive catalog of all 30+ Neovim plugins (Snacks.nvim, CodeCompanion, blink.cmp, telescope, harpoon, trouble, flash, which-key, gitsigns, tokyonight, render-markdown, kulala, csvview, oil.nvim).
- **Expanded Health Doctor**: Upgraded `sam-setup-check` from 44 to 53 comprehensive automated assertions.

## [v0.2.0] - 2026-10-23

### Added
- One-line `bootstrap.sh`: upfront consent gate, macOS version guard, Rosetta,
  Xcode CLT wait (bounded), Homebrew + `brew shellenv`, chezmoi handoff.
- `Brewfile` (curated workstation baseline, App-Store + VS Code entries stripped).
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
