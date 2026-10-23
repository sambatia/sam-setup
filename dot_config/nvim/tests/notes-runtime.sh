#!/bin/sh
# Uses installed plugins and CLIs, but only writes notes into a disposable vault.
set -eu
config_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
qa_root=$(mktemp -d "${TMPDIR:-/tmp}/lazyvim-notes-qa.XXXXXX")
# shellcheck disable=SC2329
cleanup() { rm -rf -- "$qa_root"; }
trap cleanup EXIT HUP INT TERM
export NVIM_NOTES_DIR="$qa_root/vault"
XDG_CONFIG_HOME=$(dirname "$config_root")
export XDG_CONFIG_HOME
# Keep mise-backed formatters on their existing trust state while isolating Neovim.
export MISE_STATE_DIR="${MISE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/mise}"
# Keep QA history, logs, and undo files out of the real editing session.
export XDG_STATE_HOME="$qa_root/state"
nvim --headless \
  '+lua require("config.lazy_validation").run_runtime_smoke(vim.fn.stdpath("config") .. "/tests/notes_runtime.lua")' +qa

nvim --headless \
  '+lua require("config.lazy_validation").run_runtime_smoke(vim.fn.stdpath("config") .. "/tests/notes_ux_runtime.lua")' +qa
