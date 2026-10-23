# Terminal Tooling Additions

This directory records the opt-in tools selected by the 2026-07-23 terminal audit and the managed Herdr refresh subsystem. The audit additions do not install Git hooks or edit repositories. The refresh subsystem adds one explicitly loaded Zsh module while preserving unrelated live shell configuration.

The [tmux agent stack guide](tmux-agent-stack.md) covers Agent Manager, workmux, SessionX, update ownership, recovery, and the AoE evaluation.

Run `lhelp` in Zsh for the Eza alias guide, with examples and descriptions read
from your current aliases. See [Eza aliases and lhelp](eza-aliases.md) for the
cheat sheet, plain output, terminal behavior, and verification commands.

## Fresh-Mac Configuration Ownership

Chezmoi owns the portable personal configuration for Zsh, tmux, Git, Atuin,
Bat, btop, ripgrep, Ghostty, Herdr, and Starship. It also tracks the stable
configuration for pane-topic-sync, herdr-lazy, and the Herdr workspace manager.
The Atuin template keeps automatic sync disabled, enables AI, and derives its
daemon socket from the destination home directory. On 2026-09-10, the operator
confirmed that enabling Atuin AI was intentional and is the reproducible state
for new machines.

The repository does not copy credentials, authentication sessions, shell or
Atuin history, recovery bundles, caches, generated Herdr integration hooks, or
Herdr's mutable `plugins.json`. The companion `star-setup` repository installs
packages, deploys Neovim and mise, restores reviewed plugins and integrations,
and runs the end-to-end bootstrap check. It also owns the `zsh-completions`
formula; this directory's scoped Brewfile no longer installs it.

On a replacement Mac, initialize this repository before running the
`star-setup` bootstrap:

```sh
chezmoi init https://github.com/sambatia/dotfiles.git
chezmoi diff
chezmoi apply
```

Review `.gitconfig` after the first apply and confirm the local Git identity and
signing key are correct for the new machine. Sign in to external services
manually; authentication is deliberately outside Chezmoi.

The private source names make terminal additions, Atuin, and Starship mode
`0600` at the destination. Verify the portable subset with:

```sh
bats ~/.config/terminal_setup/tests/reproducibility.bats
```

## Herdr Shell Refresh

The refresh command safely reloads idle Zsh panes without sending input to panes running agents, editors, servers, TUIs, mixed process groups, or unknown foreground processes:

```sh
refresh             # Refresh eligible remote panes, then this shell.
refresh-dry         # Preview remote selection and preflight this shell.
refresh --keep-scrollback  # Preserve prior scrollback; add no success status.
refresh --clear     # Explicit compatibility spelling of the default.
refresh --timeout-ms 20000 # Override each acknowledgement deadline for this run.
clear-panes         # Compatibility command: clear only; do not reload shells.
clear-panes-dry     # Preview the clear-only selection.
refresh-doctor      # Read-only compatibility, preflight, and failure report.
```

Shells opened before this deployment may still have the former aliases cached. Activate the managed functions once in such a shell with `source ~/.zshrc.d/herdr-refresh.zsh`, or start a new login shell.

Plain `refresh` clears each successfully validated pane, passes the documented `HERDR_PANE_ID` to the controller as an exclusion, waits for all eligible remote panes, preflights the invoking shell as a child process, and replaces the invoking shell last. Mutating public commands are silent on success: they write no status marker, concealed text, or acknowledgement escape sequence into any pane. Use `refresh --keep-scrollback` to retain prior output without adding a successful refresh message. If any remote operation remains unresolved after its bounded recovery, or any acknowledgement, clear, or preflight fails terminally, the command returns nonzero, preserves the available diagnostics, and leaves the invoking shell intact.

