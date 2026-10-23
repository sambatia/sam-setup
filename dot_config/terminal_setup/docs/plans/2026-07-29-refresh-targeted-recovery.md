# Herdr Refresh Targeted Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make bulk Herdr shell refreshes tolerate the observed leading-character delivery fault and recover one transient failure without rerunning successful panes.

**Architecture:** Keep Herdr's supported atomic `pane run` API, but submit a shielded compound command whose worker path is not at the input boundary. Model dispatch as at most two rounds over indexed pane jobs; reuse each job's acknowledgement identity across rounds so the worker's existing atomic publication is also the deduplication gate.

**Tech Stack:** Bash 3.2-compatible shell, Zsh 5.9, Herdr 0.7.5 CLI, jq, Bats 1.14, ShellCheck 0.11, shfmt 3.13, chezmoi 2.71.

## Global Constraints

- Success remains strict: every selected pane must publish a valid acknowledgement.
- Keep first-round and recovery-round acknowledgement waits concurrent.
- Perform a complete read-only discovery pass before mutation and a foreground-process recheck before every dispatch.
- Retry only missing acknowledgements or unacknowledged dispatch errors, at most once.
- Never retry a malformed, symlinked, incorrectly permissioned, incorrectly sized, or wrong-digest acknowledgement.
- Reuse one acknowledgement path, challenge, digest, and remote command per pane for both attempts.
- Public mutating functions remain silent on complete success, including recovered success.
- Do not reveal pane command lines, working directories, or foreground arguments.
- Do not add dependencies, change public Zsh arguments, patch Herdr, or apply unrelated chezmoi targets.
- Do not commit, push, deploy externally, or open a pull request without explicit authorization. Local scoped `chezmoi apply` is the required deployment.

## File Structure

- Modify `dot_config/terminal_setup/tests/herdr-refresh.bats`: deterministic input-loss, retry, acknowledgement-integrity, idempotency, and safety fixtures.
- Modify `dot_local/bin/executable_herdr-refresh-safe-shell-panes`: command shield, two-round targeted dispatch, acknowledgement state classification, and final diagnostics.
- Modify `dot_config/terminal_setup/README.md`: document automatic targeted recovery and its strict failure semantics.
- Create `dot_config/terminal_setup/docs/plans/2026-07-29-refresh-targeted-recovery-design.md`: approved design and rationale.
- Create `dot_config/terminal_setup/docs/plans/2026-07-29-refresh-targeted-recovery.md`: this implementation and verification plan.

---

### Task 1: Shield the Worker from Leading-character Loss

**Files:**
- Modify: `dot_config/terminal_setup/tests/herdr-refresh.bats`
- Modify: `dot_local/bin/executable_herdr-refresh-safe-shell-panes`

**Interfaces:**
- Consumes: the existing `remote_command` string passed as one argument to `herdr pane run`.
- Produces: a remote command beginning with ` command true 2>/dev/null; ` followed by the unchanged, shell-escaped worker invocation.

- [ ] **Step 1: Extend the fake transport to reproduce the observed corruption**

In `publish_acknowledgement`, normalize a configured pane's submitted command by trimming its leading whitespace and removing its first non-whitespace character. Parse only the worker segment after the final `; ` and refuse to publish an acknowledgement unless its first word is an absolute `zsh-refresh-current` path:

```bash
if [[ "${DROP_LEADING_CHAR_PANE:-}" == "$pane_id" ]]; then
  remote_command="${remote_command#"${remote_command%%[![:space:]]*}"}"
  remote_command="${remote_command#?}"
fi
command_only="${remote_command%% && exec /bin/zsh -l}"
worker_command="${command_only##*; }"
eval "set -- $worker_command"
[[ "${1:-}" == /*/zsh-refresh-current ]] || return 0
```

Keep the remainder of acknowledgement option extraction unchanged.

- [ ] **Step 2: Add the failing regression test**

Add:

```bash
@test "worker invocation survives a dropped leading command character" {
  run env DROP_LEADING_CHAR_PANE=w1:p1 PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$CONTROLLER" --apply --timeout-ms 150

  [ "$status" -eq 0 ]
  [[ "$output" == *"OK w1:p1"* ]]
  run_command="$(awk -F $'\t' '$2 == "pane" && $3 == "run" && $4 == "w1:p1" { print $5; exit }' "$CALL_LOG")"
  [[ "$run_command" == ' command true 2>/dev/null; '* ]]
}
```

- [ ] **Step 3: Run the regression test and verify RED**

Run:

```bash
bats --filter 'worker invocation survives a dropped leading command character' \
  dot_config/terminal_setup/tests/herdr-refresh.bats
```

Expected: FAIL because the current command starts directly with the absolute worker path; the fake drops `/`, publishes no acknowledgement, and the controller exits nonzero.

- [ ] **Step 4: Add the minimal command shield**

Change remote command initialization from:

```bash
remote_command="$quoted_worker"
```

to:

```bash
remote_command=" command true 2>/dev/null; $quoted_worker"
```

Do not change worker arguments or the final `&& exec /bin/zsh -l`.

- [ ] **Step 5: Run the regression test and verify GREEN**

Run the Step 3 command again.

Expected: PASS; the fake damages only `command true`, extracts the untouched absolute worker invocation, and publishes the acknowledgement.

- [ ] **Step 6: Run the existing controller success and quoting tests**

Run:

```bash
bats --filter 'apply dispatches|explicit clear|worker paths containing spaces|clear-only' \
  dot_config/terminal_setup/tests/herdr-refresh.bats
```

Expected: all selected tests PASS.

---

### Task 2: Retry Only Unresolved Panes

**Files:**
- Modify: `dot_config/terminal_setup/tests/herdr-refresh.bats`
- Modify: `dot_local/bin/executable_herdr-refresh-safe-shell-panes`

**Interfaces:**
- Consumes: indexed pane jobs containing `pane_id`, `ack_file`, `digest`, `remote_command`, and `dispatch_err`.
- Produces: at most two dispatch rounds; `next_job_indexes` contains only first-round jobs with no acknowledgement.

- [ ] **Step 1: Make the fake acknowledgement failure attempt-aware**

Count `pane run` calls for the current pane after the fake logs the call. When
`ACK_FAILURE_ATTEMPTS` is set, use `ACK_FAILURE_MODE` only through that attempt:

```bash
pane_run_calls="$(awk -F $'\''\t'\'' -v pane="$pane_id" \
  '\''$2 == "pane" && $3 == "run" && $4 == pane { count += 1 } END { print count + 0 }'\'' \
  "$CALL_LOG")"
if [[ "${ACK_FAILURE_PANE:-}" == "$pane_id" ]] &&
  ((pane_run_calls <= ${ACK_FAILURE_ATTEMPTS:-999999})); then
  mode="${ACK_FAILURE_MODE:-timeout}"
fi
```

Preserve the existing permanent `ACK_MODE=timeout` fixture.

- [ ] **Step 2: Add a failing targeted-recovery test**

Add:

```bash
@test "one transient timeout retries only the unresolved pane" {
  export P2_PROCESS_JSON='{"result":{"process_info":{"foreground_processes":[{"name":"zsh"}]}}}'

  run env P2_PROCESS_JSON="$P2_PROCESS_JSON" ACK_FAILURE_PANE=w1:p1 \
    ACK_FAILURE_MODE=timeout ACK_FAILURE_ATTEMPTS=1 PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$CONTROLLER" --apply --timeout-ms 150

  [ "$status" -eq 0 ]
  [[ "$output" == *"RETRY w1:p1 reason=acknowledgement-timeout attempt=2/2"* ]]
  [[ "$output" == *"refreshed=2"* ]]
  [ "$(awk -F $'\t' '$2 == "pane" && $3 == "run" && $4 == "w1:p1" { count += 1 } END { print count + 0 }' "$CALL_LOG")" -eq 2 ]
  [ "$(awk -F $'\t' '$2 == "pane" && $3 == "run" && $4 == "w1:p2" { count += 1 } END { print count + 0 }' "$CALL_LOG")" -eq 1 ]
}
```

