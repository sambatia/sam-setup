# Terminal Output Enhancements Design

**Date:** 2026-07-23

**Status:** Approved

## Objective

Close the few material presentation gaps in the existing terminal environment without replacing its strong prompt, pager, syntax-highlighting, tabular-data, or interactive-output stack.

## Current State

The workstation already has mature, complementary tools for nearly every output category: Starship, Bat, Eza, Gum, Glow, Chafa, Hunk, Delta, Difftastic, jq, yq, qsv, lnav, Viddy, Rich, Click, Cyclopts, Pygments, and a true-color Ghostty/Catppuccin environment. The remaining useful gaps are:

- a native Eza theme matching the terminal's Catppuccin Mocha palette;
- a pager optimized for large and tabular text, fixed headers, columns, filtering, follow, and watch workflows;
- an interactive structured-data viewer that complements jq and yq.

The live Chezmoi checkout has unrelated user changes. The active shell files also have local drift, so broad `chezmoi apply`, shell startup rewrites, and global pager changes are unsafe.

## Considered Approaches

### 1. Minimal, native, and scoped (selected)

Add the official Catppuccin Mocha Eza `theme.yml` at Eza's native macOS location. Add `ov` and `fx` to the existing audit-owned Homebrew bundle. Leave `PAGER`, `MANPAGER`, Git's pager, and shell aliases unchanged.

This closes real gaps while preserving Bat for source/Markdown, Hunk for Git, qsv for CSV processing, jq/yq for composable pipelines, and the current shell startup path. Both new executables are short, discoverable commands and do not need aliases.

### 2. Binaries only

Install `ov` and `fx`, but do not add an Eza theme. This is slightly smaller but leaves Eza visually inconsistent with the rest of the Catppuccin setup.

### 3. Broad global integration

Install `ov`, `fx`, and `vivid`; set `PAGER=ov`; generate `LS_COLORS`; add shell aliases and globally install language UI frameworks. This has the highest conflict and maintenance cost. `LS_COLORS` overrides Eza's native theme, a global pager can alter many commands, and project frameworks without owning projects provide no immediate value.

## Selected Architecture

The implementation has three isolated layers:

1. **Package ownership:** add `fx` and `ov` to `~/.config/terminal_setup/recommended-tools.Brewfile`. Install through `brew bundle --no-upgrade` so unrelated packages are not upgraded.
2. **Visual configuration:** manage `~/Library/Application Support/eza/theme.yml` and the upstream MIT notice directly through Chezmoi. This follows Eza's native macOS lookup path, preserves license attribution, and avoids adding `EZA_CONFIG_DIR` to shell startup.
3. **Operational guidance:** extend the terminal-setup README with tool boundaries, examples, the script-output contract, language-specific opt-in guidance, validation, and rollback.

No global pager, Git pager, manual-page pager, shell alias, prompt, terminal emulator, `LS_COLORS`, or `EZA_COLORS` value changes.

## Dependency Decisions

- **Install `ov`:** it handles large/tabular text, fixed headers and columns, follow/watch, and search/filter workflows that Bat and qsv do not cover as an interactive viewer.
- **Install `fx`:** it adds interactive JSON exploration, streaming, JavaScript expressions, and YAML/TOML viewing while retaining jq/yq for automation and stable pipelines.
- **Do not install `vivid`:** Eza's native theme is more direct, and `LS_COLORS`/`EZA_COLORS` take precedence over native themes. Vivid remains an alternative for cross-tool color coordination if that becomes a future requirement.
- **Do not install Clack, Textual, Charm, or `ratatui` globally:** these remain project-local decisions for Node, Python, Go, and Rust CLI projects respectively.

## Output Contract for Scripts

Documentation will establish these defaults for current and future scripts:

- machine-readable data goes to stdout; diagnostics and presentation go to stderr;
- color and animation require an interactive terminal;
- a non-empty `NO_COLOR` disables added ANSI color by default;
- redirected and CI output remains plain and stable;
- explicit command-line options may override defaults;
- Gum or language-native libraries are used only when interaction materially improves the workflow.

The contract is documented rather than injected as a global shell library because no single helper can safely govern unrelated shell, Python, Node, Go, and Rust programs.

## Safety and Rollback

Before deployment, create a timestamped backup directory under `~/.local/state/terminal_setup/` containing checksums, package baselines, and copies of every existing target that will change. The Eza theme target is new, so rollback removes only that exact file after confirming its checksum or restores a prior file if one appears before deployment.

Deployment is target-specific. Never run an unscoped `chezmoi apply` while the existing drift remains. Homebrew installation uses the existing manifest, disables auto-update, and passes `--no-upgrade`.

Rollback consists of:

- restoring the two changed managed text files from backup if needed;
- moving the new Eza theme to Trash, or restoring a prior theme;
- uninstalling only `fx` and `ov` if they were absent at baseline and are not subsequently needed by other installed packages.

## Validation

- Bats tests fail before implementation and pass afterward for manifest ownership, native theme path, theme provenance, no pager takeover, and documentation boundaries.
- `chezmoi execute-template`, `chezmoi diff`, and target-path checks validate source-to-target mapping.
- `brew bundle check` and local Homebrew metadata validate package ownership and compatibility.
- `zsh -n`, ShellCheck, and shfmt confirm no shell regression; the design intentionally avoids shell changes.
- `eza` parses and renders the theme in true color; `NO_COLOR`/plain-output behavior is exercised.
- `fx` is tested with JSON, YAML, TOML, streaming input, and a malformed-input failure.
- `ov` is smoke-tested for help/version, one-screen noninteractive output, tabular column options, and invalid-option failure.
- final checks compare baseline hashes and inspect both the isolated worktree diff and the live Chezmoi drift.

## Compatibility and Maintenance

Homebrew currently provides Apple Silicon bottles for both selected formulae. Eza's theme format and native macOS location are documented by the Eza project. Normal upgrades remain owned by the existing workstation update automation; this bundle is an ownership and recovery record, not another scheduler.

The Chezmoi source repository has a local `.typos.toml` exception for the exact `ratatui` crate identifier. Chezmoi does not treat this hidden repository control file as a managed home target, so the exception fixes source validation without changing global spellchecker behavior.
