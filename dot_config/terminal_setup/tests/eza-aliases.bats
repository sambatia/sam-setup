#!/usr/bin/env bats

load lib/source-root

setup() {
  terminal_setup_require_source_root
  command -v eza >/dev/null || skip "eza is required for the listing integration tests"
  export EZA_ALIAS_FILE="${EZA_ALIAS_FILE:-${TS_SOURCE_ROOT}/dot_config/zsh/aliases/eza.zsh}"
  export EZA_FIXTURE="${BATS_TEST_TMPDIR}/eza fixture"
  mkdir -p "$EZA_FIXTURE"
  python3 - <<'PY'
import os
from pathlib import Path

root = Path(os.environ['EZA_FIXTURE'])
for name in ('visible-dir/child-dir/grandchild-dir', '.hidden-dir', 'sort-files',
             'size-dirs/small-dir', 'size-dirs/large-dir', 'repository'):
    (root / name).mkdir(parents=True, exist_ok=True)
for name, size, timestamp in (('alpha-old.txt', 4, 1600000000),
                               ('middle.md', 50, 1700000000),
                               ('zeta-new.py', 600, 1800000000)):
    for parent in (root, root / 'sort-files'):
        file = parent / name
        file.write_bytes(b'x' * size)
        os.utime(file, (timestamp, timestamp))
(root / '.hidden-file').write_text('hidden')
(root / 'file-link').symlink_to('alpha-old.txt')
(root / 'visible-dir/child-dir/grandchild-dir/bottom.txt').write_text('deep')
(root / 'size-dirs/small-dir/data').write_bytes(b'x' * 10)
(root / 'size-dirs/large-dir/data').write_bytes(b'x' * 10000)
(root / 'repository/tracked.txt').write_text('staged')
(root / 'repository/.gitignore').write_text('ignored.txt\n')
(root / 'repository/ignored.txt').write_text('ignored')
PY
  # A temporary repository only: no global Git config, templates, hooks or commits.
  export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
  git -c init.defaultBranch=main init -q --template= "$EZA_FIXTURE/repository"
  git -C "$EZA_FIXTURE/repository" add tracked.txt .gitignore
  printf '\nmodified\n' >>"$EZA_FIXTURE/repository/tracked.txt"
  printf 'untracked\n' >"$EZA_FIXTURE/repository/untracked.txt"
}

run_alias() {
  run /bin/zsh -fic 'source "$1" || exit; cd "$2" || exit; eval "$3"' \
    zsh "$EZA_ALIAS_FILE" "$EZA_FIXTURE" "$1"
}

@test "managed zshrc loads the alias file once after legacy additions" {
  run python3 - "$TS_SOURCE_ROOT/dot_zshrc" <<'PY'
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
loader = 'source "$HOME/.config/zsh/aliases/eza.zsh"'
assert text.count(loader) == 1, 'expected one managed eza loader'
assert text.index(loader) > text.index('source "/Users/sam/.config/terminal_setup/additions.zsh"')
PY
  [ "$status" -eq 0 ]
}

@test "all twenty aliases execute with quoted directory arguments" {
  # Expanded by the child Zsh, not by Bats.
  # shellcheck disable=SC2016
  run_alias 'for item in ls l ll la lla lfull lt ltt ltl ld ltd lg lgt lrepo lnew lold lsize ldu lext lf; do
    (( ${+aliases[$item]} )) || exit 1
    result=$(eval "$item \"$EZA_FIXTURE\"") || exit
    [[ -n $result ]] || exit 1
  done'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "sourcing twice preserves arrays aliases and PATH without output" {
  # Expanded by the child Zsh, not by Bats.
  # shellcheck disable=SC2016
  run_alias 'before_aliases=$(alias ls l ll la lla lfull lt ltt ltl ld ltd lg lgt lrepo lnew lold lsize ldu lext lf)
    before_base=${(j:|:)EZA_BASE}; before_long=${(j:|:)EZA_LONG}; before_path=$PATH
    source "$EZA_ALIAS_FILE" || exit
    [[ $before_aliases == "$(alias ls l ll la lla lfull lt ltt ltl ld ltd lg lgt lrepo lnew lold lsize ldu lext lf)" &&
       $before_base == ${(j:|:)EZA_BASE} && $before_long == ${(j:|:)EZA_LONG} && $before_path == $PATH ]]'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "lnew orders newest first" {
  run_alias 'lnew sort-files'
  [ "$status" -eq 0 ]
  [[ "$output" == *zeta-new.py*middle.md*alpha-old.txt* ]]
}