Shells with jobs are never replaced. The invoking shell checks its own job table before any pane is touched and lists the blocking jobs (`jobs -l`); `refresh-dry` reports the same condition without stopping. For other panes, the owning shell rechecks `${#jobstates}` when the refresh command arrives and reports `SKIP <pane> reason=pending-jobs`. A stopped job, such as a background `sudo` suspended on `tty output` while waiting for a password, is detected before dispatch from Herdr's `shell_pid` and one process-table snapshot per pass, so the pane is reported as `reason=stopped-job pid=N` and receives no input, including in dry runs. Running background jobs remain the owning shell's decision, because a disowned process looks identical from outside. Job skips print even in quiet mode and name the pane by its Herdr label or title (control characters replaced, 40 characters at most).

The controller completes a read-only inspection pass before mutation, then rechecks each candidate immediately before every dispatch. Herdr reports foreground process ownership but does not expose whether an idle shell has partially typed, unsent input; avoid starting a bulk refresh while composing a command in another idle pane. The submitted command shields the absolute worker path behind a disposable, stderr-suppressed no-op so a lost leading input character cannot corrupt the worker invocation.

Before discovery, the controller asks the managed compatibility resolver for a
CLI matching the persistent Herdr server. Dry runs are strictly read-only: they
use the current compatible CLI or an already validated cached client and never
download or populate the cache. Mutating refreshes first save the current
compatible CLI or, only when necessary, fetch the exact server version from the
official Herdr GitHub release. Downloads require the expected official asset
URL, release metadata, byte size, SHA-256 digest, and reported client
version/protocol to agree before atomic publication. Cache directories and
clients are user-owned mode `0700`; symlinks and unsafe directory chains are
rejected. Server inspection also requires exactly one recognized status and,
for a running server, exactly one valid version, protocol, and compatibility
value; missing, duplicated, or contradictory evidence fails closed before any
cache or network operation. Quiet public refreshes suppress routine cache and
download notices while preserving resolver warnings and hard errors. This
avoids an automatic server restart, which would terminate pane processes.

Completion uses unique files inside a controller-owned mode-`0700` temporary directory rather than terminal output. Workers atomically publish an exact digest in a mode-`0600` file only after validation and clearing; bounded file waiters run concurrently, reject malformed files and symlinks, and remove the complete directory afterward. If a dispatch response fails or no acknowledgement arrives, the controller rechecks and retries only that unresolved pane once. Successful peers are never redispatched, and a valid acknowledgement that arrives between rounds completes the pane without a second injection. Both attempts reuse the same private acknowledgement identity, so the worker's atomic publication gate permits only one delayed or duplicate delivery to replace the shell. A malformed acknowledgement or a pane that is no longer exclusively idle Zsh fails immediately; recovered public refreshes remain silent. Each worker also has a shorter internal deadline, preventing a timed-out preflight from replacing its shell later.

Each acknowledgement deadline defaults to 15 seconds. `refresh` and
`refresh-dry` accept `--timeout-ms N` for values from 100 through 60000 and pass
the value unchanged to the controller; timeout failures include the effective
deadline in their diagnostic output.

Failed mutating refreshes save one redacted JSON record under `${XDG_STATE_HOME:-$HOME/.local/state}/herdr-refresh`; successful commands and dry runs never write a record. The directory is mode `0700`, records are mode `0600`, publication is atomic, and only the ten newest matching records are retained. A record contains a UTC timestamp, controller or current-shell component, normalized reason tokens, original exit status, installed Herdr client version, and aggregate counts. It never contains commands, pane IDs or output, cwd, environment variables, session names, socket or temporary paths, raw stderr, or acknowledgement material. Failure recording is best-effort and cannot replace the original refresh status.

Run `refresh-doctor` after a failure or package update. It uses Herdr's supported status command, a controller dry run whose output it suppresses, and the current-shell validation worker, then validates and prints only the newest redacted record. The doctor suppresses raw child output and the Herdr socket path, never sends pane input, and never updates, stops, or restarts Herdr. A server restart remains manual because stopping Herdr exits its pane processes.

The controller is safe to run directly because dry-run is its default. Its clear flag remains explicit because clear-by-default is a policy of the user-facing `refresh` function:

