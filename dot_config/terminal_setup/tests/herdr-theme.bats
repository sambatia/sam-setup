#!/usr/bin/env bats

# Herdr rewrites ~/.config/herdr/config.toml itself whenever the theme is
# switched in its UI. The theme is a mood setting, not infrastructure: it must
# never show up as chezmoi drift and `chezmoi apply` must never revert it.
# Every other key in that file stays managed.

setup() {
  SOURCE_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chezmoi-herdr-theme.XXXXXX")"
  TEST_HOME="$TEST_ROOT/home"
  mkdir -p "$TEST_HOME"
  TEST_HOME="$(cd "$TEST_HOME" && pwd -P)"
  : >"$TEST_ROOT/config.toml"
  LIVE="$TEST_HOME/.config/herdr/config.toml"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

chez() {
  HOME="$TEST_HOME" chezmoi \
    --source "$SOURCE_ROOT" \
    --destination "$TEST_HOME" \
    --config "$TEST_ROOT/config.toml" \
    --cache "$TEST_ROOT/cache" \
    --persistent-state "$TEST_ROOT/state.db" \
    --refresh-externals=false \
    --no-tty \
    --force \
    "$@"
}

theme_name() {
  awk '/^\[theme\]/{f=1;next} f&&/^\[/{exit} f&&/^name = /{print;exit}' "$LIVE"
}

@test "a theme switched live in Herdr is neither drift nor reverted by apply" {
  run chez apply
  [ "$status" -eq 0 ]
  [ -f "$LIVE" ]

  sed -i '' 's/^name = "[^"]*"/name = "nord-test"/' "$LIVE"
  [ "$(theme_name)" = 'name = "nord-test"' ]

  run chez status
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  run chez apply
  [ "$status" -eq 0 ]
  [ "$(theme_name)" = 'name = "nord-test"' ]
  [ "$(stat -f %Lp "$LIVE")" = 644 ]
}

@test "managed Herdr keys are still enforced when the live file diverges" {
  run chez apply
  [ "$status" -eq 0 ]
  grep -q '^delivery = "herdr"$' "$LIVE"

  sed -i '' 's/^delivery = "herdr"$/delivery = "system"/' "$LIVE"

  run chez status
  [ "$status" -eq 0 ]
  [[ "$output" == *".config/herdr/config.toml"* ]]

  run chez apply
  [ "$status" -eq 0 ]
  grep -q '^delivery = "herdr"$' "$LIVE"
}
