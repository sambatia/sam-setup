# Herdr Refresh Failure Diagnostics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add bounded, privacy-preserving failure records and a read-only doctor command without changing successful refresh behavior.

**Architecture:** A new `refresh-doctor` executable owns strict record validation, secure atomic persistence, bounded retention, and read-only health reporting. The existing controller records normalized run failures once, while the Zsh wrapper records only an invoking-shell failure that occurs after controller success.

**Tech Stack:** Bash 3.2-compatible shell, Zsh 5.9, Herdr 0.7.5 CLI, jq, Bats 1.14, ShellCheck 0.11, shfmt 3.13, chezmoi 2.71.

## Global Constraints

- Successful and dry-run commands never create journal records.
- Diagnostics are best-effort and never replace the original refresh status.
- Retain only the ten newest controlled `failure-*.json` records.
- Use exact mode `0700` for the journal directory and `0600` for records.
- Persist no commands, output, cwd, environment, session name, pane ID, socket
  path, raw stderr, acknowledgement secret, or temporary path.
- Default `refresh-doctor` is read-only and never runs a pane/server mutation.
- Do not add dependencies, telemetry, scheduling, automatic updates, or server
  restarts.
- Preserve retry, acknowledgement, clear, and shell-replacement semantics.
- Do not submit an upstream issue without explicit approval.

## File Structure

- Create `dot_local/bin/executable_refresh-doctor`: secure record writer,
  bounded retention, record reader, and read-only health checks.
- Create `dot_config/terminal_setup/tests/refresh-doctor.bats`: isolated writer,
  retention, privacy, health, and mutation-boundary tests.
- Modify `dot_local/bin/executable_herdr-refresh-safe-shell-panes`: normalize
  failure reasons and record one failed apply.
- Modify `dot_zshrc.d/herdr-refresh.zsh`: record an invoking-shell worker
  failure after controller success.
- Modify `dot_config/terminal_setup/tests/herdr-refresh.bats`: controller and
  Zsh integration tests.
- Modify `dot_config/terminal_setup/README.md`: document `refresh-doctor`,
  privacy, retention, and operational usage.

---

### Task 1: Secure Diagnostic Record Store

**Files:**
- Create: `dot_local/bin/executable_refresh-doctor`
- Create: `dot_config/terminal_setup/tests/refresh-doctor.bats`

**Interfaces:**
- Consumes: `refresh-doctor --record --component controller|current-shell --reason TOKEN [--reason TOKEN ...] --exit-status N` plus optional nonnegative count flags.
- Produces: one schema-1 JSON file below the XDG state directory, exit `0` after atomic publication and rotation, or exit `2` for invalid input/state.

- [ ] **Step 1: Add record validation and privacy tests**

Create Bats setup with isolated `HOME`, `XDG_STATE_HOME`, and fake `herdr`.
Add tests that reject an unknown component, reason outside
`^[a-z0-9-]{1,64}$`, exit status outside `1..255`, negative/non-numeric
counts, and unknown arguments. Include secret sentinels in fake Herdr stderr,
socket output, environment, and cwd; assert none occur in any record.

- [ ] **Step 2: Run the record tests and verify RED**

Run:

```bash
bats --filter 'record' dot_config/terminal_setup/tests/refresh-doctor.bats
```

Expected: FAIL because `executable_refresh-doctor` does not exist.

- [ ] **Step 3: Implement strict record argument parsing**

Implement Bash 3.2-compatible parsing for:

```text
--component controller|current-shell
--reason [a-z0-9-]{1,64}
--exit-status 1..255
--discovered N
--eligible N
--excluded N
--skipped N
--refreshed N
--failed N
```

Require component, at least one reason, and exit status. Reject all other
input before filesystem mutation. Deduplicate and sort reasons with jq.

- [ ] **Step 4: Implement private state-directory resolution**

Use an absolute `XDG_STATE_HOME` when set. Ignore a relative value and fall
back to the absolute `$HOME/.local/state`. Refuse a non-absolute fallback.
Create only the final `herdr-refresh` directory, set mode `0700`, and verify it
is a real non-symlink directory owned by the current UID with exact mode
`0700`.

- [ ] **Step 5: Implement atomic schema-1 publication**

Set `umask 077`. Write JSON with jq to a hidden `mktemp` file in the validated
directory, set and verify mode `0600`, then atomically hard-link it to a
controlled `failure-YYYYmmddTHHMMSSZ-PID-RANDOM.json` name. Remove the
temporary link. Obtain only a strictly matched semantic version from
`herdr --version`; otherwise store `"unavailable"`.

- [ ] **Step 6: Implement bounded retention**

List only top-level regular `failure-*.json` files, sort their controlled names
newest first, and remove entries after the tenth. Never follow symlinks or
delete a nonmatching name.

