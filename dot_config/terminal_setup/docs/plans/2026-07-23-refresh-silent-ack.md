# Silent Herdr Refresh Acknowledgement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace terminal-rendered refresh acknowledgements with private, durable filesystem acknowledgements so successful refreshes produce no visible or transient status output.

**Architecture:** The controller owns a mode-`0700` run directory and gives each eligible pane a unique acknowledgement file and challenge. The worker atomically publishes the expected digest in a mode-`0600` file only after successful validation and clearing; concurrent controller waiters validate those files without reading terminal output. Public mutating Zsh commands use quiet controller mode, while failures and dry runs remain informative.

**Tech Stack:** Bash 3.2, Zsh 5.9, Herdr 0.7.5 CLI, jq, macOS `stat`/`shasum`, Bats, ShellCheck, shfmt, chezmoi.

---

### Task 1: Add worker acknowledgement regression tests

**Files:**
- Modify: `dot_config/terminal_setup/tests/herdr-refresh.bats`
- Test: `dot_local/bin/executable_zsh-refresh-current`

**Step 1: Replace the terminal-marker success test**

Create a private fixture directory and run:

```bash
challenge='refresh:file-ack-1'
ack_file="${ack_dir}/ack-p1"
"$WORKER" --check --ack-file "$ack_file" --challenge "$challenge"
```

Assert:

- exit status is `0`;
- combined stdout/stderr is empty;
- the file contains exactly the SHA-256 digest and one newline;
- `stat -f '%Lp' "$ack_file"` is `600`;
- output contains neither `herdr-refresh-ok-` nor SGR 8 (`$'\033[8m'`).

**Step 2: Add validation and no-clobber tests**

Cover these one behavior at a time:

- `--ack-file` without `--challenge` exits `2`;
- `--challenge` without `--ack-file` exits `2`;
- a relative acknowledgement path exits `2`;
- a parent directory not owned by the current user or not mode `0700` exits `2`;
- a symlink parent or pre-existing final path exits nonzero and remains unchanged.

Use test-owned directories only. Skip the owner-mismatch assertion when the
test cannot create a differently owned directory without elevation; ownership
logic remains covered by direct `stat` fixture validation.

**Step 3: Update failure-order tests**

Pass valid acknowledgement paths to the existing failed-clear and timeout
tests. Assert that neither failure creates a final acknowledgement.

**Step 4: Run focused tests to verify RED**

Run:

```bash
bats dot_config/terminal_setup/tests/herdr-refresh.bats \
  --filter 'worker.*acknowledgement|worker.*ack file|failed explicit clear|timeout'
```

Expected: FAIL because `--ack-file` is unknown and the worker still emits a
terminal marker and successful preflight message.

### Task 2: Implement silent atomic worker publication

**Files:**
- Modify: `dot_local/bin/executable_zsh-refresh-current`
- Test: `dot_config/terminal_setup/tests/herdr-refresh.bats`

**Step 1: Add argument pairing and path validation**

Parse:

```text
--ack-file ABSOLUTE_PATH
--challenge SAFE_CHALLENGE
```

Require both or neither. Validate:

```bash
[[ "$ack_file" == /* ]]
[[ "$ack_file" != *$'\n'* && "$ack_file" != *$'\r'* ]]
[[ ! -e "$ack_file" && ! -L "$ack_file" ]]
[[ -d "$ack_dir" && ! -L "$ack_dir" ]]
[[ "$(/usr/bin/stat -f '%u' "$ack_dir")" == "$(/usr/bin/id -u)" ]]
[[ "$(/usr/bin/stat -f '%Lp' "$ack_dir")" == 700 ]]
```

Keep the existing strict challenge validation.

**Step 2: Implement no-clobber publication**

After successful preflight and any requested clear:

1. derive the 64-character lowercase SHA-256 digest;
2. set `umask 077`;
3. create a temporary file beside the final file with `mktemp`;
4. write exactly `"$digest\n"` and enforce mode `0600`;
5. use a same-directory hard link to publish only if the final path does not
   exist;
6. remove the temporary link.

The cleanup trap must remove an unfinished temporary acknowledgement without
removing a successfully published final file.

**Step 3: Remove successful worker output**

Delete the terminal acknowledgement printer and the unconditional
`preflight passed` line. Keep every failure diagnostic.

**Step 4: Run focused tests to verify GREEN**

Run:

```bash
bats dot_config/terminal_setup/tests/herdr-refresh.bats \
  --filter 'worker.*acknowledgement|worker.*ack file|failed explicit clear|timeout'
shellcheck dot_local/bin/executable_zsh-refresh-current
shfmt -d dot_local/bin/executable_zsh-refresh-current
```

Expected: all focused tests pass with no static or formatting findings.

### Task 3: Add controller filesystem acknowledgement regression tests

**Files:**
- Modify: `dot_config/terminal_setup/tests/herdr-refresh.bats`
- Test: `dot_local/bin/executable_herdr-refresh-safe-shell-panes`

