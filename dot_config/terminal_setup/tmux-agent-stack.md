# tmux agent stack

Validated on 2026-09-12, macOS 26.6.2, Apple Silicon. The installed stack runs
Claude, Codex, and OMP with their existing accounts and configuration. Physical
Ghostty rendering, clipboard, and keyboard checks remain unverified because
the computer-use tool denied access to Ghostty. The terminal tests below used
an attached PTY and a disposable tmux server.

## Responsibilities

```text
Ghostty
  └─ normal tmux server
       ├─ SessionX: session and directory navigation
       ├─ workmux: repository worktrees and agent windows
       │    ├─ sibling worktree → Codex + shell
       │    ├─ sibling worktree → Claude + shell
       │    └─ sibling worktree → OMP + shell
       └─ Agent Manager UI: persistent agent cockpit
            └─ private tmux socket: agentmgr
                 ├─ am_<id> → Claude
                 └─ am_<id> → Codex

Herdr remains installed as the fallback. AoE is deliberately deferred.
```

SessionX sees sessions on the current tmux socket. Agent Manager's private
sessions intentionally stay out of its normal session list. Quitting the
manager leaves those agents running. Killing a normal tmux server terminates
its workmux windows, but leaves `agentmgr` alone. This was tested on an isolated
normal socket; the user's existing server was never killed.

Use workmux for new project worktrees. Use Agent Manager for long-lived agent
conversations, quick prompts, and review. Open an existing workmux directory
in Agent Manager with its worktree toggle **off** to avoid creating another
worktree. Each launcher owns the sessions it creates.

## Installed versions and ownership

| Component | Version | Owner | Executable or plugin path |
|---|---|---|---|
| tmux | 3.7c | Homebrew, existing | `/opt/homebrew/bin/tmux` |
| Agent Manager | 0.36.0 | Homebrew cask `yoanwai/tap/agent-manager` | `/opt/homebrew/bin/agent-manager` |
| workmux | 0.1.261 | Homebrew formula `raine/workmux/workmux` | `/opt/homebrew/bin/workmux` |
| SessionX | `628575b` | Existing TPM | `~/.tmux/plugins/tmux-sessionx` |
| AoE | Deferred; evaluated 1.16.0 | None | Not installed |
| fzf | 0.74.4 | Homebrew, existing | `/opt/homebrew/bin/fzf` |
| bat | 0.26.1 | Homebrew, existing | `/opt/homebrew/bin/bat` |
| zoxide | 0.10.0 | Homebrew, existing | `/opt/homebrew/bin/zoxide` |
| Herdr | 0.9.0 | Homebrew, existing | `/opt/homebrew/bin/herdr` |

Agent Manager and workmux were verified as native arm64 binaries. Agent Manager
requires tmux 3.1+ and Git. No numeric tmux minimum was found in the
evaluated workmux installation guide; its tmux/Git workflow passed here. SessionX's selected builtin fzf popup needs modern
tmux popup support and fzf 0.53+; this machine exceeds both. `fzf-tmux` also
exists, although this configuration uses builtin `fzf --tmux`. SessionX has no
tagged release to pin in the evaluated repository. Its current preview script
uses `tmux capture-pane` for sessions and `ls` for directories; it does not use
bat. The installed bat dependency was checked independently.

The package list lives in [recommended-tools.Brewfile](recommended-tools.Brewfile).
No mise entries, shell aliases, launch agents, services, or alternate update
schedulers were added. Both executable names are already short and discoverable
in a new login shell.

## Configuration and agent integration

| Destination | Change and purpose |
|---|---|
| `~/.tmux.conf` | SessionX plugin and settings; three free prefix bindings; workmux status in the existing pane border |
| `~/.config/workmux/config.yaml` | Codex default, agent plus shell layout, Nerd Font icons, theme-owned status formatting, keep worktrees after merge |
| `~/Library/Application Support/agent-manager/config.toml` | Zed editor, two-second polling, workmux-hook suppression in private Claude/Codex sessions |
| `~/.omp/agent/extensions/workmux-status.ts` | Official workmux 0.1.261 OMP status extension; existing Herdr extension retained |
| `~/.claude/settings.json` | Five official workmux hook groups appended; existing hook objects and other keys preserved |
| `~/.codex/hooks.json` | Seven official workmux hook groups appended; existing hook objects and other keys preserved |
| `~/.codex/config.toml` | New workmux hook trust fingerprints recorded through Codex's hook review UI; existing hooks feature already enabled |
| `~/.homebrew/trust.json` | Exact requested cask/formula trust entries for the two official taps |
| `~/Projects/star-setup/scripts/update-all.zsh` | Read-only health probes after the existing TPM stage |
| `~/Projects/star-setup/scripts/test/update-all/tmux-agent-stack.bats` | Four regression tests for ownership, failure reporting, missing binaries, and plugin revision |
| `~/.config/terminal_setup/` | Package recovery manifest, this guide, README link, and selective hook fragments |