- [ ] **Step 7: Run record tests and verify GREEN**

Run:

```bash
bats --filter 'record|retention|XDG|permissions|privacy' \
  dot_config/terminal_setup/tests/refresh-doctor.bats
```

Expected: all selected tests PASS with ten records retained after eleven
writes.

---

### Task 2: Read-only Doctor

**Files:**
- Modify: `dot_local/bin/executable_refresh-doctor`
- Modify: `dot_config/terminal_setup/tests/refresh-doctor.bats`

**Interfaces:**
- Consumes: `refresh-doctor` with no arguments.
- Produces: a sanitized health report and exit `0` only when dependencies,
  Herdr status, quiet controller dry-run, current-shell check, and latest
  record validation succeed.

- [ ] **Step 1: Add read-only boundary and report tests**

Fake `herdr --version`, `herdr status`, `pane list`, and `pane process-info`.
Fake the controller and worker with call logging. Assert default doctor mode:

- calls `herdr status`;
- calls the controller only with `--dry-run`, with output suppressed by the
  doctor;
- calls the worker only with `--check`;
- never logs `pane run`, `pane send-text`, `pane send-keys`, server stop,
  update, clear, or shell exec;
- excludes the fake socket path, pane ID, cwd, raw stderr, and environment
  sentinel; and
- prints labeled client/server, pane preflight, shell preflight, and latest
  failure results.

- [ ] **Step 2: Run doctor tests and verify RED**

Run:

```bash
bats --filter 'doctor' dot_config/terminal_setup/tests/refresh-doctor.bats
```

Expected: FAIL because default mode is not implemented.

- [ ] **Step 3: Implement sanitized Herdr status**

Call the supported `herdr --version` and `herdr status` interfaces. Accept and
print only safe keys (`client`, `server`, `update`, `version`, `channel`,
`protocol`, `status`, `compatible`, and `restart_needed`). Explicitly discard
`socket` and all unknown lines. Do not use this human output for mutation or
compatibility decisions.

- [ ] **Step 4: Implement live read-only checks**

Require the controller and worker executables. Run:

```text
herdr-refresh-safe-shell-panes --dry-run
zsh-refresh-current --check
```

Capture and discard raw output. Print only `pane_preflight: ok|failed` and
`shell_preflight: ok|failed`. Accumulate failure state rather than stopping
after the first check.

- [ ] **Step 5: Implement latest-record validation**

Find the newest controlled record without creating the state directory.
Validate regular-file type, no symlink, current UID, mode `0600`, JSON syntax,
schema version, enumerated component, reason tokens, exit status, semantic
version or `unavailable`, timestamp, and nonnegative counts. Print the compact
validated object or `latest_failure: none`; reject unsafe or malformed files.

- [ ] **Step 6: Run doctor tests and verify GREEN**

Run:

```bash
bats --filter 'doctor|latest failure' \
  dot_config/terminal_setup/tests/refresh-doctor.bats
```

Expected: all selected tests PASS, no mutation appears in the call log, and a
failed child check makes the doctor nonzero.

---

### Task 3: Controller Failure Integration

**Files:**
- Modify: `dot_local/bin/executable_herdr-refresh-safe-shell-panes`
- Modify: `dot_config/terminal_setup/tests/herdr-refresh.bats`

**Interfaces:**
- Consumes: executable `$HOME/.local/bin/refresh-doctor --record`.
- Produces: exactly one best-effort controller record for a failed apply and no
  records for help, dry-run, or success.

- [ ] **Step 1: Extend the isolated test home**

Install `executable_refresh-doctor` into the Bats test home and set
`XDG_STATE_HOME` to an isolated absolute directory. Add helpers that count and
validate journal records.

- [ ] **Step 2: Add failing integration tests**

Add tests proving:

- quiet apply success creates no record;
- dry-run failure creates no record;
- permanent acknowledgement timeout creates exactly one controller record
  with reason `acknowledgement-timeout`, exit status `1`, and final counts;
- invalid pane-list schema in apply mode records `pane-schema-invalid` and
  exit status `2`;
- record-writer failure preserves the controller's original output/status;
  and
- record JSON contains none of the injected secret sentinels.

- [ ] **Step 3: Run controller integration tests and verify RED**

Run:

```bash
bats --filter 'diagnostic record|record writer' \
  dot_config/terminal_setup/tests/herdr-refresh.bats
```

Expected: FAIL because the controller does not invoke the writer.

- [ ] **Step 4: Add normalized failure-reason collection**

Initialize counters before discovery and keep a sentinel-based reason array.
Add a helper that accepts only internal normalized reason constants. Append a
reason whenever a terminal controller failure is emitted. Keep all existing
human diagnostics unchanged.

