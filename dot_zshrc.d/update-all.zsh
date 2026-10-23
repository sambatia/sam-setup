# ~/.zshrc.d/update-all.zsh
# Compatibility wrapper only. The update orchestrator lives at:
#   ~/.local/bin/update-all

update-all() {
  local update_all_bin="$HOME/.local/bin/update-all"

  if [[ ! -x "$update_all_bin" ]]; then
    print -u2 -- "update-all: missing executable: $update_all_bin"
    print -u2 -- "Restore it from ~/.local/state/update-all/backups or install the orchestrator."
    return 127
  fi

  "$update_all_bin" "$@"
}
