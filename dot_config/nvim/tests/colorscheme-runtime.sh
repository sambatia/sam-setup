#!/bin/sh
set -eu
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/lazyvim-colorscheme-tests.XXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM
export XDG_CONFIG_HOME
XDG_CONFIG_HOME=$(dirname "$(dirname "$script_dir")")
export XDG_STATE_HOME="$test_root/state"
export NVIM_NOTES_DIR="$test_root/vault"
export NVIM_THEME_TEST_SCRIPT="$script_dir/colorscheme_runtime.lua"
run() {
  NVIM_THEME_EXPECTED=$1 NVIM_THEME_SELECT=$2 NVIM_THEME_SAVED=$3 NVIM_THEME_CANCEL=$4 NVIM_THEME_MODE=${5:-n} \
    nvim --headless -i NONE --cmd 'let g:safe_plugin_updates_enabled=v:false' \
    -c 'lua local ok, err = pcall(dofile, vim.env.NVIM_THEME_TEST_SCRIPT); if not ok then print(err); vim.cmd("cquit 1") else vim.cmd("qa!") end'
}
run kanagawa-wave tokyonight-moon '' 0
run tokyonight-moon catppuccin-mocha tokyonight-moon 1
run tokyonight-moon catppuccin-mocha tokyonight-moon 0 i
run catppuccin-mocha kanagawa-wave catppuccin-mocha 0
run kanagawa-wave '' kanagawa-wave 0
printf '%s\n' '{broken json' > "$XDG_STATE_HOME/nvim/colorscheme.json"
run kanagawa-wave '' '' 0
printf '%s\n' '{"name":"theme-that-does-not-exist","background":"dark"}' > "$XDG_STATE_HOME/nvim/colorscheme.json"
run kanagawa-wave '' '' 0
