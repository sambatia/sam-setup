# Configure and load fzf once per interactive Zsh process. ZLE widgets are not
# inherited by child shells, so exported "loaded" flags are not authoritative.
[[ -o interactive && -t 0 && -t 1 ]] || return 0

if (( ${+widgets[fzf-file-widget]} && ${+widgets[fzf-cd-widget]} )); then
  unset FASTOOZ_FZF_LOADED
  typeset -g FASTOOZ_FZF_LOADED=1
  return 0
fi

if command -v fd &>/dev/null; then
  export FZF_DEFAULT_COMMAND="${FZF_DEFAULT_COMMAND:-fd --type f --hidden --follow --exclude .git}"
  export FZF_CTRL_T_COMMAND="${FZF_CTRL_T_COMMAND:-$FZF_DEFAULT_COMMAND}"
fi
# Previews are assigned outright. Inside "${VAR:-...}" the "}" of fzf's {}
# placeholder closed the expansion early and appended "'}" on every load; an
# outright value is idempotent and also repairs one a parent shell corrupted.
command -v bat &>/dev/null &&
  export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --line-range :200 {}'"
command -v eza &>/dev/null &&
  export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:---height 40% --layout=reverse}"

# Atuin is the sole history-search owner; the empty value is fzf's documented
# opt-out and leaves Ctrl-R available for Atuin (or native history fallback).
export FZF_CTRL_R_COMMAND=""

_terminal_fzf_status=0
if [[ -r "$HOME/.fzf.zsh" ]]; then
  source "$HOME/.fzf.zsh" || _terminal_fzf_status=$?
elif command -v fzf &>/dev/null; then
  eval "$(fzf --zsh)" || _terminal_fzf_status=$?
else
  _terminal_fzf_status=127
fi

# Normalize the legacy compatibility marker to a shell-local value. This keeps
# additions.zsh from sourcing fzf twice without poisoning nested shells.
unset FASTOOZ_FZF_LOADED
typeset -g FASTOOZ_FZF_LOADED=1

if (( _terminal_fzf_status != 0 )); then
  print -u2 -r -- "fzf-integration: official Zsh integration unavailable (status $_terminal_fzf_status); native bindings retained"
elif (( ! ${+widgets[fzf-file-widget]} || ! ${+widgets[fzf-cd-widget]} )); then
  print -u2 -r -- "fzf-integration: expected Ctrl-T/Alt-C widgets were not registered; native bindings retained"
fi
unset _terminal_fzf_status
return 0
