# sam-setup

> **One line, walk away, come back to a Mac that works like mine** — an identical, zero-friction replica of my modern terminal environment: Ghostty, Neovim (LazyVim), Herdr multiplexer, Tmux, Starship, Atuin, modern CLI utilities, data wranglers, AI coding agents, and polyglot runtimes. Your identity stays yours; none of my secrets or private history come along.

[![Release](https://img.shields.io/badge/release-v0.2.0-blue.svg)](https://github.com/sambatia/sam-setup/releases)
[![Shell](https://img.shields.io/badge/bash-5.x-1f425f)]()
[![Platform](https://img.shields.io/badge/macOS-Tahoe%20%7C%20Sonoma%20%7C%20Ventura-black)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()
[![CI](https://github.com/sambatia/sam-setup/actions/workflows/ci.yml/badge.svg)](https://github.com/sambatia/sam-setup/actions)

---

## ⚡ Quick Install

Open Terminal on your Mac, paste this command, and press Enter:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sambatia/sam-setup/main/bootstrap.sh)"
```

### Installation Profiles
```bash
# Full Installation (Default: Complete AI engineering, Cloud/K8s, DB & Terminal stack)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sambatia/sam-setup/main/bootstrap.sh)"

# Core Profile (Lightweight: Terminal, Ghostty, LazyVim, Multiplexers, & CLIs only)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sambatia/sam-setup/main/bootstrap.sh)" -- --core
```

### What Happens During Bootstrap:
1. **Upfront Consent Gate**: Displays a clear summary of what will be installed and asks for confirmation (`[y/N]`).
2. **Defensive Pre-Flight Guards**: Verifies >= 10 GB free disk space, alerts if on low battery (< 30%), and caches `sudo` credentials in the background so GUI cask downloads never hang.
3. **Identity Setup**: Chezmoi prompts for your **Name** and **Git Email** (used exclusively to configure your private `.gitconfig`).
4. **Safety Backup**: Existing configs (`~/.zshrc`, `~/.tmux.conf`, `~/.config/nvim`, etc.) are automatically backed up to `.bak-<timestamp>` (revertible anytime with `sam-setup-restore`).
5. **Curated Software Installation**: Installs the Homebrew toolset, Ghostty, JetBrains Mono Nerd Font, and modern CLI tools.
6. **Runtimes & Agents**: Installs Node.js LTS, pnpm, Python runtimes, Claude Code, and isolated Python tools via `uv`.
7. **Editor & Multiplexers**: Headlessly synchronizes LazyVim plugins and clones tmux TPM plugins.
8. **SSH Key Generation**: Generates a fresh `ed25519` SSH key **only if you don't already have one**, and prints the public key ready for GitHub.
9. **Automated Verification**: Runs `sam-setup-check` (44 assertions) to guarantee your environment is green and healthy.
10. **Ghostty Launch**: Offers to immediately launch your new GPU-accelerated Ghostty terminal.

---

## 🧰 What You Get

### 🖥 Terminal & Multiplexing
* **[Ghostty](https://ghostty.org)**: GPU-accelerated terminal styled with **Catppuccin Mocha**, 90% opacity with background blur, JetBrains Mono Nerd Font Mono, and native macOS Tahoe tabs.
* **[Herdr](https://github.com/danbuhler/herdr)**: Agentic terminal multiplexer configured with seamless Neovim smart-splits navigation (`Ctrl+h/j/k/l`) and pane topic sync.
* **[Tmux](https://github.com/tmux/tmux)**: Configured with `Ctrl-A` prefix, true-color RGB undercurl pass-through, mouse toggle (`prefix + m`), session persistence (resurrect/continuum), and TPM plugins.
* **[Workmux](https://github.com/raine/workmux)**: Automated Git worktree isolation for parallel agent workflows.

### 🐚 Shell & Navigation
* **Zsh + [Starship](https://starship.rs)**: Two-line prompt with execution duration, Git branch/status, language indicators, Catppuccin palette, and a 250ms latency ceiling.
* **[Atuin](https://atuin.sh)**: Daemon-backed shell history search with local socket and fuzzy AI search (`Ctrl-r` / Up Arrow).
* **[Zoxide](https://github.com/ajeetdsouza/zoxide)**: Smarter `cd` command that learns your habits (`z <dir>`).
* **[Yazi](https://yazi-rs.github.io)** & **[Superfile (`spf`)](https://superfile.netlify.app)**: Lightning-fast terminal file managers with graphic image previews.
* **Modern CLI Replacements**: `eza` (modern `ls`), `bat` (modern `cat` with syntax highlighting), `ripgrep` (`rg`), `fd` (`find`), `dust` (`du`), `procs` (`ps`), `btop` (`top`), `lazygit` (`lg`), `gping` (`ping`), `xh` (`curl`).

### 🤖 AI Engineering & CLI Assistants
* **[Claude Code](https://claude.ai/code)**: Anthropic's agentic engineering assistant CLI.
* **Codex CLI**: OpenAI terminal coding agent.
* **[llm](https://llm.datasette.io)**: Simon Willison's CLI LLM pipe filter with local Ollama plugin pre-configured (`cat log.txt | llm "explain this failure"`).

### 📊 Data Processing, Databases & APIs
* **[jqp](https://github.com/noahgorstein/jqp)**: Interactive TUI playground for experimenting with and refining `jq` queries on live JSON streams.
* **[VisiData (`vd`)](https://www.visidata.org/)**: The ultimate terminal spreadsheet and data wrangler for CSV, TSV, JSON, SQLite, and Parquet.
* **[LazySQL](https://github.com/jorgerojas26/lazysql)**: Keyboard-driven TUI database client for PostgreSQL, SQLite, and MySQL with safe read-only posture.
* **[mitmproxy](https://mitmproxy.org/)**: Interactive TLS/HTTP interception proxy, CLI debugger (`mitmproxy`), and web UI (`mitmweb`).
* **[Posting](https://posting.sh)**: TUI REST client with autocompletion and environment switching.
* **[Kondo](https://github.com/tbillington/kondo)**: Blazingly fast build artifact cleaner to reclaim disk space from stale `node_modules`, `target`, and `venv` directories (`kondo -n`).

### 💻 Editor (Neovim / LazyVim)
* Full **[LazyVim](https://www.lazyvim.org)** IDE stack in `~/.config/nvim`.
* Auto-configured LSPs, Treesitter parsers, Markdown renderers, Git integration via Gitsigns, and fuzzy finding via Telescope/Snacks.

### ⚙️ Polyglot Runtimes
* **[mise](https://mise.jdx.dev)**: Fast polyglot version manager pre-configured with Node.js LTS, pnpm, Codex CLI, TypeScript, and developer CLIs.
* **[uv](https://docs.astral.sh/uv/)**: Lightning-fast Python package manager managing isolated CLI tools (`basedpyright`, `gita`, `mlx-lm`, `specify-cli`, etc.).

---

## 🛠 Management & Productivity Commands

| Command | Purpose |
| :--- | :--- |
| **`sam-setup-help`** | **Built-in Cheatsheet**: Displays keyboard shortcuts, splits, navigation keys, and aliases anytime. |
| **`sam-setup-check`** | **Health Check**: Runs 44 automated diagnostic assertions across your packages, runtimes, and shell syntax. |
| **`sam-setup-doctor`** | **Self-Healing Doctor**: Automatically reshimms mise, repairs missing TPM plugins, and refreshes integrations. |
| **`update-all`** (or `sam-setup-update`) | **One-Command Updater**: Upgrades Homebrew, mise runtimes, global Node CLIs, uv tools, Neovim plugins, Tmux plugins, and pulls dotfiles. |
| **`sam-setup-restore`** | **Rollback**: Reverts your dotfiles back to your pre-installation `.bak-<timestamp>` state. |

---

## 🔒 Security & Privacy (What Stays Yours)

* **Zero Credentials Shared**: None of Sam's API keys, tokens, SSH keys, or Keychain items are included.
* **Your Own Git Identity**: Git commits use the name and email you provide during the setup prompt.
* **Private Secrets**: Put your own API keys in macOS Keychain and load them in `~/.zshrc.local`.
* **Zero Telemetry**: No tracking or phone-home mechanisms.

---

## 🎨 Local Customization

Layer your own personal tweaks without conflicting with upstream updates:
* `~/.zshrc.local` — Put custom aliases, environment variables, or PATH additions here (sourced automatically if present).
* `~/.config/ghostty/config.local` — Override terminal fonts, window dimensions, or keybindings.

Pull future updates from this repo at any time:
```sh
chezmoi update
```

---

## ⏪ Rollback & Uninstall

If you ever wish to restore your original configurations:
```sh
sam-setup-restore
```
Your backed-up dotfiles from `.bak-<timestamp>` will be restored to their original locations.

---

## 📄 License

[MIT](LICENSE) — Copyright (c) 2026 Sameh Abdalla.
