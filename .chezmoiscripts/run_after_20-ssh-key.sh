#!/usr/bin/env bash
#
# run_after — generate an SSH key ONLY if the user has no usable private key.
# Runs every apply but is idempotent + self-healing (re-runs cleanly if a prior
# attempt failed). No template vars → plain .sh, so the guard is unit-testable.
#
set -eu

# A "usable private key" = a private key FILE chezmoi/ssh would actually use.
# We check known private-key filenames (NOT `ls id_*`, which also matches .pub
# public keys and would wrongly suppress generation). SSH_DIR override = testable.
have_private_key() {
  local d="${SSH_DIR:-$HOME/.ssh}" k
  for k in id_ed25519 id_ecdsa id_rsa id_dsa; do
    [ -f "$d/$k" ] && return 0
  done
  return 1
}

main_ssh_key() {
  local d="${SSH_DIR:-$HOME/.ssh}"
  if have_private_key; then
    echo "ssh: existing private key found — not generating a new one."
    return 0
  fi
  mkdir -p "$d"; chmod 700 "$d"
  echo "ssh: no private key — generating ed25519…"
  ssh-keygen -t ed25519 -N "" -f "$d/id_ed25519" -C "generated-by-sam-setup" >/dev/null
  echo "✓ ssh key generated. Add the PUBLIC key to GitHub:"
  echo "    gh ssh-key add $d/id_ed25519.pub   # or paste it at github.com/settings/keys"
  cat "$d/id_ed25519.pub"
}

# Source-guard: tests source this and call have_private_key() with SSH_DIR stubbed.
if [ "${BASH_SOURCE[0]:-$0}" = "${0}" ]; then main_ssh_key; fi