- [ ] **Step 5: Add one best-effort record call**

For apply mode only, invoke `refresh-doctor --record` once before each terminal
exit path, passing the unique reasons, original exit status, and current
counters. A successful record prints:

```text
herdr-refresh: saved a redacted failure record; run refresh-doctor
```

If the helper is absent or fails, print:

```text
herdr-refresh: could not save the redacted failure record
```

Return the original controller status in both cases.

- [ ] **Step 6: Run controller integration and full refresh tests**

Run:

```bash
bats --print-output-on-failure \
  dot_config/terminal_setup/tests/herdr-refresh.bats
```

Expected: all tests PASS and existing successful quiet output remains empty.

---

### Task 4: Invoking-shell Failure Integration

**Files:**
- Modify: `dot_zshrc.d/herdr-refresh.zsh`
- Modify: `dot_config/terminal_setup/tests/herdr-refresh.bats`

**Interfaces:**
- Consumes: controller success followed by a nonzero local worker result.
- Produces: one best-effort `current-shell` record with reason
  `current-shell-refresh-failed`; returns the worker's unchanged status.

- [ ] **Step 1: Add failing Zsh integration tests**

Extend the fake diagnostic executable to record calls. Prove a local worker
failure after controller success calls:

```text
refresh-doctor --record --component current-shell
  --reason current-shell-refresh-failed --exit-status <worker-status>
```

Also prove dry-run worker failure and controller failure do not create a
second record.

- [ ] **Step 2: Run the Zsh tests and verify RED**

Run:

```bash
bats --filter 'current shell diagnostic|no duplicate diagnostic' \
  dot_config/terminal_setup/tests/herdr-refresh.bats
```

Expected: FAIL because the Zsh wrapper returns the worker status immediately.

- [ ] **Step 3: Record only the post-controller local failure**

Capture the worker result without changing it. For a non-dry-run failure, call
the optional doctor writer with component `current-shell`, normalized reason,
and original status. Print the same saved/unavailable message vocabulary as
the controller. Return the captured worker status. Do not record dry-run
checks or duplicate controller failures.

- [ ] **Step 4: Run the Zsh and complete refresh suites**

Run:

```bash
bats --print-output-on-failure \
  dot_config/terminal_setup/tests/herdr-refresh.bats
```

Expected: all tests PASS and shell replacement still occurs only after every
remote and local check succeeds.

---

### Task 5: Documentation, Static Validation, and Scoped Deployment

**Files:**
- Modify: `dot_config/terminal_setup/README.md`
- Test: `dot_config/terminal_setup/tests/refresh-doctor.bats`
- Test: `dot_config/terminal_setup/tests/herdr-refresh.bats`

**Interfaces:**
- Consumes: completed record, doctor, controller, and Zsh interfaces.
- Produces: documented, validated, deployed managed commands.

- [ ] **Step 1: Document operator workflow and privacy boundary**

Add `refresh-doctor` to the command and file lists. Document failure-only
retention, exact location, ten-record cap, permissions, safe field list,
excluded data, non-mutating checks, and that Herdr updates/restarts remain
manual because server stop exits pane processes.

- [ ] **Step 2: Run all focused and repository tests**

Run:

```bash
bats --print-output-on-failure dot_config/terminal_setup/tests/refresh-doctor.bats
bats --print-output-on-failure dot_config/terminal_setup/tests/herdr-refresh.bats
bats --print-output-on-failure dot_config/terminal_setup/tests/repo-audit.bats
```

Expected: every test PASS.

- [ ] **Step 3: Run static and repository validation**

Run ShellCheck and `shfmt -d` on all managed Bash executables, `zsh -n` on
managed Zsh startup files, Actionlint, `git diff --check`, and Typos on every
changed documentation, test, and script file.

Expected: every command exits `0` with no diff or diagnostic.

- [ ] **Step 4: Review and apply only changed live targets**

Inspect `chezmoi diff` for:

```text
~/.local/bin/refresh-doctor
~/.local/bin/herdr-refresh-safe-shell-panes
~/.zshrc.d/herdr-refresh.zsh
```

Apply only those targets. Do not apply unrelated live drift.

- [ ] **Step 5: Verify the deployed doctor and refresh contract**

Verify source/deployed byte equality and executable modes. Run
`refresh-doctor`, an installed-controller dry-run, and a non-clearing live
controller apply. Confirm:

- doctor returns success without pane mutation;
- installed source matches the managed files;
- all eligible panes acknowledge;
- no success journal is created; and
- existing journals, if any, remain bounded and valid.

- [ ] **Step 6: Inspect final diff and repository state**

Confirm only planned files changed, no secrets or raw diagnostic fixtures are
present, and unrelated user state remains untouched. Commit or push only when
explicitly authorized.
