#!/usr/bin/env bash
#
# run_once_before — FIRST apply only: back up any REAL pre-existing config files
# chezmoi is about to replace, so "don't clobber" is guaranteed (chezmoi
# overwrites by default). run_once = keyed on content hash, so this fires once
# per machine, not on every `chezmoi update`. Closes the eng-review critical gap.
#
set -eu

ts="$(date +%Y%m%d-%H%M%S)"
backed=0
for t in \
  "$HOME/.zshrc" "$HOME/.zshenv" "$HOME/.gitconfig" "$HOME/.tmux.conf" \
  "$HOME/.config/nvim" "$HOME/.config/mise" "$HOME/.config/starship.toml" \
  "$HOME/.config/ghostty/config"; do
  # Only back up a real file/dir (a pre-existing one). chezmoi-managed files on a
  # re-install would be caught by run_once firing only on first apply anyway.
  if [ -e "$t" ] && [ ! -L "$t" ]; then
    cp -R "$t" "$t.bak-$ts" && printf 'backed up %s -> %s.bak-%s\n' "$t" "$t" "$ts"
    backed=$((backed + 1))
  fi
done
[ "$backed" -eq 0 ] && echo "no pre-existing config to back up."
exit 0
