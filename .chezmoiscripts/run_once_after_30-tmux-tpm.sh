#!/usr/bin/env bash
#
# run_once_after — clone tpm (tmux plugin manager) so ~/.tmux.conf's plugins
# work. Idempotent; non-fatal if git is missing. Press prefix + I inside tmux
# to install the listed plugins.
#
set -eu

dir="$HOME/.tmux/plugins/tpm"
[ -d "$dir" ] && { echo "tpm already present."; exit 0; }
command -v git >/dev/null 2>&1 || { echo "git missing — skipping tpm."; exit 0; }
git clone --depth 1 https://github.com/tmux-plugins/tpm "$dir" >/dev/null 2>&1 \
  && echo "✓ tpm installed (open tmux, press prefix + I to install plugins)." \
  || echo "tpm clone failed (network?) — skipping."
exit 0
