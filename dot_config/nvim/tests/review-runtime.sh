#!/bin/sh
set -eu
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
review_root=$(mktemp -d "${TMPDIR:-/tmp}/lazyvim-review.XXXXXX")
trap 'rm -rf -- "$review_root"' EXIT HUP INT TERM
NVIM_REVIEW_LAZY_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy"
XDG_CONFIG_HOME=$(dirname "$(dirname "$script_dir")")
export NVIM_REVIEW_LAZY_ROOT XDG_CONFIG_HOME
export XDG_STATE_HOME="$review_root/state" XDG_CACHE_HOME="$review_root/cache"
export NVIM_NOTES_DIR="$review_root/vault"
export NVIM_REVIEW_BOOTSTRAP="$script_dir/review_bootstrap.lua"
export NVIM_REVIEW_RUNTIME="$script_dir/review_runtime.lua"
nvim --headless -i NONE --cmd 'lua dofile(vim.env.NVIM_REVIEW_BOOTSTRAP)' \
  -c 'lua require("config.lazy_validation").run_runtime_smoke(vim.env.NVIM_REVIEW_RUNTIME)' +qa

# Reuse the existing preview/Enter/cancel/restart cases against the same guarded
# production configuration. Each process loads the theme saved by its predecessor.
export NVIM_THEME_TEST_SCRIPT="$script_dir/colorscheme_runtime.lua"
run_theme() {
  NVIM_THEME_EXPECTED=$1 NVIM_THEME_SELECT=$2 NVIM_THEME_SAVED=$3 NVIM_THEME_CANCEL=$4 NVIM_THEME_MODE=${5:-n} \
    nvim --headless -i NONE --cmd 'lua dofile(vim.env.NVIM_REVIEW_BOOTSTRAP)' \
    -c 'lua require("config.lazy_validation").run_runtime_smoke(vim.env.NVIM_THEME_TEST_SCRIPT)' +qa
}
run_theme kanagawa-wave tokyonight-moon '' 0
run_theme tokyonight-moon catppuccin-mocha tokyonight-moon 1
run_theme tokyonight-moon catppuccin-mocha tokyonight-moon 0 i
run_theme catppuccin-mocha kanagawa-wave catppuccin-mocha 0
run_theme kanagawa-wave '' kanagawa-wave 0