- [ ] **Step 3: Run the targeted-recovery test and verify RED**

Run:

```bash
bats --filter 'one transient timeout retries only the unresolved pane' \
  dot_config/terminal_setup/tests/herdr-refresh.bats
```

Expected: FAIL because the current controller has one dispatch round and exits after the first timeout.

- [ ] **Step 4: Represent pane work as stable indexed jobs**

Before dispatch, create sentinel-based parallel arrays:

```bash
job_panes=("__sentinel__")
job_ack_files=("__sentinel__")
job_digests=("__sentinel__")
job_commands=("__sentinel__")
job_dispatch_errs=("__sentinel__")
candidate_job_indexes=("__sentinel__")
```

For every initially eligible pane, allocate its acknowledgement identity and
shielded command exactly once, append each value at the same job index, and add
that index to `candidate_job_indexes`.

- [ ] **Step 5: Replace the single dispatch/wait pass with two bounded rounds**

Use `attempt=1`, `max_attempts=2`, and per-round sentinel arrays:

```bash
while ((attempt <= max_attempts)) && ((${#candidate_job_indexes[@]} > 1)); do
  round_job_indexes=("__sentinel__")
  round_wait_pids=("__sentinel__")
  round_dispatch_statuses=("__sentinel__")
  next_job_indexes=("__sentinel__")

  # Recheck, dispatch each candidate, and start one acknowledgement waiter.
  # Wait for all round waiters, count valid acknowledgements once, and carry
  # only missing acknowledgements into next_job_indexes on attempt 1.

  candidate_job_indexes=("${next_job_indexes[@]}")
  ((attempt += 1))
done
```

For each waiter, also append its PID to the existing global `pending_pids`
cleanup list and blank that entry after `wait`.

On a first-round missing acknowledgement, print only in non-quiet mode:

```bash
printf 'RETRY %s reason=%s attempt=2/2\n' "$pane_id" "$retry_reason"
```

Set `retry_reason=dispatch-failed` when `herdr pane run` returned nonzero and
`retry_reason=acknowledgement-timeout` otherwise. Do not increment `failed`
until an operation becomes terminal.

- [ ] **Step 6: Run the targeted-recovery test and verify GREEN**

Run the Step 3 command again.

Expected: PASS with two dispatches for `w1:p1`, one for `w1:p2`, and both panes counted once as refreshed.

- [ ] **Step 7: Prove quiet recovery stays silent**

Add and run:

```bash
@test "quiet apply is silent after successful recovery" {
  run env ACK_FAILURE_PANE=w1:p1 ACK_FAILURE_MODE=timeout ACK_FAILURE_ATTEMPTS=1 \
    PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$CONTROLLER" --apply --quiet --timeout-ms 150

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
```

Expected: PASS without adding a production output branch.

---

### Task 3: Make Retries Idempotent and Failure-aware

**Files:**
- Modify: `dot_config/terminal_setup/tests/herdr-refresh.bats`
- Modify: `dot_local/bin/executable_herdr-refresh-safe-shell-panes`

**Interfaces:**
- Consumes: `wait_for_acknowledgement ACK_FILE EXPECTED_DIGEST TIMEOUT_MS`.
- Produces: exit `0` for valid, `1` for absent at timeout, and `2` for a present invalid acknowledgement.

- [ ] **Step 1: Add failing tests for stable identity and terminal failures**

Add:

```bash
@test "recovery reuses one idempotent remote command" {
  run env ACK_FAILURE_PANE=w1:p1 ACK_FAILURE_MODE=timeout ACK_FAILURE_ATTEMPTS=1 \
    PATH="$PATH" CALL_LOG="$CALL_LOG" "$CONTROLLER" --apply --timeout-ms 150

  [ "$status" -eq 0 ]
  [ "$(awk -F $'\t' '$2 == "pane" && $3 == "run" && $4 == "w1:p1" { print $5 }' "$CALL_LOG" | sort -u | wc -l | tr -d ' ')" -eq 1 ]
}

@test "permanent acknowledgement timeout stops after one retry" {
  run env ACK_MODE=timeout PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$CONTROLLER" --apply --timeout-ms 150

  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL w1:p1 reason=acknowledgement-timeout attempts=2"* ]]
  [ "$(awk -F $'\t' '$2 == "pane" && $3 == "run" && $4 == "w1:p1" { count += 1 } END { print count + 0 }' "$CALL_LOG")" -eq 2 ]
}
```

Update the malformed acknowledgement test to require
`reason=acknowledgement-invalid` and exactly one dispatch.

- [ ] **Step 2: Run the new tests and verify RED**

Run:

```bash
bats --filter 'recovery reuses|permanent acknowledgement|malformed acknowledgement' \
  dot_config/terminal_setup/tests/herdr-refresh.bats
```

Expected: at least the permanent-timeout and malformed-classification assertions FAIL until terminal states are separated.

- [ ] **Step 3: Separate absent and invalid acknowledgement states**

In `wait_for_acknowledgement`, return `2` for every branch where an
acknowledgement path exists but fails file type, symlink, mode, size, read, or
digest validation. Continue returning `1` only after polling exhausts without
any acknowledgement path.

When collecting waiters:

```bash
wait "$wait_pid"
ack_status=$?
case "$ack_status" in
  0) ((refreshed += 1)) ;;
  1) # retry once or emit acknowledgement-timeout ;;
  2) # emit acknowledgement-invalid and never retry ;;
esac
```

- [ ] **Step 4: Keep acknowledgement identity stable across attempts**

Build `ack_file`, `challenge`, `digest`, and `remote_command` only when the job
is first created. The recovery round must index and reuse `job_ack_files`,
`job_digests`, and `job_commands`; it must not regenerate any of them.

- [ ] **Step 5: Run the state tests and verify GREEN**

Run the Step 2 command again.

Expected: all selected tests PASS; permanent absence dispatches twice, malformed acknowledgements dispatch once, and both retry commands are byte-for-byte identical.

- [ ] **Step 6: Add and verify a retry eligibility safety test**

Extend the fake process response with `P1_PROCESS_JSON_THIRD` for the third
`process-info` call, then add:

```bash
@test "recovery does not redispatch a pane that stopped being idle" {
  export P1_PROCESS_JSON_THIRD='{"result":{"process_info":{"foreground_processes":[{"name":"node"}]}}}'

  run env ACK_MODE=timeout P1_PROCESS_JSON_THIRD="$P1_PROCESS_JSON_THIRD" \
    PATH="$PATH" CALL_LOG="$CALL_LOG" "$CONTROLLER" --apply --timeout-ms 150

  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL w1:p1 reason=changed-before-retry attempts=1"* ]]
  [ "$(awk -F $'\t' '$2 == "pane" && $3 == "run" && $4 == "w1:p1" { count += 1 } END { print count + 0 }' "$CALL_LOG")" -eq 1 ]
}
```

Run that exact Bats filter and verify RED before implementing the
recovery-specific recheck result, then GREEN afterward.

- [ ] **Step 7: Run the complete Bats suite**

Run:

```bash
bats dot_config/terminal_setup/tests/herdr-refresh.bats
```

Expected: all tests PASS with no warnings or leaked background processes.

---

### Task 4: Document, Validate, and Deploy the Scoped Change

**Files:**
- Modify: `dot_config/terminal_setup/README.md`
- Verify: all files listed under File Structure
- Deploy: `~/.local/bin/herdr-refresh-safe-shell-panes`

**Interfaces:**
- Consumes: the tested managed controller source.
- Produces: a deployed controller identical to chezmoi source and user-facing documentation describing recovery.

