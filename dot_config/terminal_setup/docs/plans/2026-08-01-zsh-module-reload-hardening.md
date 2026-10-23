# Zsh Module Reload Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `refresh` prove that every intended Zsh module is present, safe, and loaded in deterministic order while removing local plaintext token remnants and reconciling chezmoi with the newer live configuration.

**Architecture:** A hidden data-only manifest defines module order, and one Zsh loader owns manifest validation plus module sourcing. The refresh worker invokes that same loader in validation-only mode before syntax and runtime startup checks. Chezmoi owns the loader, manifest, and all active non-secret modules; Keychain remains the credential source.

**Tech Stack:** Zsh 5.9, Bash, Bats, chezmoi 2.71.1, macOS `security(1)`, ShellCheck, shfmt, Gitleaks, GitHub Actions.

## Post-review hardening

Implementation review identified three cross-cutting requirements that are
part of the delivered scope:

- reject symlink modules and report a module that returns nonzero before
  stopping the remaining load sequence;
- remove command/cwd diagnostic logging, retain only private timestamp/latency
  records, and delete the legacy plaintext logs; and
- make UID/mode validation portable across BSD and GNU `stat`, run the real
  managed inventory test, include all production scripts and `.zshenv` in
  static analysis, and exercise the workflow on Ubuntu 24.04.

These changes preserve the original architecture: there is still one manifest,
one loader contract, no wildcard auto-sourcing, and no new runtime dependency.

## Global Constraints

- Preserve the current module order and Herdr pane-selection behavior.
- Never auto-source arbitrary `*.zsh` files.
- Never print, log, commit, or pass credential values in command arguments.
- Do not rotate or revoke the NTFY token while external consumers are unknown.
- Do not commit, push, or rewrite Git history without explicit user approval.
- Use exact chezmoi targets; never run an unscoped `chezmoi apply` while drift exists.
- Keep ordinary interactive shells recoverable while making refresh preflight fail closed.
- Add no package dependency; all required tools are already installed.

---

### Task 1: Specify the module-loader contract with failing tests

**Files:**
- Create: `dot_config/terminal_setup/tests/zsh-module-loader.bats`
- Modify: `.github/workflows/terminal-checks.yml`

**Interfaces:**
- Consumes: `MODULE_LOADER` path, a module directory, and a `.module-order` manifest.
- Produces: executable contract `zsh .module-loader.zsh --validate MODULE_DIR MANIFEST`; sourced function `terminal_load_zsh_modules MODULE_DIR MANIFEST`.

- [ ] **Step 1: Add isolated Bats fixtures**

Create a temporary module directory and call the future loader through real
`/bin/zsh`. Use module fixtures that append their names to `LOAD_LOG`; never
source workstation modules in the test process.

```bash
setup() {
  export TEST_ROOT
  TEST_ROOT="$(mktemp -d "${BATS_TEST_TMPDIR}/zsh-modules.XXXXXX")"
  export MODULE_DIR="${TEST_ROOT}/.zshrc.d"
  export MANIFEST="${MODULE_DIR}/.module-order"
  export LOAD_LOG="${TEST_ROOT}/load.log"
  export MODULE_LOADER="${MODULE_LOADER:-${BATS_TEST_DIRNAME}/../../../dot_zshrc.d/dot_module-loader.zsh}"
  mkdir -p "$MODULE_DIR"
  : >"$LOAD_LOG"
}
```

- [ ] **Step 2: Add precise behavior tests**

Cover ordered loading, validation-only non-execution, missing manifest,
malformed basename, duplicate entry, missing listed file, and unlisted on-disk
module. The failure cases must assert that `LOAD_LOG` remains empty.

