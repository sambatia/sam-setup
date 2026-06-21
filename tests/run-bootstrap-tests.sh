#!/usr/bin/env bash
#
# run-bootstrap-tests.sh — dependency-free unit tests for the sam-setup scripts.
# Covers the SAFETY branches a warm-runner CI smoke can't reach: consent-decline
# aborts with no mutation, the SSH keygen guard, and rollback selection.
#
set -uo pipefail

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
PASS=0; FAIL=0
GRN=$'\033[32m'; RED=$'\033[31m'; RST=$'\033[0m'; [ -t 1 ] || { GRN=""; RED=""; RST=""; }
ok()  { PASS=$((PASS+1)); printf '  %s✓%s %s\n' "$GRN" "$RST" "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  %s✗%s %s\n' "$RED" "$RST" "$1"; }

# ── consent gate (bootstrap.sh) ──────────────────────────────────────────────
# Source bootstrap; its die() exits, so override it to a non-exiting stub first.
# shellcheck source=/dev/null
source "$DIR/bootstrap.sh"
set +e
die() { printf 'DIE: %s\n' "$1" >&2; return 1; }   # override: report instead of exit

SAM_SETUP_YES=1 consent >/dev/null 2>&1 && ok "consent: SAM_SETUP_YES=1 auto-proceeds" || bad "consent: auto-proceed"

unset SAM_SETUP_YES
printf 'n\n' | consent >/dev/null 2>&1
[ "$?" -ne 0 ] && ok "consent: decline (n) aborts non-zero" || bad "consent: decline aborts"

printf 'y\n' | { SAM_SETUP_YES=0 consent >/dev/null 2>&1; }
[ "$?" -eq 0 ] && ok "consent: explicit y proceeds" || bad "consent: y proceeds"

# ── SSH keygen guard (run_after_20-ssh-key.sh) ───────────────────────────────
# shellcheck source=/dev/null
source "$DIR/.chezmoiscripts/run_after_20-ssh-key.sh"

T1="$(mktemp -d)"; : > "$T1/id_rsa"          # friend already has an RSA key
SSH_DIR="$T1" have_private_key && ok "keygen guard: existing id_rsa → has key (no regen)" || bad "keygen guard: existing id_rsa"
rm -rf "$T1"

T2="$(mktemp -d)"; : > "$T2/id_ed25519.pub"  # ONLY a public key present
SSH_DIR="$T2" have_private_key && bad "keygen guard: lone .pub must NOT count as a private key" || ok "keygen guard: lone .pub is not a private key"
rm -rf "$T2"

T3="$(mktemp -d)"                            # no keys at all
SSH_DIR="$T3" have_private_key && bad "keygen guard: empty dir wrongly reports a key" || ok "keygen guard: empty dir → no key (will generate)"
rm -rf "$T3"

# ── rollback (sam-setup-restore) ─────────────────────────────────────────────
FAKEHOME="$(mktemp -d)"
printf 'NEW\n' > "$FAKEHOME/.zshrc"
printf 'OLD\n' > "$FAKEHOME/.zshrc.bak-20260101-000000"
HOME="$FAKEHOME" bash "$DIR/dot_local/bin/executable_sam-setup-restore" >/dev/null 2>&1
[ "$(cat "$FAKEHOME/.zshrc" 2>/dev/null)" = "OLD" ] && ok "restore: replaces current with most-recent .bak" || bad "restore: did not restore backup"
[ ! -e "$FAKEHOME/.zshrc.bak-20260101-000000" ] && ok "restore: consumes the backup" || bad "restore: backup not consumed"
rm -rf "$FAKEHOME"

# ── chezmoi template render (the .tmpl files aren't shellcheck-covered) ──────
if command -v chezmoi >/dev/null 2>&1; then
  chezmoi execute-template --source="$DIR" \
    < "$DIR/.chezmoiscripts/run_onchange_after_10-install-packages.sh.tmpl" >/dev/null 2>&1 \
    && ok "tmpl: install-packages renders (Brewfile include resolves)" \
    || bad "tmpl: install-packages render failed"
  cfg="$(SAM_SETUP_NAME="Test User" SAM_SETUP_EMAIL="t@e.co" \
    chezmoi execute-template --source="$DIR" --init < "$DIR/.chezmoi.toml.tmpl" 2>/dev/null)"
  case "$cfg" in
    *'name   = "Test User"'*) ok "tmpl: config renders + env-seeds identity (CI-friendly)" ;;
    *) bad "tmpl: config render/env-seed failed" ;;
  esac
else
  printf '  %s· chezmoi absent — template render checks skipped%s\n' "${GRN}" "${RST}"
fi

printf '\nTests: %s%d passed%s, %s%d failed%s\n' "$GRN" "$PASS" "$RST" "$([ "$FAIL" -gt 0 ] && echo "$RED" || echo "")" "$FAIL" "$RST"
[ "$FAIL" -eq 0 ]