Chezmoi owns the portable files through `dot_tmux.conf`, `dot_config/workmux`,
`dot_omp/agent/extensions`, and
`private_Library/private_Application Support/agent-manager/config.toml`.
The updater remains owned by star-setup and is already live through the existing
`~/.local/bin/update-all` symlink. Agent credentials, transcripts, databases,
hook trust, and the mixed Claude/Codex user configuration remain local.
Smoke tests created normal agent history and project-trust metadata in those
local stores; none is in dotfiles.

Ukiyo rebuilds window-tab formats when themes change. Therefore
`status_format: false` leaves it in charge, and the stable pane-border format
includes `@workmux_status`. The original SSH indicator and continuum save
command remain. This displays the window's agent status above its panes;
`workmux dashboard` provides the overview across windows. Existing status-bar,
Ghostty, shell, and Herdr settings were retained, including the live-only final
`set -g mouse on` override in `~/.tmux.conf`. A wholesale `chezmoi apply` would
still remove that pre-existing override; use a reviewed selective apply.

| Agent | Agent Manager | workmux | Actual test |
|---|---|---|---|
| Claude Code 2.1.269 | Native support; per-launch MCP and hook settings | Official hooks | Existing Claude Max session answered in both launchers; status and recovery passed |
| Codex 0.154.0 | Native support; per-launch MCP overrides | Official hooks | Existing account answered in both launchers; hook trust, status, continuation, fork, and recovery tested |
| OMP 18.1.17 | No native preset in evaluated release; no custom adapter added | Official extension | Existing configured provider answered; status reached done |
| Pi | Native preset upstream | Official extension upstream | Executable absent; not installed or tested |

Agent Manager prefixes every Claude and Codex launch, resume, picker, legacy
revive, and fork command with
`env WORKMUX_DISABLE_SET_WINDOW_STATUS=1`. Both upstream workmux registration
and status commands honor this variable. Recovery uses separate command
templates upstream; a regression check found and corrected missing suppression
on those paths. Private sessions stay out of the normal workmux dashboard, and
Agent Manager supplies their status tracking.
Claude's MCP file is passed with `--mcp-config`; Codex gets process-level
`-c mcp_servers...` overrides. No global MCP entries or authentication methods
were replaced. Existing approval modes were retained.

The manager's default worktree toggle remains off. Its optional worktree mode
was tested separately: it creates a sibling `project-worktrees/<name>` and an
`am/<name>` branch. Workmux uses `project__worktrees/<branch>` siblings. The global
workmux config specifies no file-copy operations or setup hooks. A fixture
`.env` was absent from every created worktree. Project-level workmux config can
override global defaults, so review `workmux add ... --dry-run` in each project.

### Reproducing the selective hooks

`workmux setup --hooks` previews integration for every detected agent directory,
including stale directories. On this machine the broad write was declined.
Instead, the reviewed upstream entries were merged only into Claude and Codex,
and the OMP extension was copied. No agent skills were installed.

[workmux-hooks/claude.json](workmux-hooks/claude.json) and
[workmux-hooks/codex.json](workmux-hooks/codex.json) contain exactly those additions
from workmux 0.1.261. On a fresh machine, back up the target user file, merge each
fragment's event arrays by appending only missing groups, and retain every other
key and hook. Never replace an entire settings file with a fragment. The OMP
extension is restored by Chezmoi. In Codex, review and trust these new commands
in `/hooks`; the first already-started turn may precede that trust decision.
After upgrades, review the current upstream hook changes before refreshing
these fragments. Binary updates do not silently rewrite user hooks.

## Keys and daily use

The existing tmux primary prefix is `Ctrl+A`; `Ctrl+B` is the secondary prefix.
Both send-prefix bindings remain. Existing `prefix L` resize and `prefix o`
next-pane bindings were left intact.