```bash
@test "loader sources every listed module in manifest order" {
  printf '%s\n' 'print -r -- first >> "$LOAD_LOG"' >"${MODULE_DIR}/first.zsh"
  printf '%s\n' 'print -r -- second >> "$LOAD_LOG"' >"${MODULE_DIR}/second.zsh"
  printf '%s\n' first.zsh second.zsh >"$MANIFEST"

  run env LOAD_LOG="$LOAD_LOG" /bin/zsh -fc \
    'source "$1"; terminal_load_zsh_modules "$2" "$3"' \
    zsh "$MODULE_LOADER" "$MODULE_DIR" "$MANIFEST"

  [ "$status" -eq 0 ]
  [ "$(cat "$LOAD_LOG")" = $'first\nsecond' ]
}

@test "validation rejects an unlisted module before sourcing anything" {
  printf '%s\n' 'print -r -- listed >> "$LOAD_LOG"' >"${MODULE_DIR}/listed.zsh"
  printf '%s\n' 'print -r -- orphan >> "$LOAD_LOG"' >"${MODULE_DIR}/orphan.zsh"
  printf '%s\n' listed.zsh >"$MANIFEST"

  run /bin/zsh "$MODULE_LOADER" --validate "$MODULE_DIR" "$MANIFEST"

  [ "$status" -ne 0 ]
  [[ "$output" == *"unlisted module: orphan.zsh"* ]]
  [ ! -s "$LOAD_LOG" ]
}
```

- [ ] **Step 3: Register the suite in CI**

Add this line alongside the existing Bats invocations:

```bash
bats --print-output-on-failure dot_config/terminal_setup/tests/zsh-module-loader.bats
```

- [ ] **Step 4: Run the new suite and verify the expected red state**

Run:

```bash
bats --print-output-on-failure dot_config/terminal_setup/tests/zsh-module-loader.bats
```

Expected: FAIL because `dot_zshrc.d/dot_module-loader.zsh` does not exist.

- [ ] **Step 5: Review the focused diff without committing**

Run `git diff --check` and `git diff -- .github/workflows/terminal-checks.yml dot_config/terminal_setup/tests/zsh-module-loader.bats`. Do not commit.

---

### Task 2: Implement one fail-closed loader and manifest

**Files:**
- Create: `dot_zshrc.d/dot_module-loader.zsh`
- Create: `dot_zshrc.d/dot_module-order`
- Modify: `dot_zshrc`
- Reconcile: `dot_zshenv`
- Add: the 11 currently unmanaged active modules under `dot_zshrc.d/`; preserve private mode for `sam-wizard.zsh`

**Interfaces:**
- Consumes: `terminal_validate_zsh_modules MODULE_DIR MANIFEST` and the line-oriented manifest contract from Task 1.
- Produces: `reply`, an ordered Zsh array of validated absolute module paths; `terminal_load_zsh_modules`, which sources that array only after complete validation.

- [ ] **Step 1: Reconcile the current live startup files into source state**

First prove that neither live file contains a literal token with a redacted
Gitleaks scan, then use chezmoi's supported reverse-sync command:

```bash
gitleaks dir --no-banner --redact=100 "$HOME/.zshrc"
gitleaks dir --no-banner --redact=100 "$HOME/.zshenv"
chezmoi re-add "$HOME/.zshrc" "$HOME/.zshenv"
```

Expected: scans exit `0`; source files now represent the newer live targets.

- [ ] **Step 2: Implement the data-only manifest**

Create `dot_zshrc.d/dot_module-order` with exactly this order:

```text
sam-wizard.zsh
fastfetch.zsh
herdr-sidebar-context.zsh
update-all.zsh
pretty-tools.zsh
tuxedo.zsh
herdr-refresh.zsh
prompt-latency-probe.zsh
tailscale.zsh
tailscale-completions.zsh
remote-access.zsh
screensaver.zsh
```

- [ ] **Step 3: Implement the shared Zsh loader**

Create `dot_zshrc.d/dot_module-loader.zsh` with these public entry points and
validation order:

