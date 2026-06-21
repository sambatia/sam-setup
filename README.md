# sam-setup

> One line, walk away, come back to a Mac that works like mine — same CLI tools, nvim, fonts, theme, and shell. Your identity stays yours; none of my secrets come along.

[![Shell](https://img.shields.io/badge/bash-5.x-1f425f)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()

## Install

On a fresh Mac, paste this and walk away (you'll get one `[y/N]` consent prompt, then it asks your name + email):

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sambatia/sam-setup/v0.1.0/bootstrap.sh)"
```

> **Why a version tag (`v0.1.0`) and not `main`?** Piping a URL into your shell runs
> whatever is there *right now*. Pinning to a released tag means you run code that was
> reviewed and tagged — not whatever happens to be on `main` this minute. Bump the tag
> in this line when a new release is cut.

It will, on your Mac:
- install Homebrew (if missing) + the tools/apps in the `Brewfile`,
- generate an SSH key **only if you have none**,
- back up (never silently overwrite) then replace your shell/nvim/mise/tmux config.

Re-running is safe. Pull later changes with `chezmoi update` (run `chezmoi diff` first to preview).

## What you get

- **CLI tools** — ripgrep, fzf, zoxide, eza, bat, lazygit, btop, … (the `Brewfile`).
- **Neovim** — the full Lazy.nvim stack.
- **Shell** — zsh with the Starship prompt, autosuggestions + syntax highlighting,
  modern aliases, and tool init (zoxide/atuin/direnv/mise/fzf).
- **Terminal** — Ghostty, themed Catppuccin Mocha with a JetBrains Mono Nerd Font.
- **tmux** — Ctrl-A prefix, mouse, Catppuccin (tpm auto-cloned; `prefix + I` to install).
- **Git** — your identity (prompted), sensible defaults.

## Customize (your machine, never shipped)

Everything here is a sane shared baseline. Layer your own on top — these files are
sourced if present and are **not** part of this repo:

- `~/.zshrc.local` — your aliases, PATH tweaks, machine-specific bits.
- `~/.config/ghostty/config.local` — terminal overrides.
- **Secrets** go in the macOS Keychain, never a dotfile (see the note in `~/.zshrc`).

Pull updates later with `chezmoi update` (run `chezmoi diff` first to preview).

## What stays yours / never shipped

Your git name + email (prompted on first run), a fresh SSH key, and — deliberately —
**none** of my secrets, tokens, signing keys, or Keychain contents. This repo is the
public, shareable layer only.

## Uninstall / rollback

Existing configs are moved to `<path>.bak-<timestamp>` before replacement, so nothing
is lost. A one-command `restore` is on the task list.

## Development

```sh
just            # list tasks
just check      # shellcheck + unit tests (the pre-commit gate)
just brewfile-refresh   # regenerate the Brewfile from your machine
just preview    # chezmoi diff — what an update would change
```

## Releasing

The install one-liner pins to a git tag, so changes only reach friends when you cut a release:

```sh
just release v0.2.0   # runs checks, tags, pushes, reminds you to bump the README line
```

Then update the `v0.X.Y` in the install command above. See `CHANGELOG.md`.

## License

[MIT](LICENSE) — Copyright (c) 2026 Sameh Abdalla.