@test "lold orders oldest first" {
  run_alias 'lold sort-files'
  [ "$status" -eq 0 ]
  [[ "$output" == *alpha-old.txt*middle.md*zeta-new.py* ]]
}

@test "lsize orders largest first" {
  run_alias 'lsize sort-files'
  [ "$status" -eq 0 ]
  [[ "$output" == *zeta-new.py*middle.md*alpha-old.txt* ]]
}

@test "ldu uses recursive sizes and orders largest directory first" {
  run_alias 'ldu size-dirs'
  [ "$status" -eq 0 ]
  [[ "$output" == *large-dir*small-dir* ]]
}

@test "lext orders by extension" {
  run_alias 'lext sort-files'
  [ "$status" -eq 0 ]
  [[ "$output" == *middle.md*zeta-new.py*alpha-old.txt* ]]
}

@test "ll shows the long header and hidden files while lla omits hidden files" {
  run_alias 'll .'
  [ "$status" -eq 0 ]
  [[ "$output" == *Permissions*Size*Name* ]]
  [[ "$output" == *.hidden-file* && "$output" == *.hidden-dir* ]]
  run_alias 'lla .'
  [ "$status" -eq 0 ]
  [[ "$output" == *Permissions* && "$output" != *.hidden-file* ]]
}

@test "lf only lists files and ld only lists directories" {
  run_alias 'lf .'
  [ "$status" -eq 0 ]
  [[ "$output" == *alpha-old.txt* && "$output" != *visible-dir* && "$output" != *.hidden-file* ]]
  run_alias 'ld .'
  [ "$status" -eq 0 ]
  [[ "$output" == *visible-dir* && "$output" != *alpha-old.txt* && "$output" != *.hidden-dir* ]]
}

@test "lt and ltt have depths two and three and ltd omits files" {
  run_alias 'lt visible-dir'
  [ "$status" -eq 0 ]
  [[ "$output" == *grandchild-dir* && "$output" != *bottom.txt* ]]
  run_alias 'ltt visible-dir'
  [ "$status" -eq 0 ]
  [[ "$output" == *bottom.txt* ]]
  run_alias 'ltd visible-dir'
  [ "$status" -eq 0 ]
  [[ "$output" == *grandchild-dir* && "$output" != *bottom.txt* ]]
}

@test "Git aliases display status and lgt respects gitignore" {
  run_alias 'lg repository'
  [ "$status" -eq 0 ]
  [[ "$output" == *Git* && "$output" == *tracked.txt* && "$output" == *untracked.txt* ]]
  run_alias 'lgt repository'
  [ "$status" -eq 0 ]
  [[ "$output" == *tracked.txt* && "$output" != *ignored.txt* ]]
  run_alias 'lrepo .'
  [ "$status" -eq 0 ]
  [[ "$output" == *Git* && "$output" == *repository* && "$output" == *visible-dir* ]]
}

@test "lfull accepts extended attributes and ordinary ls options remain usable" {
  run_alias 'lfull .'
  [ "$status" -eq 0 ]
  [[ "$output" == *Group* && "$output" == *Links* && "$output" == *file-link* ]]
  run_alias 'ls -lah sort-files'
  [ "$status" -eq 0 ]
  [[ "$output" == *alpha-old.txt* && "$output" == *zeta-new.py* ]]
}