```sh
herdr-refresh-safe-shell-panes
herdr-refresh-safe-shell-panes --dry-run --verbose
herdr-refresh-safe-shell-panes --apply --clear
herdr-refresh-safe-shell-panes --dry-run --timeout-ms 20000
```

Direct controller runs report each pane as `ELIGIBLE`, `SKIP`, `EXCLUDE`, `OK`, or `FAIL`, and summarize `discovered`, `eligible`, `excluded`, `skipped`, `refreshed`, and `failed` counts. The public mutating functions use the controller's quiet mode, which suppresses routine progress and success output but never errors; dry runs remain informative. Exit `0` means discovery and all selected work succeeded, including a valid no-op; exit `1` means at least one selected pane failed; exit `2` means usage, dependency, discovery, server, inspection, or response validation failed.

If startup preflight fails, the affected live shell is not replaced. Read the emitted startup diagnostic, fix the named startup file, and validate before retrying:

```sh
zsh-refresh-current --check
refresh-dry
```

### Optional Zsh Plugin Safety

`~/.zshrc.d/.optional-plugin-loader.zsh` validates each Homebrew-owned optional
plugin in a bounded clean interactive child Zsh before the plugin can mutate the
current shell. The probe resolves package-manager symlinks to one canonical
regular file, sources it with user and global startup files disabled, and
forces every delayed autoload stub to load. Interactive mode also exercises
plugins that otherwise return early outside a terminal. A missing dependency,
parse error, nonzero initializer, or two-second timeout therefore rejects the
plugin before its ZLE hooks can affect typing.

A rejected plugin prints one normalized `zsh-plugin-loader` warning and is
skipped; startup continues with native Zsh behavior. In particular, rejecting
`zsh-autocomplete` leaves Oh My Zsh's standard completion available. Healthy
plugins remain Homebrew-owned and are checked on every new shell, so a
same-version reinstall or on-disk corruption cannot reuse a stale positive
cache.

The refresh worker syntax-checks the loader explicitly and treats any runtime
skip warning as a failed preflight. This prevents automated pane replacement
with a degraded configuration while leaving a directly opened terminal usable
for recovery. After a package update, run:

```sh
zsh-refresh-current --check
```

Do not bypass the warning with a direct `source`. Repair or reinstall the named
package, rerun the check, and then start or refresh shells normally.

### Completion and Interactive Widget Ownership

Homebrew owns `zsh-completions`, and `~/.zshrc.d/completion-paths.zsh` prepends
its completion directory before zsh-autocomplete and Oh My Zsh initialize the
completion system. The module is idempotent and never calls `compinit`; the
existing completion framework remains the sole `compinit` owner. Never use
`compinit -u` to hide an insecure directory. Diagnose with `compaudit` and fix
only the affected user-owned permissions.

`~/.zshrc.d/fzf.zsh` is the fzf integration owner. It configures fd-backed
hidden-file search, bat/eza previews, Ctrl-T file selection, and Alt-C directory
selection before sourcing the integration generated by the installed fzf.
Ctrl-R is explicitly disabled in fzf so Atuin remains the sole history-search
owner. Idempotency checks the process-local ZLE widget registry; the legacy
`FASTOOZ_FZF_LOADED` marker is deliberately shell-local because child shells do
not inherit widgets.

The completion-path helper also removes inherited `fpath` entries that no
longer exist before completion initialization. This matters for terminal apps
and supervisors that outlive a Homebrew upgrade: a new tab can otherwise
inherit Cellar paths belonging to a removed plugin version. Existing directories
are preserved in order, and the current Homebrew completion directory is added
once.

#### Gita and Mani completions

`uv` owns the Gita executable and Homebrew owns the Mani executable. Gita
0.16.8.2 does not ship a compatible Zsh completion. The available upstream
script describes older flags and reads the ambient Gita inventory while the
user presses Tab, so Chezmoi intentionally does not install `_gita`.

