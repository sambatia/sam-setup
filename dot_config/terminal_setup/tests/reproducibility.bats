#!/usr/bin/env bats

setup() {
  SOURCE_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chezmoi-repro.XXXXXX")"
  TEST_HOME="$TEST_ROOT/home"
  mkdir -p "$TEST_HOME"
  TEST_HOME="$(cd "$TEST_HOME" && pwd -P)"
  : >"$TEST_ROOT/config.toml"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

apply_reproducible_targets() {
  HOME="$TEST_HOME" chezmoi \
    --source "$SOURCE_ROOT" \
    --destination "$TEST_HOME" \
    --config "$TEST_ROOT/config.toml" \
    --cache "$TEST_ROOT/cache" \
    --persistent-state "$TEST_ROOT/state.db" \
    --refresh-externals=false \
    --no-tty \
    --force \
    apply
}

@test "portable shell and terminal configs apply into an empty home with intended modes" {
  run apply_reproducible_targets
  [ "$status" -eq 0 ]

  [ "$(stat -f %Lp "$TEST_HOME/.zprofile")" = 644 ]
  [ "$(stat -f %Lp "$TEST_HOME/.config/terminal_setup/additions.zsh")" = 600 ]
  [ "$(stat -f %Lp "$TEST_HOME/.config/atuin/config.toml")" = 600 ]
  [ "$(stat -f %Lp "$TEST_HOME/.config/btop/btop.conf")" = 644 ]
  [ "$(stat -f %Lp "$TEST_HOME/.config/btop/themes/catppuccin_mocha.theme")" = 644 ]
  [ -f "$TEST_HOME/.config/btop/themes/LICENSE-catppuccin" ]
  [ "$(stat -f %Lp "$TEST_HOME/.config/bat/config")" = 600 ]
  [ "$(stat -f %Lp "$TEST_HOME/.config/ghostty/config")" = 644 ]
  [ "$(stat -f %Lp "$TEST_HOME/.config/herdr/config.toml")" = 644 ]
  [ "$(stat -f %Lp "$TEST_HOME/.ripgreprc")" = 600 ]
  [ "$(stat -f %Lp "$TEST_HOME/.config/starship.toml")" = 600 ]
}

@test "canonical bat and ripgrep preferences are restored" {
  run apply_reproducible_targets
  [ "$status" -eq 0 ]

  run grep -Fx -- '--theme="Catppuccin Mocha"' "$TEST_HOME/.config/bat/config"
  [ "$status" -eq 0 ]
  run grep -Fx -- '--smart-case' "$TEST_HOME/.ripgreprc"
  [ "$status" -eq 0 ]
  run grep -Fx -- '--hidden' "$TEST_HOME/.ripgreprc"
  [ "$status" -eq 0 ]
  run grep -Fx -- '--glob=!.git/*' "$TEST_HOME/.ripgreprc"
  [ "$status" -eq 0 ]
}

@test "Atuin deployment keeps sync private, enables AI, and renders a portable daemon socket" {
  run apply_reproducible_targets
  [ "$status" -eq 0 ]

  run grep -E '^auto_sync[[:space:]]*=[[:space:]]*false$' "$TEST_HOME/.config/atuin/config.toml"
  [ "$status" -eq 0 ]
  run awk '
    /^\[ai\]$/ { in_ai = 1; next }
    /^\[/ { in_ai = 0 }
    in_ai && /^enabled[[:space:]]*=[[:space:]]*true$/ { found = 1 }
    END { exit !found }
  ' "$TEST_HOME/.config/atuin/config.toml"
  [ "$status" -eq 0 ]
  run grep -Fx 'enabled = true' "$TEST_HOME/.config/atuin/config.toml"
  [ "$status" -eq 0 ]
  run grep -Fx "socket_path = \"$TEST_HOME/.local/share/atuin/atuin.sock\"" "$TEST_HOME/.config/atuin/config.toml"
  [ "$status" -eq 0 ]
  run grep -F '/Users/sam/' "$TEST_HOME/.config/atuin/config.toml"
  [ "$status" -ne 0 ]
}

@test "Herdr deployment restores only stable configuration and reviewed manifests" {
  run apply_reproducible_targets
  [ "$status" -eq 0 ]

  [ -f "$TEST_HOME/.config/herdr/plugins/config/herdr-lazy/plugins.lock" ]
  [ -f "$TEST_HOME/.config/herdr/plugins/config/dan.pane-topic-sync/config.toml" ]
  [ -f "$TEST_HOME/.config/herdr/plugins/config/herdr-plugin-workspace-manager/config.yml" ]
  [ ! -e "$TEST_HOME/.config/herdr/plugins/config/herdr-lazy/bootstrapped" ]
  [ ! -e "$TEST_HOME/.config/herdr/plugins/config/herdr-lazy/plugins.lock.1" ]
}

@test "Chezmoi no longer claims zsh-completions package ownership" {
  run grep -E '^[[:space:]]*brew[[:space:]]+"zsh-completions"' "$SOURCE_ROOT/dot_config/terminal_setup/recommended-tools.Brewfile"
  [ "$status" -ne 0 ]
}