- [ ] **Step 1: Update the operational documentation**

In the Herdr refresh section, document:

- the sacrificial command prefix protects the worker path at the terminal input boundary;
- one private acknowledgement identity is reused for one targeted retry;
- successful panes are never redispatched;
- missing acknowledgements and unacknowledged dispatch errors retry once;
- invalid acknowledgements and changed/busy panes fail immediately and strictly;
- recovered public refreshes remain silent.

- [ ] **Step 2: Run focused static validation**

Run:

```bash
shellcheck \
  dot_local/bin/executable_herdr-refresh-safe-shell-panes \
  dot_local/bin/executable_zsh-refresh-current
shfmt -d \
  dot_local/bin/executable_herdr-refresh-safe-shell-panes \
  dot_local/bin/executable_zsh-refresh-current
git diff --check
typos \
  dot_config/terminal_setup/README.md \
  dot_config/terminal_setup/docs/plans/2026-07-29-refresh-targeted-recovery-design.md \
  dot_config/terminal_setup/docs/plans/2026-07-29-refresh-targeted-recovery.md \
  dot_config/terminal_setup/tests/herdr-refresh.bats \
  dot_local/bin/executable_herdr-refresh-safe-shell-panes
```

Expected: every command exits `0` and `shfmt -d` produces no diff.

- [ ] **Step 3: Run the repository CI-equivalent checks**

Run:

```bash
bats dot_config/terminal_setup/tests/herdr-refresh.bats
bats dot_config/terminal_setup/tests/repo-audit.bats
actionlint
```

Expected: every test and lint check PASS.

- [ ] **Step 4: Inspect the final source diff and scoped deployment diff**

Run:

```bash
git status --short
git diff -- \
  dot_config/terminal_setup/README.md \
  dot_config/terminal_setup/docs/plans/2026-07-29-refresh-targeted-recovery-design.md \
  dot_config/terminal_setup/docs/plans/2026-07-29-refresh-targeted-recovery.md \
  dot_config/terminal_setup/tests/herdr-refresh.bats \
  dot_local/bin/executable_herdr-refresh-safe-shell-panes
chezmoi diff \
  ~/.local/bin/herdr-refresh-safe-shell-panes \
  ~/.config/terminal_setup/README.md
```

Expected: the controller diff contains only this task. The README preview also
shows pre-existing unapplied source drift; review it but do not apply that
target in this task. No secrets or unexpected target changes appear.

- [ ] **Step 5: Apply only the reviewed production targets**

Run:

```bash
chezmoi apply \
  ~/.local/bin/herdr-refresh-safe-shell-panes
```

Expected: exit `0`; no README, `.zshrc`, worker, package, Herdr server, or
external system changes.

- [ ] **Step 6: Verify deployed bytes and local preflight**

Run:

```bash
cmp -s \
  dot_local/bin/executable_herdr-refresh-safe-shell-panes \
  ~/.local/bin/herdr-refresh-safe-shell-panes
zsh-refresh-current --check
herdr-refresh-safe-shell-panes --dry-run --verbose
```

Expected: `cmp` and worker preflight exit `0`; dry-run discovers current panes without mutation or inspection errors.

- [ ] **Step 7: Run one live no-clear controller validation**

Run:

```bash
herdr-refresh-safe-shell-panes --apply --timeout-ms 5000
```

Expected: every currently eligible idle Zsh pane reports `OK`, no pane reports
`FAIL`, no pane is cleared, the summary has `failed=0`, and any transient
delivery fault is recovered by a targeted `RETRY`.

- [ ] **Step 8: Recheck final repository and deployment state**

Run:

```bash
git diff --check
git status --short
chezmoi diff \
  ~/.local/bin/herdr-refresh-safe-shell-panes \
  ~/.config/terminal_setup/README.md
```

Expected: source changes remain uncommitted for user review, the controller has
no remaining chezmoi diff, and the reviewed pre-existing README drift remains
unapplied.