Chezmoi owns the reviewed Mani completion at
`~/.oh-my-zsh/custom/completions/_mani`. Oh My Zsh already adds that directory
to `fpath` and initializes completion, so Mani needs no startup hook,
startup-time generation, or extra `compinit` call. The Homebrew formula for
Mani 0.32.1 does not install a completion file.

The file was generated by the official `/opt/homebrew/bin/mani` 0.32.1 binary,
then hardened so every completion request supplies the managed empty project
and user configs under `~/.config/terminal_setup`. Tab completion therefore
cannot load an inherited Mani config or repository fleet. The reviewed file is
8,173 bytes with SHA-256
`99e909212bb4f22107f747e6cc57f44d823b75fe80b4f346273b64bf070d7cf4`.

To update it, verify the Homebrew-owned version and run `mani completion zsh`
in an isolated temporary home with explicit trusted project and user configs.
Reapply the explicit-config guard, inspect the full output, record its byte
count and digest in `tests/dev-workflows.bats`, and run the focused Bats test.
Do not fetch a moving branch or generate completion during shell startup. To
roll it back, remove only `_mani` and the two managed empty config files from
Chezmoi and their deployed targets, then start a new shell. Leave `fpath`,
`.module-order`, and the existing completion initialization unchanged.

Atuin initializes once in `~/.zshrc`, after `additions.zsh`, using the registered
`atuin-search` widget as its guard. The additions file does not initialize Atuin;
Ctrl-R remains Atuin's history binding. Starship, zoxide, direnv, and mise keep
their existing owners and guards. zsh-syntax-highlighting remains
Homebrew-owned and is loaded through the bounded plugin gate after every other
widget integration, as required by upstream.

As of 2026-08-04, Homebrew's stable `zsh-autocomplete` 26.08.03 bottle omits
the release's `z-async` Git submodule. This machine therefore uses Homebrew's
`--HEAD` installation, whose resolved commit `24c4ea8` is the same commit as
the upstream 26.08.03 tag and whose Homebrew Git fetch includes submodules.
Keep this package Homebrew-owned; do not copy dependencies into its Cellar
directory. A future switch back to the stable bottle is safe only after
`zsh-refresh-current --check` passes. If it fails, the loader will skip the
plugin and leave the terminal usable for recovery.

### Zsh Module Inventory

`~/.zshrc.d/.module-order` is the single, ordered inventory of interactive
Zsh modules. `~/.zshrc.d/.module-loader.zsh` validates the entire inventory
before sourcing anything: entries must be unique safe basenames ending in
`.zsh`, every listed file must exist, and every non-hidden on-disk `.zsh` file
must be listed. Arbitrary wildcard auto-loading is intentionally unsupported,
so a backup, partial file, or stale secret cannot become executable shell
configuration merely by appearing in the directory.

The loader deliberately avoids the identifier `module_path`, which is a special
Zsh array used by `zmodload`. Shadowing it while sourcing a child module makes
standard binary modules such as `zsh/regex` resolve relative to the child file;
the production regression suite loads `zsh/regex` through the real loader to
protect this boundary.

The refresh worker invokes that same loader in validation-only mode before its
syntax and runtime startup checks. A missing, malformed, duplicate, or unlisted
module therefore blocks shell replacement with an actionable diagnostic while
leaving the existing interactive shell available for repair. A module that
returns nonzero is named explicitly, stops later modules from loading, and also
blocks refresh even when it did not write its own diagnostic.

To add a module safely:

1. Create `~/.zshrc.d/NAME.zsh`.
2. Add `NAME.zsh` once to `~/.zshrc.d/.module-order` at the required load
   position.
3. Run `zsh-refresh-current --check`.
4. Run `refresh-dry`.
5. Add or re-add both targets with chezmoi and inspect their scoped diff.

If validation reports `invalid module name`, `duplicate module`, `listed module
unavailable`, or `unlisted module`, edit only `.module-order` and the named
module until the inventory is one-to-one, then rerun the two checks above.
Do not bypass validation by sourcing individual modules. Symlinks and
directories are not valid module entries; manage a regular file instead.

