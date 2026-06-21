# sam-setup

> One line, walk away, come back to a Mac that works like mine — same CLI tools, nvim, fonts, theme, and shell. Your identity stays yours; none of my secrets come along.

[![Shell](https://img.shields.io/badge/bash-5.x-1f425f)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()

> **Status: scaffolding.** The repo skeleton + pinned one-liner are in place; the
> Brewfile, dotfile templates, and install scripts are being built out
> (see [the task list](#build-status)).

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

CLI tools (ripgrep, fzf, zoxide, …), the Neovim stack, a Nerd Font, the Starship
prompt, and shell wiring. GUI apps come via the `Brewfile` casks.

## What stays yours / never shipped

Your git name + email (prompted on first run), a fresh SSH key, and — deliberately —
**none** of my secrets, tokens, signing keys, or Keychain contents. This repo is the
public, shareable layer only.

## Uninstall / rollback

Existing configs are moved to `<path>.bak-<timestamp>` before replacement, so nothing
is lost. A one-command `restore` is on the task list.

## Build status

Tracked in the eng-review plan. Foundation (this skeleton + pinned one-liner) done;
next up: Brewfile, chezmoi dotfile templates, the `brew bundle` + SSH-key run-scripts,
unit tests, and CI smoke.

## License

[MIT](LICENSE) — Copyright (c) 2026 Sameh Abdalla.
