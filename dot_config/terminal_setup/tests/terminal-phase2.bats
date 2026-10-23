#!/usr/bin/env bats

setup() {
  SOURCE_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)"
  TEST_ROOT="$(mktemp -d "${BATS_TEST_TMPDIR}/terminal-phase2.XXXXXX")"
  ATUIN_LOG="$TEST_ROOT/atuin-init.log"
  : >"$ATUIN_LOG"
}

teardown() {
  case "${TEST_ROOT:-}" in
    "${BATS_TEST_TMPDIR}/terminal-phase2."*) /bin/rm -rf -- "$TEST_ROOT" ;;
  esac
}

@test "Oh My Zsh startup disables its independent update mode before sourcing" {
  mkdir -p "$TEST_ROOT/.oh-my-zsh"
  cat >"$TEST_ROOT/.oh-my-zsh/oh-my-zsh.sh" <<'ZSH'
zstyle -s ':omz:update' mode update_mode || update_mode=prompt
print -r -- "$update_mode" >"$HOME/omz-mode-at-source"
function omz { :; }
ZSH
  awk '/^zstyle .:omz:update. mode disabled/{capture=1} /^# ── Prompt:/{capture=0} capture{print}' \
    "$SOURCE_ROOT/dot_zshrc" >"$TEST_ROOT/omz-section.zsh"

  run env HOME="$TEST_ROOT" PATH=/usr/bin:/bin /bin/zsh -fc '
    source "$1"
    zstyle -s ":omz:update" mode update_mode
    [[ "$update_mode" == disabled ]] && (( ${+functions[omz]} ))
  ' zsh "$TEST_ROOT/omz-section.zsh"

  [ "$status" -eq 0 ]
  [ "$(cat "$TEST_ROOT/omz-mode-at-source")" = disabled ]
}

@test "additions does not reinitialize Atuin when its search widget already exists" {
  run env HOME="$TEST_ROOT" PATH=/usr/bin:/bin \
    FASTOOZ_HOMEBREW_SHELLENV_READY=1 ATUIN_LOG="$ATUIN_LOG" \
    /bin/zsh -fc '
      atuin() {
        [[ "$1 $2" == "init zsh" ]] || return 1
        print -r -- init >>"$ATUIN_LOG"
        print -r -- ":"
      }
      atuin-search() { :; }
      zle -N atuin-search
      source "$1"
      (( ${+widgets[atuin-search]} ))
    ' zsh "$SOURCE_ROOT/dot_config/terminal_setup/private_additions.zsh"

  [ "$status" -eq 0 ]
  [ ! -s "$ATUIN_LOG" ]
}

@test "wizard exposes Hunk as Git default and Delta as an opt-in diff" {
  run env HOME="$TEST_ROOT" PATH=/usr/bin:/bin FASTOOZ_DIR="$TEST_ROOT" \
    /bin/zsh -fc 'source "$1"; _sam_help' zsh \
    "$SOURCE_ROOT/dot_zshrc.d/private_sam-wizard.zsh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Hunk"* ]]
  [[ "$output" == *"git ddiff"* ]]
  [ "$(git config --file "$SOURCE_ROOT/dot_gitconfig" --get core.pager)" = "hunk pager" ]
}

@test "wizard help names the active history, monitor, and repeat-command tools" {
  run env HOME="$TEST_ROOT" PATH=/usr/bin:/bin FASTOOZ_DIR="$TEST_ROOT" \
    /bin/zsh -fc 'source "$1"; _sam_help' zsh \
    "$SOURCE_ROOT/dot_zshrc.d/private_sam-wizard.zsh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Atuin"* ]]
  [[ "$output" == *"btop"* ]]
  [[ "$output" == *"viddy"* ]]
  [[ "$output" == *"watchexec"* ]]
  run grep -E 'p10k configure|imgcat <img>|aliased from top' \
    "$SOURCE_ROOT/dot_zshrc.d/private_sam-wizard.zsh"
  [ "$status" -ne 0 ]
}

@test "wizard teaches builtin cd and standard zoxide commands" {
  run env HOME="$TEST_ROOT" PATH=/usr/bin:/bin FASTOOZ_DIR="$TEST_ROOT" \
    /bin/zsh -fc 'source "$1"; _sam_help' zsh \
    "$SOURCE_ROOT/dot_zshrc.d/private_sam-wizard.zsh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"cd <dir>"*"Change directory"*"shell builtin"* ]]
  [[ "$output" == *"z <query>"*"Jump to a frequent directory"*"zoxide"* ]]
  [[ "$output" == *"zi"*"Pick a frequent directory"*"zoxide + fzf"* ]]

  run grep -F 'Try: z project|Jump to a frequent directory with zoxide' \
    "$SOURCE_ROOT/dot_zshrc.d/private_sam-wizard.zsh"
  [ "$status" -eq 0 ]
  run grep -F 'zoxide-backed cd' "$SOURCE_ROOT/dot_zshrc.d/private_sam-wizard.zsh"
  [ "$status" -ne 0 ]
}

@test "wizard recommends installed Viddy instead of unavailable watch" {
  run grep -n 'watch -n2 cmd' "$SOURCE_ROOT/dot_zshrc.d/private_sam-wizard.zsh"
  [ "$status" -ne 0 ]
  run grep -n 'viddy -n 2' "$SOURCE_ROOT/dot_zshrc.d/private_sam-wizard.zsh"
  [ "$status" -eq 0 ]
}

@test "btop uses a managed Catppuccin Mocha theme with required color roles" {
  local theme="$SOURCE_ROOT/dot_config/btop/themes/catppuccin_mocha.theme"
  [ -f "$theme" ]
  [ -f "$SOURCE_ROOT/dot_config/btop/themes/LICENSE-catppuccin" ]
  run grep -Fx 'color_theme = "catppuccin_mocha"' \
    "$SOURCE_ROOT/dot_config/btop/btop.conf"
  [ "$status" -eq 0 ]
  for role in main_bg main_fg selected_bg selected_fg cpu_box mem_box \
    net_box proc_box process_start process_end; do
    run grep -E "^theme\\[$role\\]=\"#[[:xdigit:]]{6}\"" "$theme"
    [ "$status" -eq 0 ]
  done
}
