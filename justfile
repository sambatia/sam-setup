# sam-setup — task runner. Run `just` to list recipes.
set shell := ["bash", "-cu"]

# Plain (non-template) shell scripts we lint.
SCRIPTS := "bootstrap.sh tests/run-bootstrap-tests.sh .chezmoiscripts/run_once_before_05-backup-existing.sh .chezmoiscripts/run_after_20-ssh-key.sh .chezmoiscripts/run_once_after_30-tmux-tpm.sh dot_local/bin/executable_sam-setup-restore dot_local/bin/executable_sam-setup-check dot_local/bin/executable_sam-setup-help dot_local/bin/executable_update-all"

default:
    @just --list --unsorted

# ── Quality ──────────────────────────────────────────────────────
# shellcheck every plain bash script (the .tmpl files are chezmoi templates)
lint:
    @command -v shellcheck >/dev/null 2>&1 || (echo "✗ shellcheck not installed" && exit 1)
    shellcheck -S warning {{SCRIPTS}}

# unit tests (consent, keygen guard, restore, template render)
test:
    @./tests/run-bootstrap-tests.sh

# the gate to run before committing
check: lint test
    @echo "✅ all checks passed"

# format scripts with shfmt when available (optional)
fmt:
    @command -v shfmt >/dev/null 2>&1 && shfmt -w -i 2 -ci {{SCRIPTS}} || echo "shfmt not installed (optional)"

# ── Maintenance ──────────────────────────────────────────────────
# Regenerate the Brewfile from THIS machine (mas + vscode stripped). Review casks after.
brewfile-refresh:
    @command -v brew >/dev/null 2>&1 || (echo "✗ brew not found" && exit 1)
    brew bundle dump --force --file=Brewfile.full
    grep -vE '^(mas|vscode) ' Brewfile.full > Brewfile.body && rm -f Brewfile.full
    @{ sed -n '1,4p' Brewfile; echo; cat Brewfile.body; } > Brewfile.new && mv Brewfile.new Brewfile && rm -f Brewfile.body
    @echo "✅ Brewfile refreshed — review casks before committing"

# Preview what `chezmoi update` WOULD change on this machine (no writes)
preview:
    @chezmoi diff --source="$(pwd)" || echo "run from a machine where chezmoi is initialized"

# ── Release ──────────────────────────────────────────────────────
# Cut a release tag (the one-liner pins to it). Usage: just release v0.2.0
release VERSION:
    @git diff --quiet || (echo "✗ working tree dirty — commit first" && exit 1)
    @just check
    git tag -a {{VERSION}} -m "sam-setup {{VERSION}}"
    git push origin main --tags
    @echo "✅ {{VERSION}} tagged + pushed. Update the one-liner in README.md to {{VERSION}}."