Never put credentials in a module. Retrieve secrets from macOS Keychain or
another configured password manager, and scan new managed files before adding
them to the source state.

Shell diagnostics likewise never record command text, working directories, or
environment values. The prompt-latency probe retains only a timestamp and
latency measurement in a mode-`0600` bounded log. This avoids turning routine
shell debugging into a second command-history or credential store. Newly loaded
shells also remove the deprecated `last_cmd.log` left by pre-migration shells.

The production files are managed at:

- `~/.zshrc` — startup orchestration and the module-loader handoff;
- `~/.zshenv` — private-mode, non-interactive environment setup;
- `~/.zshrc.d/.optional-plugin-loader.zsh` — bounded fail-closed plugin preflight;
- `~/.zshrc.d/.module-loader.zsh` — shared inventory validation and ordered loading;
- `~/.zshrc.d/.module-order` — data-only module order;
- `~/.zshrc.d/*.zsh` — the explicitly inventoried non-secret modules;
- `~/.zshrc.d/herdr-refresh.zsh` — stable Zsh user interface;
- `~/.local/bin/refresh-doctor` — redacted failure retention and read-only health report;
- `~/.local/bin/herdr-refresh-safe-shell-panes` — discovery, classification, dispatch, and private acknowledgement coordination;
- `~/.local/libexec/herdr-refresh-client` — private compatible-client resolution, validation, and cache publication;
- `~/.local/bin/zsh-refresh-current` — isolated startup preflight, explicit clearing, and atomic acknowledgement publication.

Preview or deploy only those targets from the chezmoi source directory with explicit paths:

```sh
chezmoi diff \
  ~/.zshrc.d/herdr-refresh.zsh \
  ~/.local/bin/refresh-doctor \
  ~/.local/bin/herdr-refresh-safe-shell-panes \
  ~/.local/libexec/herdr-refresh-client \
  ~/.local/bin/zsh-refresh-current

chezmoi apply \
  ~/.zshrc.d/herdr-refresh.zsh \
  ~/.local/bin/refresh-doctor \
  ~/.local/bin/herdr-refresh-safe-shell-panes \
  ~/.local/libexec/herdr-refresh-client \
  ~/.local/bin/zsh-refresh-current
```

The Bats suites resolve these artifacts from either the chezmoi source tree or
their deployed locations. Run all refresh coverage after changing any component:

```sh
bats \
  ~/.config/terminal_setup/tests/herdr-refresh-client.bats \
  ~/.config/terminal_setup/tests/herdr-refresh.bats \
  ~/.config/terminal_setup/tests/refresh-doctor.bats
```

The 2026-08-01 module hardening reconciled the former `.zshrc` and `.zshenv`
source drift. Continue to use explicit target lists: preview every startup,
loader, manifest, module, and worker target together before applying a module
inventory change. This installation's original refresh rollback record is
`~/.local/state/terminal_setup/refresh-backup/ROLLBACK.md`.
Restore reviewed source versions and start a fresh shell; never restore removed
plaintext credential copies. Existing redacted failure records are bounded
inert state and may be retained or separately moved to Trash.

## Repository Audit

Run conservative checks for the repository containing the current directory:

```sh
repo-audit
```

Or select a repository explicitly:

```sh
repo-audit /path/to/repository
```

The command uses tracked filenames to decide which checks apply, continues after an individual failure, and exits nonzero if any executed check fails. It runs:

| Repository content | Check |
| --- | --- |
| All repositories | `git diff --check` and `typos` |
| GitHub Actions workflows | `actionlint` |
| Shell scripts | `shellcheck` and `shfmt -d` |
| Terraform/OpenTofu | `tofu fmt -check` and `tflint` without plugin downloads |
| CSV or TSV files | `qsv validate` |
| Markdown or HTML | `lychee --offline` |