```zsh
_terminal_zsh_module_error() {
  print -u2 -r -- "zsh-module-loader: $*"
}

terminal_validate_zsh_modules() {
  emulate -L zsh
  setopt local_options extended_glob no_aliases no_glob_dots

  local module_dir="$1"
  local manifest="$2"
  local module_name module_path disk_path
  local -A seen
  local -a modules
  reply=()

  [[ -d "$module_dir" ]] || {
    _terminal_zsh_module_error "module directory unavailable: $module_dir"
    return 1
  }
  [[ -f "$manifest" && -r "$manifest" ]] || {
    _terminal_zsh_module_error "manifest unavailable: $manifest"
    return 1
  }

  while IFS= read -r module_name || [[ -n "$module_name" ]]; do
    [[ -z "$module_name" || "$module_name" == \#* ]] && continue
    [[ "$module_name" == [A-Za-z0-9][A-Za-z0-9._-]#.zsh ]] || {
      _terminal_zsh_module_error "invalid module name: $module_name"
      return 1
    }
    (( ${+seen[$module_name]} == 0 )) || {
      _terminal_zsh_module_error "duplicate module: $module_name"
      return 1
    }
    module_path="${module_dir}/${module_name}"
    [[ -f "$module_path" ]] || {
      _terminal_zsh_module_error "listed module unavailable: $module_name"
      return 1
    }
    seen[$module_name]=1
    modules+=("$module_path")
  done <"$manifest"

  for disk_path in "$module_dir"/*.zsh(N); do
    module_name="${disk_path:t}"
    (( ${+seen[$module_name]} )) || {
      _terminal_zsh_module_error "unlisted module: $module_name"
      return 1
    }
  done

  reply=("${modules[@]}")
}

terminal_load_zsh_modules() {
  terminal_validate_zsh_modules "$@" || return
  local module_path
  for module_path in "${reply[@]}"; do
    source "$module_path" || return
  done
}
```

Add an executed-script branch that accepts exactly
`--validate MODULE_DIR MANIFEST`, calls `terminal_validate_zsh_modules`, and
returns `2` for any other arguments. When sourced, it must define functions but
perform no validation or loading by itself.

- [ ] **Step 4: Replace the inline `.zshrc` list with the loader call**

Use `${ZDOTDIR:-$HOME}` for the module root, require the hidden loader, call
`terminal_load_zsh_modules`, and unset helper variables and functions after a
successful load. Emit one concise stderr error if the loader itself is missing.

```zsh
_zshrc_root="${ZDOTDIR:-$HOME}"
_zshrc_module_dir="${_zshrc_root}/.zshrc.d"
_zshrc_module_loader="${_zshrc_module_dir}/.module-loader.zsh"
_zshrc_module_manifest="${_zshrc_module_dir}/.module-order"
if [[ -r "$_zshrc_module_loader" ]]; then
  source "$_zshrc_module_loader" &&
    terminal_load_zsh_modules "$_zshrc_module_dir" "$_zshrc_module_manifest"
else
  print -u2 -r -- "zsh-module-loader: loader unavailable: $_zshrc_module_loader"
fi
unset _zshrc_root _zshrc_module_dir _zshrc_module_loader _zshrc_module_manifest
unfunction terminal_load_zsh_modules terminal_validate_zsh_modules \
  _terminal_zsh_module_error 2>/dev/null
```

- [ ] **Step 5: Add every active non-secret module to chezmoi explicitly**

Run `chezmoi add` with the 11 unmanaged paths one by one; do not pass the
directory and do not include `secrets.zsh`. Confirm that `sam-wizard.zsh` maps
to a `private_` source path and that all others retain their current target
modes.

- [ ] **Step 6: Run the loader suite and Zsh syntax checks**

Run:

```bash
bats --print-output-on-failure dot_config/terminal_setup/tests/zsh-module-loader.bats
zsh -n dot_zshrc dot_zshrc.d/*.zsh
```

Expected: all tests pass and syntax exits `0`.

- [ ] **Step 7: Review the focused diff without committing**

Inspect source paths, permissions, and `git diff --check`. Confirm that no
credential value appears in `git diff`. Do not commit.

---

### Task 3: Integrate manifest validation into refresh preflight

**Files:**
- Modify: `dot_local/bin/executable_zsh-refresh-current`
- Modify: `dot_config/terminal_setup/tests/herdr-refresh.bats`

