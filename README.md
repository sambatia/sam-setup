# sam-setup

> **One line, walk away, come back to a Mac that works like mine** — identical terminal UX, Ghostty, Neovim, Herdr multiplexer, modern CLI utilities, fonts, themes, and polyglot runtimes. Your identity stays yours; none of my secrets or private history come along.

[![Shell](https://img.shields.io/badge/bash-5.x-1f425f)]()
[![Platform](https://img.shields.io/badge/macOS-Tahoe%20%7C%20Sonoma%20%7C%20Ventura-black)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()

---

## ⚡ Quick Install

On your Mac, open Terminal, paste this single line, and press Enter:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sambatia/sam-setup/main/bootstrap.sh)"
```

### What happens next:
1. **Consent Gate**: Displays a clear summary of what will be installed and asks for your confirmation (`[y/N]`).
2. **System Prerequisites**: Installs Xcode Command Line Tools, Rosetta 2 (if Apple Silicon), and Homebrew (if missing).
3. **Identity Setup**: Chezmoi prompts for your **Name** and **Git Email** (used exclusively for your `.gitconfig`).
4. **Safety Backup**: Existing configs (`~/.zshrc`, `~/.tmux.conf`, `~/.config/nvim`, etc.) are automatically backed up to timestamped copies (`.bak-<timestamp>`).
5. **Software Installation**: Installs the curated Homebrew toolset, Ghostty, JetBrains Mono Nerd Font, and CLI utilities.
6. **Runtimes & Agents**: Installs Node.js LTS, pnpm, and coding agent CLIs via `mise`, and sets up isolated Python tools with `uv`.
7. **Editor & Multiplexers**: Headlessly synchronizes LazyVim plugins and clones tmux TPM plugins.
8. **SSH Key**: Generates a fresh `ed25519` SSH key **only if you don't already have one**, and prints the public key ready for GitHub.
9. **Health Verification**: Runs `sam-setup-check` to verify that everything is green and ready.

---

## 🧰 What You Get

### 🖥 Terminal & Multiplexing
* **[Ghostty](https://ghostty.org)**: GPU-accelerated terminal styled with **Catppuccin Mocha**, 90% opacity with background blur, JetBrains Mono Nerd Font Mono, and native macOS Tahoe tabs.
* **[Herdr](https://github.com/danbuhler/herdr)**: Agentic terminal multiplexer configured with seamless Neovim smart-splits navigation (`Ctrl+h/j/k/l`) and pane topic sync.
* **[Tmux](https://github.com/tmux/tmux)**: Configured with `Ctrl-A` prefix, true-color RGB undercurl pass-through, mouse toggle (`prefix + m`), session persistence (resurrect/continuum), and TPM plugins.
* **[Workmux](https://github.com/raine/workmux)**: Automated Git worktree isolation for parallel agent workflows.

### 🐚 Shell & Navigation
* **Zsh + [Starship](https://starship.rs)**: Two-line prompt with execution duration, Git branch/status, language indicators, Catppuccin palette, and a 250ms latency ceiling.
* **[Atuin](https://atuin.sh)**: Daemon-backed shell history search with local socket and fuzzy AI search.
* **[Zoxide](https://github.com/ajeetdsouza/zoxide)**: Smarter `cd` command that learns your habits.
* **[Yazi](https://yazi-rs.github.io)** & **[Superfile (`spf`)](https://superfile.netlify.app)**: Modern, lightning-fast terminal file managers with graphic previews.
* **Modern CLI Replacements**: `eza` (replaces `ls`), `bat` (replaces `cat`), `ripgrep` (`rg`), `fd` (`find`), `dust` (`du`), `procs` (`ps`), `btop` (`top`), `lazygit` (`lg`), `gping` (`ping`), `xh` (`curl`).

### 💻 Editor (Neovim / LazyVim)
* Full **[LazyVim](https://www.lazyvim.org)** IDE stack in `~/.config/nvim`.
* Auto-configured LSPs, Treesitter parsers, Markdown glow/renderers, git integrations, and fuzzy finding via Telescope.

### ⚙️ Polyglot Runtimes
* **[mise](https://mise.jdx.dev)**: Fast, polyglot version manager pre-configured with Node.js LTS, pnpm, Codex CLI, TypeScript, and developer CLIs.
* **[uv](https://docs.astral.sh/uv/)**: Fast Python package manager managing standalone CLI tools (`basedpyright`, `gita`, `mlx-lm`, `specify-cli`, etc.).

### 🔄 One-Command Updates
Whenever you want to update your entire environment, simply run:
```sh
update-all
```
This updates Homebrew, mise runtimes, global Node CLIs, uv tools, Neovim plugins, Tmux plugins, and dotfiles in a single coordinated, safe pass.

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