Missing optional executables are reported as skips. Hurl scenarios, Kubernetes schemas, Docker images, network traces, worktree operations, and Git history rewriting are never executed automatically.

## Output and Viewing Tools

Two focused viewers fill gaps without replacing the existing tools:

- `ov` is the interactive pager for large or tabular text, fixed headers and columns, search/filter, follow, and watch workflows. Use it directly, for example `ov --header 1 --column-delimiter "," --column-mode data.csv` or `ps aux | ov -H1 --column-width --column-rainbow`. Bat remains the source-code and Markdown viewer, Hunk remains Git's pager, and no global `PAGER` is set.
- `fx` is the interactive structured-data explorer. Open JSON with `fx data.json`; select the required parser for other formats with `fx --yaml < data.yaml` or `fx --toml < config.toml`. jq and yq remain the stable, composable choices for scripts and transformations; qsv remains the CSV processing and validation suite.

The commands are intentionally unaliased: both names are already short, and explicit invocation prevents an interactive UI from unexpectedly appearing in redirections, CI, or another program's pager flow.

### Network diagnostics

Use `net-health --quick` for connectivity, latency, loss, DNS and a bounded
route trace. `net-health` also selects Apple's network-quality test. Public speed
tests are explicit: `--speed-provider ookla` or `--librespeed`.
`--json` emits a structured report. The [network diagnostics guide](network-diagnostics.md)
documents options, bandwidth use, status rules, update ownership and rollback.
The standalone package owns Python and Rich; Chezmoi owns only the launcher,
completion and this workstation guide. Interactive runs show a live checklist, completed-check
bar, elapsed timers and a Mocha report. Use `--no-progress` for the styled report
alone or `--plain` for plain text. Pipes and JSON stay free of animation.

### Rich CLI and the Textual viewer

Rich CLI is owned by Homebrew (`rich-cli`, executable `rich`). The official
`textual-dev` package is owned by `uv` and provides the `textual` command plus
the current Textual framework. They use separate environments: Rich CLI 1.8.1
requires older Rich/Textual libraries, while modern Textual needs Rich 14.2 or
newer. The existing Homebrew Python libraries remain untouched.

Package selections are recorded in `recommended-tools.Brewfile` and
`recommended-tools.uv.txt`. On a fresh machine, install these selections with:

```sh
brew install rich-cli
uv tool install --python "$(command -v python3)" --no-python-downloads textual-dev
```

`update-all` discovers both through its existing package-manager inventories.
The Homebrew section upgrades Rich CLI; the `uv` section upgrades `textual-dev`
and its dependencies under the existing security gates. No separate updater,
duplicate package owner, or additional update-all block is needed.

The existing `pretty-tools.zsh` startup module provides these explicit commands:

| Command | Use |
| --- | --- |
| `rshow file.py` | Highlight source or render a supported file format. |
| `rjson data.json` | Pretty-print JSON; `producer | rjson -` accepts stdin. |
| `rcsv data.csv` | Display CSV as a table. |
| `rmd README.md` | Render Markdown. |
| `rshow --ipynb notebook.ipynb` | Render a Jupyter notebook. |
| `rshow --pager file.py` | Open Rich CLI's pager explicitly. |
| `tview file.txt` | Open the read-only Textual file viewer. |
| `textual colors` / `textual keys` | Explore colors or inspect terminal key events. |
| `textual run app.py` | Run a custom Textual application. |

Rich helpers use Mocha's text color and the supported Dracula syntax palette.
They preserve Rich CLI's automatic plain output in pipes and honor `NO_COLOR`.
The Textual viewer uses its built-in `catppuccin-mocha` theme, numbered lines,
`Ctrl+F` to find text, `F3` for the next match, `Alt+W` to toggle wrapping, and
`Ctrl+Q` to quit. It accepts UTF-8 files up to 8 MiB and rejects binary input;
use `ov` or `lnav` for larger files. It does not write to the viewed file.

