#!/usr/bin/env bash
#
# run_once_before — FIRST apply only: back up any REAL pre-existing config files
# chezmoi is about to replace, so "don't clobber" is guaranteed (chezmoi
# overwrites by default). run_once = keyed on content hash, so this fires once
# per machine, not on every `chezmoi update`.
#
set -eu

ts="$(date +%Y%m%d-%H%M%S)"
backed=0
for t in \
  "$HOME/.zshrc" "$HOME/.zshenv" "$HOME/.zprofile" "$HOME/.zshrc.d" \
  "$HOME/.gitconfig" "$HOME/.tmux.conf" \
  "$HOME/.config/nvim" "$HOME/.config/mise" "$HOME/.config/starship.toml" \
  "$HOME/.config/ghostty" "$HOME/.config/atuin" "$HOME/.config/herdr" \
  "$HOME/.config/workmux" "$HOME/.config/yazi" "$HOME/.config/btop" \
  "$HOME/.config/bat" "$HOME/.config/superfile" "$HOME/.config/tuios"; do
  if [ -e "$t" ] && [ ! -L "$t" ]; then
    cp -R "$t" "$t.bak-$ts" && printf 'backed up %s -> %s.bak-%s\n' "$t" "$t" "$ts"
    backed=$((backed + 1))
  fi
done
[ "$backed" -eq 0 ] && echo "no pre-existing config to back up."
exit 0
