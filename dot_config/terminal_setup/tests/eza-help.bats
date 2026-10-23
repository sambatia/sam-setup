#!/usr/bin/env bats

load lib/source-root

@test "lhelp renders safely from live alias definitions across terminal modes" {
  terminal_setup_require_source_root
  run env TERMINAL_SETUP_SOURCE_ROOT="$TS_SOURCE_ROOT" PYTHONDONTWRITEBYTECODE=1 \
    python3 "${BATS_TEST_DIRNAME}/test_eza_help.py" -v
  [ "$status" -eq 0 ]
}