New shells load these helpers automatically. To load them into an existing
shell without restarting agents, run `source ~/.zshrc.d/pretty-tools.zsh`.
Existing `rview` (macOS Vim), viewers, global pagers, and keybindings are preserved.

The Textual runtime is isolated inside the `textual-dev` tool environment.
Python projects should still declare their own Textual/Rich dependencies.
For rollback, restore the backed-up shell module, manifests and this README,
then remove the task-created viewer/test/uv-manifest files listed in the task
backup manifest. Package removal is separate: `brew uninstall rich-cli` and
`uv tool uninstall textual-dev`, after confirming nothing else now needs them.
Never uninstall the existing Homebrew Python Rich library as part of this rollback.

## Btop Theme

Btop uses the official Catppuccin Mocha theme from `catppuccin/btop`, pinned to
commit `f437574b600f1c6d932627050b15ff5153b58fa3`. Chezmoi installs
`~/.config/btop/themes/catppuccin_mocha.theme` and its MIT notice at
`~/.config/btop/themes/LICENSE-catppuccin`. The managed `btop.conf` selects the
theme by name; no Homebrew theme path or extra package is required.

## Eza Theme

Eza uses the official Catppuccin Mocha theme from `eza-community/eza-themes`. Chezmoi installs the pinned theme and its MIT notice at Eza's native macOS paths:

- `~/Library/Application Support/eza/theme.yml`
- `~/Library/Application Support/eza/LICENSE.eza-themes`

No shell environment variable is needed. Oh My Zsh currently supplies basic `LS_COLORS`, so those file-kind colors keep precedence while the native theme styles metadata, Git state, sizes, permissions, and other fields. Ghostty maps the basic ANSI colors through the existing Catppuccin terminal palette. This preserves cross-tool behavior without stacking Vivid or mutating global color variables.

For first deployment or later restoration, apply the native directory as one scoped target so Chezmoi creates the parent before its two files:

```sh
chezmoi diff "$HOME/Library/Application Support/eza"
chezmoi apply "$HOME/Library/Application Support/eza"
```

## Script Output Contract

Use these defaults for shell scripts and language-specific CLIs so interactive polish never corrupts pipelines or logs:

- Send machine-readable results to stdout. Send progress, prompts, warnings, and diagnostics to stderr.
- Add color and animation only when the destination is an interactive terminal. For stdout in a POSIX shell, test `[ -t 1 ]`; check file descriptor 2 separately when styling stderr.
- Treat a present, non-empty `NO_COLOR` as a request to suppress added ANSI color. An explicit command-line option may override that default for one invocation.
- Keep redirected, piped, and CI output plain and stable. Disable spinners and cursor movement when the relevant stream is not a TTY.
- Prefer Gum for short shell interactions and Rich for formatted Python output because they are already installed. Add a full TUI framework only when the workflow genuinely needs persistent screen state, navigation, or complex widgets.

A minimal decision in a POSIX shell looks like this:

```sh
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  use_color=true
else
  use_color=false
fi
```

Do not export `NO_COLOR` globally unless plain output is the desired workstation default; scripts should honor it when callers choose to set it.

## Project-Local UI Frameworks

Keep application frameworks in the project that uses them so their versions, runtime requirements, tests, and release lifecycle remain reproducible:

| Ecosystem | Preferred opt-in | Adopt when |
| --- | --- | --- |
| Node.js | Clack | A Node CLI needs polished prompts, progress, or task groups beyond a few Gum calls. |
| Python | Textual | A Python application needs a full-screen TUI; keep Rich for non-full-screen output. |
| Go | Charm's Bubble Tea, Lip Gloss, and Huh | A Go CLI needs a stateful TUI, styling system, and forms. |
| Rust | `ratatui` | A Rust application needs a full-screen, stateful terminal UI. |

These are project-local recommendations, not global workstation packages. Add one only to a concrete project after confirming its supported runtime and accessibility/noninteractive behavior.

## Explicit Tools

These examples keep targets visible. Review project-specific configuration before broadening their scope.

