#!/usr/bin/env bats

load lib/source-root

setup() {
  TS_SOURCE_ROOT="$(terminal_setup_source_root)" ||
    TS_SOURCE_ROOT="${TS_SOURCE_ROOT}"
  export TS_SOURCE_ROOT
  export TEST_ROOT
  TEST_ROOT="$(mktemp -d "${BATS_TEST_TMPDIR}/repo-audit.XXXXXX")"
  export TEST_REPO="${TEST_ROOT}/repo with spaces"
  export FAKE_BIN="${TEST_ROOT}/bin"
  export CALL_LOG="${TEST_ROOT}/calls.log"
  export REPO_AUDIT_BIN="${REPO_AUDIT_BIN:-${TS_SOURCE_ROOT}/dot_local/private_bin/executable_repo-audit}"

  mkdir -p "$TEST_REPO" "$FAKE_BIN"
  : >"$CALL_LOG"
  git -C "$TEST_REPO" init -q
  git -C "$TEST_REPO" config user.email "fixture@example.invalid"
  git -C "$TEST_REPO" config user.name "Fixture"
  printf '%s\n' '# Fixture' >"${TEST_REPO}/README.md"
  git -C "$TEST_REPO" add README.md
  git -C "$TEST_REPO" commit -qm "fixture"

  for tool in actionlint typos shellcheck shfmt tofu tflint qsv lychee hurl wt dive trip kubeconform; do
    make_fake_tool "$tool"
  done
}

teardown() {
  if [[ -n "${TEST_ROOT:-}" && -d "$TEST_ROOT" ]]; then
    case "$TEST_ROOT" in
      "${BATS_TEST_TMPDIR}/repo-audit."*) /bin/rm -rf -- "$TEST_ROOT" ;;
    esac
  fi
}

make_fake_tool() {
  local tool="$1"
  printf '%s\n' \
    '#!/bin/sh' \
    'tool=${0##*/}' \
    'printf "%s" "$tool" >>"$CALL_LOG"' \
    'for arg in "$@"; do printf "\\t%s" "$arg" >>"$CALL_LOG"; done' \
    'printf "\\n" >>"$CALL_LOG"' \
    'if [ "${FAIL_TOOL:-}" = "$tool" ]; then exit 7; fi' \
    'exit 0' >"${FAKE_BIN}/${tool}"
  chmod +x "${FAKE_BIN}/${tool}"
}

commit_fixture() {
  git -C "$TEST_REPO" add .
  git -C "$TEST_REPO" commit -qm "add fixture files"
}

@test "help is successful and documents the non-mutating boundary" {
  run "$REPO_AUDIT_BIN" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: repo-audit [PATH]"* ]]
  [[ "$output" == *"does not execute Hurl"* ]]
}

@test "a non-Git directory fails with an actionable error" {
  local plain_dir="${TEST_ROOT}/not a repository"
  mkdir -p "$plain_dir"

  run "$REPO_AUDIT_BIN" "$plain_dir"

  [ "$status" -eq 2 ]
  [[ "$output" == *"not inside a Git work tree"* ]]
}

@test "applicable local checks run for tracked files and paths with spaces" {
  local audit_output
  local expected_repo
  mkdir -p \
    "${TEST_REPO}/.github/workflows" \
    "${TEST_REPO}/scripts" \
    "${TEST_REPO}/infra" \
    "${TEST_REPO}/api" \
    "${TEST_REPO}/k8s"
  printf '%s\n' 'name: fixture' >"${TEST_REPO}/.github/workflows/ci.yml"
  printf '%s\n' '#!/bin/sh' 'printf "%s\\n" fixture' >"${TEST_REPO}/scripts/check.sh"
  printf '%s\n' 'terraform {}' >"${TEST_REPO}/infra/main.tf"
  printf '%s\n' 'name,value' 'fixture,1' >"${TEST_REPO}/data.csv"
  printf '%s\n' 'GET https://example.invalid' >"${TEST_REPO}/api/check.hurl"
  printf '%s\n' 'FROM scratch' >"${TEST_REPO}/Dockerfile"
  printf '%s\n' 'apiVersion: v1' 'kind: ConfigMap' >"${TEST_REPO}/k8s/configmap.yaml"
  commit_fixture
  expected_repo="$(git -C "$TEST_REPO" rev-parse --show-toplevel)"

  run env PATH="${FAKE_BIN}:/opt/homebrew/bin:/usr/bin:/bin" "$REPO_AUDIT_BIN" "$TEST_REPO"

  [ "$status" -eq 0 ]
  audit_output="$output"
  [[ "$audit_output" == *"Repository: ${expected_repo}"* ]]
  for tool in actionlint typos shellcheck shfmt tofu tflint qsv lychee; do
    run grep -q "^${tool}" "$CALL_LOG"
    [ "$status" -eq 0 ]
  done
  for tool in hurl wt dive trip kubeconform; do
    run grep -q "^${tool}" "$CALL_LOG"
    [ "$status" -ne 0 ]
  done
  [[ "$audit_output" == *"Hurl files detected; execution remains manual"* ]]
  [[ "$audit_output" == *"Kubernetes YAML detected; schema validation remains manual"* ]]
  [[ "$audit_output" == *"Docker files detected; image analysis requires an explicit image"* ]]
}

@test "untracked workflow files do not trigger actionlint" {
  mkdir -p "${TEST_REPO}/.github/workflows"
  printf '%s\n' 'name: untracked' >"${TEST_REPO}/.github/workflows/untracked.yml"

  run env PATH="${FAKE_BIN}:/opt/homebrew/bin:/usr/bin:/bin" "$REPO_AUDIT_BIN" "$TEST_REPO"

  [ "$status" -eq 0 ]
  run grep -q '^actionlint' "$CALL_LOG"
  [ "$status" -ne 0 ]
}

@test "missing optional tools are skips rather than crashes" {
  run env PATH="/usr/bin:/bin" "$REPO_AUDIT_BIN" "$TEST_REPO"

  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP"* ]]
  [[ "$output" == *"typos is not installed"* ]]
}

@test "a failed check produces failure after remaining checks run" {
  export FAIL_TOOL=typos

  run env PATH="${FAKE_BIN}:/opt/homebrew/bin:/usr/bin:/bin" FAIL_TOOL="$FAIL_TOOL" "$REPO_AUDIT_BIN" "$TEST_REPO"

  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL"* ]]
  [[ "$output" == *"1 failed"* ]]
  run grep -q '^lychee' "$CALL_LOG"
  [ "$status" -eq 0 ]
}