**Interfaces:**
- Consumes: `.module-loader.zsh --validate MODULE_DIR MANIFEST` from Task 2.
- Produces: a failed preflight before runtime startup when module inventory is inconsistent.

- [ ] **Step 1: Add failing worker integration tests**

Create isolated `ZDOTDIR` fixtures containing the real loader plus a manifest.
Add tests proving that `--check` accepts a complete inventory and rejects an
unlisted module before the runtime completion marker.

```bash
@test "worker rejects an unlisted Zsh module" {
  local zdotdir="${TEST_ROOT}/module-drift"
  mkdir -p "${zdotdir}/.zshrc.d"
  cp "$MODULE_LOADER_SOURCE" "${zdotdir}/.zshrc.d/.module-loader.zsh"
  printf '%s\n' listed.zsh >"${zdotdir}/.zshrc.d/.module-order"
  : >"${zdotdir}/.zshrc.d/listed.zsh"
  : >"${zdotdir}/.zshrc.d/orphan.zsh"
  : >"${zdotdir}/.zshrc"

  run env HOME="$TEST_HOME" ZDOTDIR="$zdotdir" TERM=xterm-256color "$WORKER" --check

  [ "$status" -ne 0 ]
  [[ "$output" == *"unlisted module: orphan.zsh"* ]]
}
```

- [ ] **Step 2: Run the focused tests and verify the expected red state**

Run only the new Bats test filters. Expected: the worker currently reaches only
its generic runtime error path rather than the explicit inventory-validation
stage.

- [ ] **Step 3: Add the preflight validation stage**

Before module syntax checks, collect non-hidden `*.zsh` modules. If any exist,
require `.module-loader.zsh` and `.module-order`, syntax-check the loader, and
run:

```bash
/bin/zsh -f "$module_loader" --validate "$module_dir" "$module_manifest"
```

Append loader diagnostics to the existing private `syntax_log`; set
`syntax_failed=1` on any failure. Keep the current globbed `zsh -n` loop after
inventory validation.

- [ ] **Step 4: Run focused and complete refresh tests**

```bash
bats --print-output-on-failure \
  --filter 'worker (accepts|rejects).*module' \
  dot_config/terminal_setup/tests/herdr-refresh.bats
bats --print-output-on-failure dot_config/terminal_setup/tests/herdr-refresh.bats
```

Expected: all tests pass.

- [ ] **Step 5: Run static checks and review without committing**

```bash
shellcheck -x -- dot_local/bin/executable_zsh-refresh-current
shfmt -d -- dot_local/bin/executable_zsh-refresh-current
git diff --check
```

Do not commit.

---

### Task 4: Remove local plaintext token remnants

**Files:**
- Delete: `~/.zshrc.d/secrets.zsh`
- Sanitize: `~/.zshenv.bak-pre-mise`
- Sanitize: `~/.zsh_history`

**Interfaces:**
- Consumes: existing `NTFY_TOKEN` generic-password item for account `$USER`.
- Produces: no local plaintext copy in the identified shell files; unchanged Keychain item and token value.

- [ ] **Step 1: Reconfirm the safety preconditions without printing values**

Check that the Keychain item exists, a clean login Zsh obtains a non-empty
`NTFY_TOKEN`, and each targeted plaintext file still contains the same token.
All checks print only `present`, `nonempty`, or `contains_current_token=yes`.

- [ ] **Step 2: Remove the exact orphan file**

Delete only `/Users/sam/.zshrc.d/secrets.zsh` after rechecking that it is a
regular, non-symlink file containing only the two expected exports. Do not copy
it to Trash or a backup because that would retain the credential.

- [ ] **Step 3: Mechanically sanitize the backup and history**

Use byte-oriented in-place filtering that never prints matching lines:

```bash
LC_ALL=C perl -ni -e 'print unless /NTFY_TOKEN/' /Users/sam/.zshenv.bak-pre-mise
LC_ALL=C perl -ni -e 'print unless /NTFY_TOKEN/' /Users/sam/.zsh_history
```