- Actionlint: `actionlint`. This validates local GitHub Actions workflows without contacting GitHub.
- Typos: `typos .`. This reports spelling findings; use fix flags only after reviewing a diff.
- Hurl: `hurl --test path/to/test.hurl`. **Network and mutation boundary:** Hurl sends the requests in the file; a test can change a real remote service.
- Worktrunk: `wt list` is the safe starting point, though enriched forge status can make read-only API requests. Commands such as `wt switch --create feature-name` create worktrees and branches. Shell integration was intentionally not installed because the deployed `.zshrc` has pre-existing local drift; after reconciling that file, the optional command is `wt config shell install`.
- Git Absorb: `git absorb --dry-run` previews how staged changes would be assigned. `git absorb` creates local fixup commits, while `--and-rebase` or a later autosquash rewrites history; review the staged diff and branch state first. If an absorb operation must be undone, the project documents `git reset --soft PRE_ABSORB_HEAD` as the recovery point.
- Kubeconform: `kubeconform -strict -summary path/to/manifest.yaml`. Pin `-kubernetes-version X.Y.Z` to the project's deployment target instead of relying on the default `master` schema. **Network boundary:** schemas can be downloaded, and CRDs may need project-specific schema locations.
- TFLint: `tflint --recursive --call-module-type=none`. This avoids module calls; `tflint --init` is intentionally separate because it downloads configured plugins.
- Dive: `dive image:tag`. **Docker boundary:** this opens the selected image and may cause Docker to pull it if it is absent locally.
- qsv: `qsv validate path/to/data.csv`. This performs local structural and UTF-8 validation.
- Trippy: `trip --unprivileged example.com`. **Network boundary:** this sends probes to the named host; do not use a target without authorization.
- Lychee: `lychee --offline --no-progress README.md`. Keep `--offline` for local-only checking; omit it only when external link requests are intended.

## Package Manifest

The manifest owns only this audit's additions:

```sh
HOMEBREW_NO_AUTO_UPDATE=1 brew bundle check \
  --file "$HOME/.config/terminal_setup/recommended-tools.Brewfile"
```

Install missing entries without upgrading unrelated packages:

```sh
HOMEBREW_NO_AUTO_UPDATE=1 brew bundle install --no-upgrade \
  --file "$HOME/.config/terminal_setup/recommended-tools.Brewfile"
```

TFLint moved from a formula to a cask in its official `terraform-linters/tap`. Homebrew requires an explicit trust record for third-party casks, so only this exact cask is trusted:

```sh
brew trust --cask terraform-linters/tap/tflint
```

Existing workstation update automation remains responsible for normal package upgrades. The manifest is an ownership and recovery record, not a second update scheduler.

## Rollback

To roll back only the output enhancements added in this pass, first confirm that no later project depends on them, then run:

```sh
HOMEBREW_NO_AUTO_UPDATE=1 brew uninstall fx ov
/usr/bin/trash \
  "$HOME/Library/Application Support/eza/theme.yml" \
  "$HOME/Library/Application Support/eza/LICENSE.eza-themes"
```

Remove the corresponding two theme source entries from Chezmoi as part of the same rollback. If rolling back the entire workstation audit, remove only the twelve formulae owned by this manifest:

```sh
HOMEBREW_NO_AUTO_UPDATE=1 brew uninstall \
  actionlint dive fx git-absorb hurl kubeconform lychee ov qsv trippy typos-cli worktrunk
```

Then remove TFLint and its narrow trust record:

```sh
HOMEBREW_NO_AUTO_UPDATE=1 brew uninstall --cask terraform-linters/tap/tflint
brew untrust --cask terraform-linters/tap/tflint
```

Remove the tap only after `brew tap-info terraform-linters/tap` confirms nothing else depends on it:

```sh
brew untap terraform-linters/tap
```

The newly managed files can be moved to Trash after removing their matching entries from the chezmoi source. No pre-existing shell, Git, tmux, repository, task, or credential data needs to be restored because those targets are not changed by this installation.
