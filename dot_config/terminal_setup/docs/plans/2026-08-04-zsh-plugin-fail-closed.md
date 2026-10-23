# Fail-Closed Zsh Plugin Loading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Do not dispatch subagents for this workspace because the active repositories contain overlapping uncommitted user changes.

**Goal:** Ensure an incomplete, corrupt, or hanging optional Zsh plugin is skipped before it can break interactive typing, while preserving healthy plugin behavior and surfacing regressions during `update-all` validation.

**Architecture:** A chezmoi-managed Zsh helper validates each optional plugin in a bounded clean interactive child Zsh and forces delayed autoload stubs to resolve before sourcing the plugin into the interactive parent. Existing refresh validation treats a skipped plugin as degraded, and `update-all` invokes that existing refresh check after package changes. Homebrew remains the sole package owner.

**Tech Stack:** Zsh 5.9, system Perl watchdog, Bats, chezmoi 2.72, Homebrew, Git.

## Global Constraints

- Preserve all existing uncommitted changes in both repositories.
- Do not commit, push, publish, or modify unrelated files.
- Do not print or persist secrets or raw third-party plugin output.
- Optional plugin failure must leave a usable interactive shell with native completion.
- Preflight must finish or time out within two seconds per plugin.
- Apply only explicitly changed chezmoi targets.

---

### Task 1: Optional plugin loader regression tests

**Files:**
- Create: `/Users/sam/.local/share/chezmoi/dot_config/terminal_setup/tests/zsh-optional-plugin-loader.bats`
- Test target: `/Users/sam/.local/share/chezmoi/dot_zshrc.d/dot_optional-plugin-loader.zsh`

**Interfaces:**
- Consumes: `/bin/zsh`, `/usr/bin/perl`, temporary plugin fixtures.
- Produces: executable behavioral contract for `terminal_preflight_zsh_plugin`, `terminal_source_optional_zsh_plugin`, and top-level `--check`.

- [ ] **Step 1: Write the failing fixture tests**

Create Bats fixtures under `BATS_TEST_TMPDIR` and tests equivalent to:

```bash
@test "healthy plugin preflights and loads into the parent" {
  printf '%s\n' 'typeset -g TEST_PLUGIN_LOADED=1' >"$PLUGIN"
  run /bin/zsh -fc 'source "$1"; terminal_source_optional_zsh_plugin demo "$2"; print -r -- "$TEST_PLUGIN_LOADED"' zsh "$LOADER" "$PLUGIN"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\n1' || "$output" == 1 ]]
}

@test "missing delayed autoload dependency is rejected before parent mutation" {
  printf '%s\n' 'typeset -g PARENT_MUTATED=1' 'fpath=( "$PLUGIN_ROOT/missing" $fpath )' 'autoload -Uz delayed-demo' >"$PLUGIN"
  run env PLUGIN_ROOT="$TEST_ROOT" /bin/zsh -fc 'source "$1"; terminal_source_optional_zsh_plugin demo "$2"; print -r -- "mutated=${PARENT_MUTATED:-0}"' zsh "$LOADER" "$PLUGIN"
  [ "$status" -eq 0 ]
  [[ "$output" == *"optional plugin skipped: demo"* ]]
  [[ "$output" == *"mutated=0"* ]]
}
```

Also cover an available delayed function, missing path, valid package-manager
symlink resolution, broken-link rejection, syntax error, nonzero source,
two-second timeout, and one failed plugin followed by a healthy plugin.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
bats --print-output-on-failure dot_config/terminal_setup/tests/zsh-optional-plugin-loader.bats
```

Expected: FAIL because `dot_optional-plugin-loader.zsh` does not exist.

---

### Task 2: Bounded fail-closed loader and startup integration

**Files:**
- Create: `/Users/sam/.local/share/chezmoi/dot_zshrc.d/dot_optional-plugin-loader.zsh`
- Modify: `/Users/sam/.local/share/chezmoi/dot_zshrc`
- Test: `/Users/sam/.local/share/chezmoi/dot_config/terminal_setup/tests/zsh-optional-plugin-loader.bats`

**Interfaces:**
- Consumes: `terminal_preflight_zsh_plugin NAME ABSOLUTE_PATH`.
- Produces: `terminal_source_optional_zsh_plugin NAME ABSOLUTE_PATH`, `TERMINAL_ZSH_PLUGINS_LOADED`, and `TERMINAL_ZSH_PLUGINS_SKIPPED`.

- [ ] **Step 1: Implement the isolated probe and watchdog**

The helper must validate arguments and execute this child-Zsh behavior under a
two-second Perl alarm:

```zsh
source "$1" || exit
for name value in "${(@kv)functions}"; do
  [[ "$value" == "builtin autoload -X"* ]] || continue
  autoload +X -- "$name" || exit