| Scope | Key | Action |
|---|---|---|
| tmux, new | `prefix O` | SessionX popup |
| tmux, new | `prefix Alt+l` | `workmux last-done` |
| tmux, new | `prefix Tab` | `workmux last-agent` |
| SessionX defaults | type, then Enter | Filter and switch; an existing directory path creates a session there |
| SessionX defaults | `Ctrl+F` / `Ctrl+X` | zoxide directories / directories under `~/Projects` |
| SessionX defaults | `Ctrl+W` / `Ctrl+T` | Window list / tree preview |
| SessionX defaults | `Ctrl+R` | Rename selected session, then type its new name |
| SessionX defaults | `Alt+Backspace` | **Immediately kill selected session, without confirmation** |
| SessionX defaults | Escape | Close popup |
| Agent Manager defaults | `n`, Space, Enter, `A` | New agent, quick prompt, focus, full tmux attach |
| Agent Manager defaults | `Ctrl+Q` or `Ctrl+\` | Return to manager |
| Agent Manager defaults | `Ctrl+R`, F3 | Diff review, Zed editor |
| Agent Manager defaults | `v`, `R`, `q` | Revive conversation, restart fresh, quit manager while agents continue |

Only the three tmux bindings are new assignments. The application keys are
upstream defaults. `Alt+l`, Option-key behavior, F3, and clipboard need physical
Ghostty verification. The equivalent `workmux last-done` command was tested.
With the matching nested prefixes here, `Ctrl+B`, `Ctrl+B`, `d` forwards the
prefix and detaches the inner session; `Ctrl+Q` also passed the PTY test.

The twelve actions to remember:

1. `tmux new-session -A -s dev`: open the normal workspace.
2. `prefix O`: switch sessions or choose a directory.
3. `agent-manager`: open the persistent cockpit from a project directory.
4. Manager `n`: choose Claude/Codex; keep worktree off unless explicitly needed.
5. Manager Space / Enter / `Ctrl+Q`: prompt, focus, return.
6. Manager `Ctrl+R` / `v` / `R`: review, resume, restart fresh.
7. `workmux add feature-name --agent codex --dry-run`: inspect the plan.
8. `workmux add feature-name --agent codex`: create it; use `claude` or `omp` as needed.
9. `workmux dashboard`: see all managed agent states.
10. `prefix Alt+l` / `prefix Tab`: last done or waiting agent / last agent.
11. `workmux open feature-name --continue`: reopen with the last conversation; omit `--continue` for a fresh one.
12. `workmux close feature-name`, then `workmux remove --keep-branch feature-name` when finished: close the window, then remove the worktree after reviewing changes.

`update-all` remains the usual maintenance command. In manager creation, the
worktree checkbox is opt-in. Manager `d` confirms deletion of its session, but
does not promise removal of the associated Git worktree; inspect Git afterward.

Continuation and fork remain opt-in. Exact installed fork syntax is
`workmux add new-name --agent codex --fork=<session-id>` (also available for
Claude). Prefer an explicit ID: bare `--fork` under a Codex caller may use its
inherited `CODEX_THREAD_ID`, even when the command changes directories. The
test initially selected that caller's thread; it was stopped, and an explicit
fixture ID correctly forked the intended conversation. Claude's current workmux
fork implementation copies its transcript with the same session ID into the
new project store. It resumed locally, but Claude warned that another terminal
already owned Remote Control for that ID. Do not treat that as independent
remote-session identity.

## AoE evaluation and decision

This compares Agent Manager 0.36.0, AoE 1.16.0, and workmux 0.1.261. “Supported”
describes upstream capability; only the selected local stack was run here.

| Capability | Agent Manager | AoE | workmux | Unique value here? |
|---|---|---|---|---|
| Claude Code | Native; tested | Supported | Supported; tested | No |
| Codex | Native; tested | Supported | Supported; tested | No |
| OMP | Custom command only | Native, including ACP view | Official extension; tested | AoE adds structured view; no demonstrated need |
| Pi | Native | Supported | Official extension | No executable here |
| Persistent tmux sessions | Private socket; tested | tmux-backed | Normal tmux windows | No |
| Live status | Native detection | Agent-aware detection | Hooks/extensions | No |
| Worktrees | Optional | Supported | Primary purpose | No |
| Diff review | Native; tested | Native | Dashboard/diff workflow | No |
| Agent-to-agent operations | MCP and scoped CLI | CLI/API control | CLI orchestration | No missing local operation identified |
| Web UI | No integrated surface found | Desktop dashboard | No integrated surface found | Yes, if needed |
| Mobile-oriented access | Terminal/SSH | Phone structured view | Terminal/SSH | Yes, if needed |
| HTTP/API control | Local CLI/MCP | HTTP API | Local CLI/JSON | Different interface; no automation gap shown |
| Remote access | SSH to host | Browser/remote mode | SSH to host | Browser access is distinct |
| Sandbox/container support | Existing agent permissions | Docker/Podman/Apple Containers | Containers/Lima | No current isolation requirement |
| Multi-repo workspace | Sessions/groups and repo review | Explicit multi-repo workspaces | Repository worktrees | Distinct grouping; no concrete requirement |
| Notifications | Desktop/terminal | Desktop and Web Push | Hook/status and merge notification | Web Push is distinct |
| Existing subscription auth | Verified for Claude/Codex | Supported routes; not tested here | Verified for Claude/Codex | No reason to migrate auth |
| MCP/config preservation | Per-launch merge/overrides verified | Agent/view dependent; not verified locally | Existing CLI config plus hooks | No added benefit established |

AoE is deferred. Web/mobile access and explicit multi-repo workspaces are real
differences, but this rollout has no concrete remote-management or HTTP
automation workflow. workmux already covers the requested OMP and worktree
needs. Adding a second local cockpit would add maintenance before demonstrating
an operational benefit. No AoE service, listener, token, sandbox, profile, or
update stage was created.

Additional evidence to revisit before an AoE trial: open
[#2658](https://github.com/agent-of-empires/agent-of-empires/issues/2658) reports
Claude Max authentication loss in one macOS session; it does not establish a
reproduced root cause. [#3928](https://github.com/agent-of-empires/agent-of-empires/issues/3928)
reports a v1.16.0 mass-restart resume race on WSL, not a verified macOS failure.
The v1.16.0 release also calls out database migration/downgrade constraints.
These are trial considerations, not proof that AoE is unusable.

If a phone/Web/API workflow becomes concrete, evaluate it separately with a
private authenticated endpoint, distinct session ownership, and backups of
its own state. Preserve the installed agents' subscription-based access.

## Updates and recovery

| Item | Sole updater | Verification |
|---|---|---|
| Agent Manager cask | Existing Homebrew cask upgrade stage | `agent-manager --version`, path owner |
| workmux formula | Existing Homebrew formula upgrade stage | `workmux --version`, path owner |
| SessionX | Existing guarded TPM `update_plugins all` stage | Installed Git revision |
| AoE | None | Not installed |

The added Shell probes only read versions and revision. They do not invoke
`agent-manager update`, a workmux self-updater, `brew upgrade`, `git pull`, or an
installer. Existing Homebrew and TPM tests plus the four new fixtures verify
that ownership and failure reporting. The live check reported all three
Homebrew binaries, SessionX's TPM revision, `updated=0`, `warnings=0`, and
`failures=0`. The TPM check planned one existing `update_plugins all` invocation.
Existing bounded TPM failure handling was retained.

Homebrew's tap validation required reviewing an unrelated `stremio-mcp` formula
in the Agent Manager tap. Its exact temporary trust was revoked immediately
after tapping; it was never installed. Permanent trust is limited to the two
requested packages. The Agent Manager cask emits an upstream `postflight`
deprecation warning. Installation succeeded; no bypass or alternate installer
was used. Prefer Homebrew updates over the manager's in-app update action.

Backups for this rollout are in
`~/.local/state/tmux-agent-stack/backups/20260912T204241/`, with a path/hash
manifest and private file permissions. For rollback, compare each backup with
the current file and reverse only this task's additions. Restore the live tmux
backup if it has had no later edits; restore the corresponding Chezmoi source
as well. Remove only the added workmux groups from mixed agent hook files, and
remove their corresponding Codex trust records. Keep every pre-existing group.
Remove the new standalone workmux config, OMP extension, and Agent Manager
config only after checking for later edits. Remove the three tmux bindings and
SessionX declaration, then reload `tmux source-file ~/.tmux.conf`.

To uninstall binaries after stopping their sessions, use
`brew uninstall --cask yoanwai/tap/agent-manager` and
`brew uninstall raine/workmux/workmux`. Retain runtime data for recovery unless
it is deliberately discarded. Remove the corresponding Brewfile and trust
entries only when no longer used. The new updater probe function and its one
Shell call can be removed independently. Do not run an unqualified
`tmux kill-server` as a cleanup shortcut.

## Verification record

| Check | Result |
|---|---|
| Native packages, one owner, fresh login-shell PATH | Passed |
| New tmux bindings and config reload/restart | Passed on live reload and disposable restart |
| Existing normal tmux sessions and Herdr | Preserved |
| SessionX popup, filter, preview, switch, create, rename, delete, zoxide | Passed through attached PTY |
| Agent Manager Claude and Codex replies | Passed with existing auth/config |
| Manager quit/reopen | Passed; private session PIDs unchanged |
| Kill isolated normal socket | Passed; private session PIDs unchanged |
| Kill/revive each managed agent | Passed; original conversation IDs and transcripts retained |
| Manager diff review | Passed; displayed a known fixture change |
| Nested attach, Ctrl+Q, forwarded prefix detach | Passed through PTY |
| workmux dry-run and sibling worktrees | Passed; no `.env` sentinel copied |
| workmux Claude, Codex, OMP replies | Passed |
| Agent status | Real replies reached done for all three; official status command path verified working → waiting → done |
| `workmux last-done` | Passed; selected the expected Codex pane |
| Codex continue and explicit-ID fork | Passed; prior messages restored |
| Claude fork | Local transcript resumed; Remote Control identity warning recorded |
| Original Claude/Codex hook preservation | Passed by structural comparison to backups |
| Focused updater/Homebrew/TPM Bats | 31 passed, including four new regression tests |
| Python updater tests | 40 passed |
| Full updater suite | 611 Bats tests and 40 Python tests passed; exit 0 |
| Chezmoi restore into empty home | All five existing reproducibility tests passed |
| Zsh syntax, repository lint, diff whitespace | Passed |
| Secret scans | Both repository histories and all 11 changed source files passed with gitleaks redaction |
| Physical Ghostty resize, glyphs, Option/F3, clipboard | Blocked by computer-use access denial; no visual pass claimed |
| Fixture cleanup | All task sessions, worktrees, repository, and zoxide entry removed; empty task-created manager DB reset |

Status `waiting` was injected through the official hook command for a controlled
check; a real approval-dialog transition was not forced. The existing agents'
permission settings were retained. PTY redraws at 80×24 and 150×44 were readable,
but that does not verify Ghostty's physical font rendering or clipboard.
The full updater suite initially deferred because another project had an active
Bats run; it was retried after that run ended. No unrelated process was killed.

Task evidence is local at `~/.planning/2026-09-12-tmux-agent-stack/`. No benchmark
of long-running agent workloads, sandbox isolation test, Pi installation, or
AoE deployment was included.

## Delivery and remaining validation

Chezmoi manages the tmux bindings, package declarations, Agent Manager and
workmux configuration, OMP extension, hook fragments, and this guide.
star-setup manages the updater integration and its regression tests.
Authentication and conversation state remain local.

Physical Ghostty checks remain a follow-up: resize the terminal, inspect glyphs,
try the Option/F3 keys, and verify clipboard behavior. Computer-use access was
denied, so the PTY checks above do not establish those results.

The local evidence directory contains the reviewed patch, backups, validation
logs, and commit/push closeout record:
`~/.planning/2026-09-12-tmux-agent-stack/`.

## Upstream references

- [Agent Manager installation](https://github.com/YoanWai/agent-manager/blob/v0.36.0/docs/install.md), [configuration](https://github.com/YoanWai/agent-manager/blob/v0.36.0/docs/configuration.md), and [usage/recovery](https://github.com/YoanWai/agent-manager/blob/v0.36.0/docs/usage.md).
- [workmux 0.1.261 release](https://github.com/raine/workmux/releases/tag/v0.1.261), [status tracking](https://workmux.raine.dev/guide/status-tracking), and [fork implementation](https://github.com/raine/workmux/blob/v0.1.261/src/multiplexer/conversation.rs).
- [SessionX configuration and dependencies](https://github.com/omerxx/tmux-sessionx) and [the tested preview implementation](https://github.com/omerxx/tmux-sessionx/blob/628575b/scripts/preview.sh).
- [AoE 1.16.0 release](https://github.com/agent-of-empires/agent-of-empires/releases/tag/v1.16.0), [supported agents](https://github.com/agent-of-empires/agent-of-empires/blob/v1.16.0/docs/index.md), [structured views](https://github.com/agent-of-empires/agent-of-empires/blob/v1.16.0/docs/structured-view.md), and [resume behavior](https://github.com/agent-of-empires/agent-of-empires/blob/v1.16.0/docs/guides/session-resume.md).
