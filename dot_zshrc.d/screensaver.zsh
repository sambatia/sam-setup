#!/usr/bin/env zsh
# CMatrix convenience aliases.
# Added 2026-07-09: purely cosmetic screensaver shortcuts, safe to delete.
# Guarded so this module is inert when cmatrix is absent.
if command -v cmatrix &>/dev/null; then
  alias matrix='cmatrix -ba -u 6'
  alias matrixg='cmatrix -ba -u 6 -C green'
fi