done
```

The Perl supervisor must fork, redirect child stdout/stderr to `/dev/null`,
`exec` the resolved Zsh with `-dfc`, return its exit status, and on alarm send
TERM, wait 100 milliseconds, send KILL if necessary, reap, and return 124.

- [ ] **Step 2: Implement fail-closed parent loading**

On preflight success, source the plugin and append its name to
`TERMINAL_ZSH_PLUGINS_LOADED`. On any failure, do not source it, append the name
to `TERMINAL_ZSH_PLUGINS_SKIPPED`, print exactly one normalized diagnostic, and
return success so startup continues.

- [ ] **Step 3: Integrate startup ordering**

In `dot_zshrc`, source the helper from
`$HOME/.zshrc.d/.optional-plugin-loader.zsh`. Load `zsh-autocomplete` through it
before Oh My Zsh. Load autosuggestions and syntax highlighting through it after
Oh My Zsh. If the helper itself is unavailable, print one diagnostic and
continue with Oh My Zsh/native completion. Remove loader functions after setup.

- [ ] **Step 4: Run focused tests and syntax checks**

Run:

```bash
/bin/zsh -n dot_zshrc dot_zshrc.d/dot_optional-plugin-loader.zsh
bats --print-output-on-failure dot_config/terminal_setup/tests/zsh-optional-plugin-loader.bats
```

Expected: all pass with no leaked child output or lingering timeout process.

---

### Task 3: Refresh preflight integration

**Files:**
- Modify: `/Users/sam/.local/share/chezmoi/dot_local/bin/executable_zsh-refresh-current`
- Modify: `/Users/sam/.local/share/chezmoi/dot_config/terminal_setup/tests/herdr-refresh.bats`
- Modify: `/Users/sam/.local/share/chezmoi/dot_config/terminal_setup/README.md`

**Interfaces:**
- Consumes: `~/.zshrc.d/.optional-plugin-loader.zsh` and existing login-shell stderr invariant.
- Produces: explicit helper syntax validation and documented fail-closed recovery behavior.

- [ ] **Step 1: Add a failing refresh test**

Add a test fixture with a syntax-invalid `.optional-plugin-loader.zsh`, execute
`zsh-refresh-current --check`, and assert nonzero status plus
`preflight failed (startup syntax)`.

- [ ] **Step 2: Verify RED**

Run:

```bash
bats --filter 'optional plugin loader' dot_config/terminal_setup/tests/herdr-refresh.bats
```

Expected: FAIL because the worker does not inspect the helper.

- [ ] **Step 3: Add explicit syntax validation**

Append the optional loader path to the worker's syntax phase when it exists. Do
not source it there; the existing isolated login-shell phase owns runtime
validation and stderr rejection.

- [ ] **Step 4: Document behavior and verify**

Document that package failures skip the plugin, retain a usable shell, and make
`zsh-refresh-current --check` fail with a concise diagnostic. Run focused Bats,
`shellcheck`, `shfmt -d`, and `zsh -n` on the modified worker.

---

### Task 4: Post-update shell health gate

**Files:**
- Modify: `/Users/sam/Projects/star-setup/scripts/update-all.zsh`
- Modify: `/Users/sam/Projects/star-setup/scripts/test/update-all/probes.bats`
- Modify: `/Users/sam/Projects/star-setup/Docs/Update-All.md`

**Interfaces:**
- Consumes: executable `$HOME/.local/bin/zsh-refresh-current --check`.
- Produces: a required final shell-health validation when the worker exists; a clear skip when it does not.

- [ ] **Step 1: Add failing validation tests**

Use a fixture worker that records argv and returns configurable status. Assert
that `validation_section` invokes exactly `--check`, records success as healthy,
and records a nonzero result as a validation failure without attempting repair.

- [ ] **Step 2: Verify RED**

Run:

```bash
bats --filter 'Zsh refresh health' scripts/test/update-all/probes.bats
```

Expected: FAIL because validation does not invoke the worker.

- [ ] **Step 3: Add the narrow validation hook**

Resolve only `$HOME/.local/bin/zsh-refresh-current`. If it is executable, call
`validate_required "Shell" "zsh-refresh-current --check" "$worker" --check`.
Otherwise emit a skip explaining that managed shell health cannot be checked.
Do not alter Homebrew rollback or recovery policy.

- [ ] **Step 4: Verify focused update-all behavior**

Run the filtered Bats test, `zsh -n scripts/update-all.zsh`, and ShellCheck on
the script. Inspect the scoped diff to confirm existing OMP and assurance edits
are unchanged.

---

### Task 5: Official package restoration and targeted deployment

**Files:**
- Apply: `/Users/sam/.zshrc`
- Apply: `/Users/sam/.zshrc.d/.optional-plugin-loader.zsh`
- Apply: `/Users/sam/.local/bin/zsh-refresh-current`
- Package: Homebrew `zsh-autocomplete`

**Interfaces:**
- Consumes: current Homebrew formula metadata and reviewed chezmoi source.
- Produces: Homebrew-owned supported keg with no untracked dependency clone, plus live fail-closed startup.

- [ ] **Step 1: Preview and apply only changed chezmoi targets**

Run scoped `chezmoi diff`, apply the three named targets, and confirm the live
files match `chezmoi cat` output. Do not run a broad apply.

- [ ] **Step 2: Verify the guard before package mutation**

Create a disposable broken plugin fixture and invoke the installed loader's
`--check`; confirm nonzero. Start an isolated shell using a fixture `.zshrc`
that loads the broken plugin and confirm a marker command still executes.

- [ ] **Step 3: Refresh and restore from current Homebrew metadata**

Run `brew update`, confirm the official stable formula version, and reinstall
`zsh-autocomplete`. If the stable package fails the deployed preflight, inspect
Homebrew's `--HEAD` fetch and use it only when its resolved commit is an exact
upstream release tag and its submodules are initialized. Confirm the final
Homebrew receipt, installed dependency files, and plugin preflight; never patch
the Cellar manually.

- [ ] **Step 4: Run complete verification**

Run:

```bash
bats --print-output-on-failure dot_config/terminal_setup/tests/zsh-optional-plugin-loader.bats
bats --print-output-on-failure dot_config/terminal_setup/tests/zsh-module-loader.bats
bats --print-output-on-failure dot_config/terminal_setup/tests/herdr-refresh.bats
zsh-refresh-current --check
just update-all-test
git diff --check
```

Then start a pseudo-terminal login Zsh, type a `codex resume …` prefix without
executing it, and confirm there are no plugin errors and completion remains
responsive. Report exact changed files, package version, verification results,
remaining risks, and the untouched pre-existing worktree changes.