**Step 1: Extend the fake Herdr apply fixture**

For `pane run`, parse the internally generated fixed worker arguments without
executing `&& exec /bin/zsh -l`. Publish the expected digest to the requested
acknowledgement file using mode `0600`.

Add fixture modes for:

- no file (timeout);
- wrong digest;
- wrong mode;
- symlink;
- delayed publication gated until every eligible pane is dispatched.

**Step 2: Replace terminal wait assertions**

Update apply tests to assert:

- the remote command contains one quoted `--ack-file` and `--challenge`;
- no `herdr pane wait-output` call occurs;
- no remote command contains `herdr-refresh-ok-`;
- acknowledgement paths are unique for multiple panes;
- acknowledgement paths are inside one private controller directory.

**Step 3: Add durable and concurrent completion tests**

Prove:

- an acknowledgement created before the waiter begins is still accepted;
- two delayed acknowledgements complete concurrently;
- timeout, wrong digest, wrong mode, and symlink each return `1` and increment
  `failed`;
- dispatch failure does not wait for that pane and other panes are attempted.

**Step 4: Run controller tests to verify RED**

Run:

```bash
bats dot_config/terminal_setup/tests/herdr-refresh.bats \
  --filter 'apply|acknowledgement|unique|concurrent|dispatch'
```

Expected: FAIL because the controller still invokes `pane wait-output` and
does not pass `--ack-file`.

### Task 4: Implement concurrent controller file waiters

**Files:**
- Modify: `dot_local/bin/executable_herdr-refresh-safe-shell-panes`
- Test: `dot_config/terminal_setup/tests/herdr-refresh.bats`

**Step 1: Harden the controller run directory**

Immediately after `mktemp -d`, run:

```bash
chmod 700 "$tmp_dir"
```

Abort with exit `2` if private-directory setup fails.

**Step 2: Generate per-pane acknowledgement state**

For each rechecked eligible pane:

- derive a safe unique challenge and digest;
- select `${tmp_dir}/ack-${pane_token}-${index}`;
- shell-quote the worker, acknowledgement path, and challenge independently;
- append `--ack-file ... --challenge ...` to the fixed remote command.

Never place the expected digest or any `herdr-refresh-ok-` value in the remote
command.

**Step 3: Replace `pane wait-output`**

After successful dispatch, start a bounded background waiter for the exact
acknowledgement path. Poll at 50 ms intervals and accept only:

```bash
[[ -f "$ack_file" && ! -L "$ack_file" ]]
[[ "$(/usr/bin/stat -f '%Lp' "$ack_file")" == 600 ]]
[[ "$(wc -c <"$ack_file" | tr -d ' ')" == 65 ]]
IFS= read -r actual_digest <"$ack_file"
[[ "$actual_digest" == "$expected_digest" ]]
```

Track waiter PIDs and pane IDs in parallel arrays. Reap every waiter, report
each result once, and retain existing exit and summary semantics.

**Step 4: Run focused and full controller tests**

Run:

```bash
bats dot_config/terminal_setup/tests/herdr-refresh.bats \
  --filter 'controller|apply|acknowledgement|unique|concurrent|dispatch'
shellcheck dot_local/bin/executable_herdr-refresh-safe-shell-panes
shfmt -d dot_local/bin/executable_herdr-refresh-safe-shell-panes
```

Expected: focused tests pass, no `pane wait-output` is logged, and static checks
are clean.

### Task 5: Make successful public apply commands fully quiet

**Files:**
- Modify: `dot_local/bin/executable_herdr-refresh-safe-shell-panes`
- Modify: `dot_zshrc.d/herdr-refresh.zsh`
- Modify: `dot_config/terminal_setup/tests/herdr-refresh.bats`

**Step 1: Add RED tests**

Cover:

- controller `--apply --quiet` success has empty output;
- controller `--apply --quiet` failure still prints the relevant `FAIL` or
  infrastructure diagnostic;
- `refresh` success emits no output before shell replacement;
- `refresh --keep-scrollback` success emits no new output;
- `refresh-dry` remains informative;
- `clear-panes` success emits no controller status.

Run:

```bash
bats dot_config/terminal_setup/tests/herdr-refresh.bats --filter 'quiet|refresh.*output|refresh-dry|clear-panes'
```

Expected: FAIL because `--quiet` is unknown and successful workers/controllers
still print status.

**Step 2: Implement quiet controller reporting**

Add `--quiet` to the controller's internal options. Suppress routine mode,
classification, success, summary, and no-op output only when quiet. Continue
writing every failure and infrastructure diagnostic to stderr.

**Step 3: Use quiet mode from mutating Zsh functions**

Append `--quiet` to controller arguments for `refresh` and `clear-panes`, but
not for `refresh-dry`, `clear-panes-dry`, or direct controller use.

**Step 4: Verify GREEN and syntax**

Run:

```bash
bats dot_config/terminal_setup/tests/herdr-refresh.bats --filter 'quiet|refresh|clear-panes'
zsh -n dot_zshrc.d/herdr-refresh.zsh
shellcheck dot_local/bin/executable_herdr-refresh-safe-shell-panes \
  dot_local/bin/executable_zsh-refresh-current
shfmt -d dot_local/bin/executable_herdr-refresh-safe-shell-panes \
  dot_local/bin/executable_zsh-refresh-current
```

Expected: focused tests and static checks pass.

### Task 6: Update operations documentation

**Files:**
- Modify: `dot_config/terminal_setup/README.md`
- Reference: `dot_config/terminal_setup/docs/plans/2026-07-23-refresh-silent-ack-design.md`

**Step 1: Document the new completion channel**

Explain that mutating commands are silent on success, errors remain visible,
dry runs remain informative, and controller-owned acknowledgement files are
private and ephemeral.

**Step 2: Document compatibility and rollback**

State that no Herdr/Ghostty fork or new package is needed. Provide exact scoped
chezmoi apply targets and previous-revision rollback steps.

**Step 3: Validate documentation**

Run:

```bash
typos dot_config/terminal_setup/README.md \
  dot_config/terminal_setup/docs/plans/2026-07-23-refresh-silent-ack-design.md \
  dot_config/terminal_setup/docs/plans/2026-07-23-refresh-silent-ack.md
```

Expected: zero findings.

### Task 7: Run complete source verification

**Files:**
- Verify: `dot_config/terminal_setup/tests/herdr-refresh.bats`
- Verify: `dot_config/terminal_setup/tests/repo-audit.bats`
- Verify: `dot_config/terminal_setup/tests/terminal-output.bats`

**Step 1: Run the full test suite**

Run:

```bash
bats dot_config/terminal_setup/tests
```

Expected: every test passes with zero failures.

**Step 2: Run static and security checks**

Run:

```bash
shellcheck dot_local/bin/executable_herdr-refresh-safe-shell-panes \
  dot_local/bin/executable_zsh-refresh-current
shfmt -d dot_local/bin/executable_herdr-refresh-safe-shell-panes \
  dot_local/bin/executable_zsh-refresh-current
zsh -n dot_zshrc dot_zshrc.d/herdr-refresh.zsh
gitleaks dir --no-banner --redact .
```

Expected: all commands exit `0`.

**Step 3: Inspect the diff**

Run:

```bash
git diff --check
git status --short
git diff --stat
git diff -- \
  dot_local/bin/executable_herdr-refresh-safe-shell-panes \
  dot_local/bin/executable_zsh-refresh-current \
  dot_zshrc.d/herdr-refresh.zsh \
  dot_config/terminal_setup/tests/herdr-refresh.bats \
  dot_config/terminal_setup/README.md \
  dot_config/terminal_setup/docs/plans/2026-07-23-refresh-silent-ack-design.md \
  dot_config/terminal_setup/docs/plans/2026-07-23-refresh-silent-ack.md
```

Expected: only the scoped refresh implementation, tests, and documentation
have changed.

### Task 8: Deploy exact targets and verify live behavior

**Files:**
- Deploy: `~/.local/bin/herdr-refresh-safe-shell-panes`
- Deploy: `~/.local/bin/zsh-refresh-current`
- Deploy: `~/.zshrc.d/herdr-refresh.zsh`

**Step 1: Preview scoped deployment**

Run chezmoi from this worktree with only the three managed targets. Confirm the
preview contains no unrelated live configuration.

**Step 2: Apply exact targets**

Apply only:

```text
~/.local/bin/herdr-refresh-safe-shell-panes
~/.local/bin/zsh-refresh-current
~/.zshrc.d/herdr-refresh.zsh
```

Do not run an unscoped chezmoi apply.

**Step 3: Verify deployed equality and safe paths**

Run byte comparisons between worktree source results and all three deployed
targets, then:

```bash
~/.local/bin/zsh-refresh-current --check
~/.local/bin/herdr-refresh-safe-shell-panes --dry-run
zsh -lic 'refresh --help; refresh-dry'
```

Expected: worker check is silent on success; dry-run commands remain
informative.

**Step 4: Exercise controlled live Herdr panes**

Use only panes classified as eligible idle Zsh panes. Run the real mutating
flow, wait for every acknowledgement, then inspect recent pane text and ANSI
snapshots.

Expected:

- every eligible pane reaches a fresh prompt;
- no pane contains `herdr-refresh-ok-`;
- no refresh-generated SGR 8 sequence is present;
- no successful controller or worker status remains;
- failures, if any, are reported and the invoking shell is preserved.

**Step 5: Re-run deployed tests and report**

Run the full refresh test suite against deployed paths, inspect final Git and
chezmoi status, and report actual counts, live-pane evidence, rollback
instructions, and any unresolved environmental limitation.

Do not commit, push, open a pull request, or publish without explicit user
authorization.
