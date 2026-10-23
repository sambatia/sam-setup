# ==============================================================================
#  ~/.config/terminal_setup/additions.zsh
#  Managed by dev_env_setup.sh v2.0
#  Your ~/.zshrc is untouched except for one source line at the bottom.
#  To remove everything: delete that line and this file.
# ==============================================================================

# ── Brew prefix fallback (normally initialized once by ~/.zshenv) ─────────────
if [[ -z "${FASTOOZ_HOMEBREW_SHELLENV_READY:-}" &&
      -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  export FASTOOZ_HOMEBREW_SHELLENV_READY=1
elif [[ -z "${FASTOOZ_HOMEBREW_SHELLENV_READY:-}" &&
        -f /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
  export FASTOOZ_HOMEBREW_SHELLENV_READY=1
fi

# ── Starship (skip if already initialised by another config) ───────────────────
if command -v starship &>/dev/null && [[ "${STARSHIP_SHELL:-}" != "zsh" ]]; then
  eval "$(starship init zsh)"
  export STARSHIP_LOG=error
fi

# ── Zoxide (skip if already initialised) ───────────────────────────────────────
if command -v zoxide &>/dev/null && ! typeset -f __zoxide_z &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

# ── mise (controlled by MISE_ACTIVATE_OK — avoids conflicts with nvm/pyenv) ────
# Set MISE_ACTIVATE_OK=true in your .zshrc BEFORE the source line to enable.
if [[ "${MISE_ACTIVATE_OK:-false}" == "true" ]]; then
  command -v mise &>/dev/null && eval "$(mise activate zsh)"
fi

# ── fzf ────────────────────────────────────────────────────────────────────────
if [[ -t 0 && -t 1 && -z "${FASTOOZ_FZF_LOADED:-}" ]]; then
  if [[ -f "${HOME}/.fzf.zsh" ]]; then
    source "${HOME}/.fzf.zsh"
  else
    command -v fzf &>/dev/null && { eval "$(fzf --zsh)" 2>/dev/null || true; }
  fi
  export FASTOOZ_FZF_LOADED=1
fi

# ── carapace completions ───────────────────────────────────────────────────────
command -v carapace &>/dev/null && eval "$(carapace _carapace zsh)" 2>/dev/null || true

# ── fzf options (guarded — existing values win, except the previews) ───────────
if command -v fd &>/dev/null; then
  export FZF_DEFAULT_COMMAND="${FZF_DEFAULT_COMMAND:-fd --type f --hidden --follow --exclude .git}"
  export FZF_CTRL_T_COMMAND="${FZF_CTRL_T_COMMAND:-$FZF_DEFAULT_COMMAND}"
fi
# Previews are assigned outright, as in ~/.zshrc.d/fzf.zsh: a {} placeholder
# inside "${VAR:-...}" closes the expansion early and appends "'}" on every load.
command -v bat &>/dev/null && export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --line-range :200 {}'"
command -v eza &>/dev/null && export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:---height 40% --layout=reverse}"

# ── bat (man pages; guarded) ──────────────────────────────────────────────────
# Theme authority is ~/.config/bat/config. Drop inherited overrides so every
# interactive shell uses the configured Catppuccin Mocha theme consistently.
if command -v bat &>/dev/null; then
  unset BAT_THEME
  if [[ -z "${MANPAGER:-}" ]]; then
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
    export MANROFFOPT="-c"
  fi
fi

# ── ripgrep ────────────────────────────────────────────────────────────────────
command -v rg &>/dev/null &&   export RIPGREP_CONFIG_PATH="${RIPGREP_CONFIG_PATH:-${HOME}/.ripgreprc}"

# ── Herdr aliases ──────────────────────────────────────────────────────────────
if command -v herdr &>/dev/null; then
  alias h='herdr'
  alias hs='herdr session list'
  alias ha='herdr session attach'
  alias hst='herdr server stop'
  alias hrl='herdr server reload-config'
  alias hup='herdr update'
  alias hint='herdr integration status'
  alias hag='herdr agent list'
fi

# ── Supacode ───────────────────────────────────────────────────────────────────
if [[ -d "/Applications/Supacode.app" ]] || command -v supacode &>/dev/null; then
  alias sc='open -a Supacode 2>/dev/null || supacode 2>/dev/null'
fi

# ── eza listing (new names only — 'ls' is NOT aliased) ────────────────────────
# `[[ -t 1 ]]`: eza can hang when stdout is not a terminal, stranding the shell that
# holds it. Claude Code and other agent/CI shells snapshot this config and run with
# stdout on a socket, so they must fall back to coreutils. Evaluated once at startup,
# so an interactive terminal is unaffected (eza still used in pipes there).
if [[ -t 1 ]] && command -v eza &>/dev/null; then
  alias ll='eza -lah --git --icons --group-directories-first'
  alias lt='eza --tree --level=2 --icons'
  alias la='eza -a --icons'
  alias lla='eza -lah --git --icons -a'
  alias lst='eza --icons --group-directories-first'
fi

# ── lazygit ────────────────────────────────────────────────────────────────────
# TTY-guarded for the same reason: a full-screen TUI in a non-TTY shell hangs.
[[ -t 1 ]] && command -v lazygit &>/dev/null && alias lg='lazygit'

# ── glow markdown viewer ───────────────────────────────────────────────────────
command -v glow &>/dev/null && alias mdv='glow'

# ── yazi file manager with cd-on-quit ─────────────────────────────────────────
if command -v yazi &>/dev/null && ! typeset -f y &>/dev/null; then
  function y() {
    local tmp cwd
    tmp="$(mktemp -t 'yazi-cwd.XXXXXX')" || return 1
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [[ -n "$cwd" ]] && [[ "$cwd" != "$PWD" ]]; then
      builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
  }
fi

# ── Convenience ────────────────────────────────────────────────────────────────
alias reload='exec zsh'
alias path='echo $PATH | tr ":" "\n"'
