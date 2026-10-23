#!/usr/bin/env bats

load lib/source-root

setup() {
  terminal_setup_require_source_root

  export GITA_COMPLETION="${TS_SOURCE_ROOT}/dot_oh-my-zsh/custom/completions/_gita"
  export MANI_COMPLETION="${TS_SOURCE_ROOT}/dot_oh-my-zsh/custom/completions/_mani"
  export MANI_PROJECT_CONFIG="${TS_SOURCE_ROOT}/dot_config/terminal_setup/mani-completion-project.yaml"
  export MANI_USER_CONFIG="${TS_SOURCE_ROOT}/dot_config/terminal_setup/mani-completion-user.yaml"
  export TEST_ROOT
  TEST_ROOT="$(mktemp -d "${BATS_TEST_TMPDIR}/dev-workflows.XXXXXX")"
}

teardown() {
  if [[ -n "${TEST_ROOT:-}" && -d "$TEST_ROOT" ]]; then
    case "$TEST_ROOT" in
      "${BATS_TEST_TMPDIR}/dev-workflows."*) /bin/rm -rf -- "$TEST_ROOT" ;;
    esac
  fi
}

@test "Chezmoi does not install the incompatible inventory-reading Gita completion" {
  [ ! -e "$GITA_COMPLETION" ]
  [ ! -L "$GITA_COMPLETION" ]
}

@test "Mani completion is a reviewed regular-file artifact" {
  [ -f "$MANI_COMPLETION" ]
  [ ! -L "$MANI_COMPLETION" ]

  run /bin/sh -c 'wc -c < "$1" | tr -d "[:space:]"' sh "$MANI_COMPLETION"
  [ "$status" -eq 0 ]
  [ "$output" = "8173" ]

  run shasum -a 256 "$MANI_COMPLETION"
  [ "$status" -eq 0 ]
  [ "${output%% *}" = "99e909212bb4f22107f747e6cc57f44d823b75fe80b4f346273b64bf070d7cf4" ]
}

@test "Mani completion forces explicit reviewed empty configs" {
  [ "$(cat "$MANI_PROJECT_CONFIG")" = "{}" ]
  [ "$(cat "$MANI_USER_CONFIG")" = "{}" ]
  [ ! -L "$MANI_PROJECT_CONFIG" ]
  [ ! -L "$MANI_USER_CONFIG" ]

  run grep -F 'requestComp="${words[1]} -c ${(q)maniCompletionProjectConfig} -u ${(q)maniCompletionUserConfig} __complete ${words[2,-1]}"' "$MANI_COMPLETION"
  [ "$status" -eq 0 ]
  run grep -F 'requestComp="${words[1]} __complete ${words[2,-1]}"' "$MANI_COMPLETION"
  [ "$status" -eq 1 ]

  run env \
    HOME="$TEST_ROOT" \
    XDG_CONFIG_HOME="$TEST_ROOT/config" \
    mani -c "$MANI_PROJECT_CONFIG" -u "$MANI_USER_CONFIG" __complete ''
  [ "$status" -eq 0 ]
}

@test "standard compinit discovers and loads Mani without startup files" {
  run env \
    HOME="$TEST_ROOT" \
    ZDOTDIR="$TEST_ROOT" \
    COMPLETION_DIR="$(dirname "$MANI_COMPLETION")" \
    zsh -f -c '
      fpath=("$COMPLETION_DIR" $fpath)
      autoload -Uz compinit
      compinit -D -d "$ZDOTDIR/.zcompdump" || exit 10
      [[ "${_comps[mani]-}" == _mani ]] || exit 11
      autoload +X _mani || exit 12
      [[ "${functions[_mani]}" != *"autoload -X"* ]] || exit 13
      print -r -- "mapping=${_comps[mani]} loaded=${functions[_mani]+yes}"
    '

  [ "$status" -eq 0 ]
  [ "$output" = "mapping=_mani loaded=yes" ]
}