Record modes before and after and restore the original restrictive mode if the
mechanical rewrite changes it.

- [ ] **Step 4: Verify removal without exposing the token**

Re-run exact in-memory comparisons against the Keychain value and assert `no`
for all three paths. Also assert that the Keychain value is unchanged and a
clean login shell still exports a non-empty token.

- [ ] **Step 5: Run a live-directory redacted Gitleaks scan**

Scan `.zshenv`, `.zshrc`, `.zshrc.d`, and the sanitized backup with
`--redact=100`. Do not scan or print private shell history contents.

---

### Task 5: Deploy scoped targets, document the workflow, and verify end to end

**Files:**
- Modify: `dot_config/terminal_setup/README.md`
- Apply: `.zshrc`, `.zshenv`, `.zshrc.d/.module-loader.zsh`, `.zshrc.d/.module-order`, the 12 module targets, and `.local/bin/zsh-refresh-current`

**Interfaces:**
- Consumes: all deliverables from Tasks 1-4.
- Produces: a reproducible, documented refresh configuration with source and destination identity.

- [ ] **Step 1: Document module lifecycle and recovery**

Add a README section explaining:

```text
1. Create the module as ~/.zshrc.d/NAME.zsh.
2. Add NAME.zsh once to ~/.zshrc.d/.module-order in the required load order.
3. Run zsh-refresh-current --check.
4. Run refresh-dry.
5. Add/re-add both files to chezmoi and inspect the scoped diff.
```

Document that an unlisted, missing, malformed, or duplicate module blocks
refresh and that arbitrary wildcard auto-loading is intentionally unsupported.

- [ ] **Step 2: Preview only the explicit chezmoi targets**

Run `chezmoi diff` with every changed target listed explicitly. Inspect the
complete output for accidental deletions, stale source, token values, or
unrelated changes. Stop on any unexpected path.

- [ ] **Step 3: Apply only the reviewed targets**

Run `chezmoi apply` with the same explicit target list. Do not run a broad
apply, Git commit, push, or Herdr pane mutation.

- [ ] **Step 4: Run complete repository validation**

```bash
bats --print-output-on-failure dot_config/terminal_setup/tests/zsh-module-loader.bats
bats --print-output-on-failure dot_config/terminal_setup/tests/herdr-refresh.bats
bats --print-output-on-failure dot_config/terminal_setup/tests/refresh-doctor.bats
bats --print-output-on-failure dot_config/terminal_setup/tests/repo-audit.bats
shellcheck -x -- dot_local/bin/executable_herdr-refresh-safe-shell-panes \
  dot_local/bin/executable_refresh-doctor \
  dot_local/bin/executable_repo-audit \
  dot_local/bin/executable_zsh-refresh-current
shfmt -d -- dot_local/bin/executable_herdr-refresh-safe-shell-panes \
  dot_local/bin/executable_refresh-doctor \
  dot_local/bin/executable_repo-audit \
  dot_local/bin/executable_zsh-refresh-current
actionlint
typos
git diff --check
gitleaks git --no-banner --redact=100
```

Expected: every command exits `0` with zero test, lint, format, workflow,
spelling, whitespace, or secret findings.

- [ ] **Step 5: Verify deployed shell behavior**

```bash
/Users/sam/.local/bin/zsh-refresh-current --check
/bin/zsh -lic 'refresh --dry-run --keep-scrollback'
```

Expected: worker exit `0`; dry run exit `0`; no failed panes. Confirm a clean
login shell exposes `refresh`, all 12 module-provided commands expected by the
existing setup, and a non-empty NTFY token without printing any value.

- [ ] **Step 6: Prove source/destination identity and inspect final state**

Use `chezmoi diff` on the explicit targets and require empty output. Then inspect
`git status --short`, the complete Git diff, file modes, and the final module
set. Report changed files, validation evidence, the deliberate no-rotation
decision, and any remaining external-consumer risk. Do not commit or push.
