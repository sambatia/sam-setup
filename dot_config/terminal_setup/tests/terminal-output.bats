#!/usr/bin/env bats

load lib/source-root

setup() {
  TS_SOURCE_ROOT="$(terminal_setup_source_root)" ||
    TS_SOURCE_ROOT="${TS_SOURCE_ROOT}"
  export TS_SOURCE_ROOT
	export REPO_ROOT
	REPO_ROOT="$(cd "${TS_SOURCE_ROOT}" && pwd)"
	export BREWFILE="${REPO_ROOT}/dot_config/terminal_setup/recommended-tools.Brewfile"
	export README="${REPO_ROOT}/dot_config/terminal_setup/README.md"
	export THEME="${REPO_ROOT}/private_Library/private_Application Support/eza/theme.yml"
	export THEME_LICENSE="${REPO_ROOT}/private_Library/private_Application Support/eza/LICENSE.eza-themes"
	export TYPOS_CONFIG="${REPO_ROOT}/.typos.toml"
}

@test "the package manifest owns each focused viewer exactly once" {
	run grep -Ec '^brew "fx"$' "$BREWFILE"
	[ "$status" -eq 0 ]
	[ "$output" -eq 1 ]

	run grep -Ec '^brew "ov"$' "$BREWFILE"
	[ "$status" -eq 0 ]
	[ "$output" -eq 1 ]
}

@test "the package manifest does not add the conflicting vivid layer" {
	run grep -Ec '^brew "vivid"$' "$BREWFILE"
	[ "$status" -eq 1 ]
	[ "$output" -eq 0 ]
}

@test "the native macOS Eza theme is the attributed Catppuccin Mocha theme" {
	[ -f "$THEME" ]
	run grep -F 'github.com/eza-community/eza-themes' "$THEME"
	[ "$status" -eq 0 ]
	run grep -F 'Retrieved: 2026-07-23' "$THEME"
	[ "$status" -eq 0 ]
	run grep -F 'directory: {foreground: "#89B4FA"}' "$THEME"
	[ "$status" -eq 0 ]
	run grep -F 'git_dirty: {foreground: "#F38BA8"}' "$THEME"
	[ "$status" -eq 0 ]
}

@test "the copied upstream Eza theme preserves its MIT license notice" {
	[ -f "$THEME_LICENSE" ]
	run grep -F 'The MIT License (MIT)' "$THEME_LICENSE"
	[ "$status" -eq 0 ]
	run grep -F 'Copyright (c) 2024 Sandro-Alessio Gierens' "$THEME_LICENSE"
	[ "$status" -eq 0 ]
}

@test "the managed output layer does not take over global pagers or color variables" {
	run grep -E '^[[:space:]]*(export[[:space:]]+)?(PAGER|MANPAGER|GIT_PAGER|LS_COLORS|EZA_COLORS)=' \
		"$BREWFILE" "$README" "$THEME"
	[ "$status" -eq 1 ]
}

@test "documentation defines the noninteractive script output contract" {
	run grep -F 'NO_COLOR' "$README"
	[ "$status" -eq 0 ]
	run grep -F '[ -t 1 ]' "$README"
	[ "$status" -eq 0 ]
	run grep -F 'stdout' "$README"
	[ "$status" -eq 0 ]
	run grep -F 'stderr' "$README"
	[ "$status" -eq 0 ]
}

@test "documentation keeps language UI frameworks project local" {
	for framework in Clack Textual Charm; do
		run grep -F "$framework" "$README"
		[ "$status" -eq 0 ]
	done
	run grep -F "\`ratatui\`" "$README"
	[ "$status" -eq 0 ]
	run grep -F 'project-local' "$README"
	[ "$status" -eq 0 ]
}

@test "documentation explains focused roles and exact rollback" {
	run grep -F "\`ov\`" "$README"
	[ "$status" -eq 0 ]
	run grep -F "\`fx\`" "$README"
	[ "$status" -eq 0 ]
	run grep -E 'brew uninstall([^[:alnum:]]|.*[[:space:]])fx([[:space:]]|$)' "$README"
	[ "$status" -eq 0 ]
	run grep -E 'brew uninstall([^[:alnum:]]|.*[[:space:]])ov([[:space:]]|$)' "$README"
	[ "$status" -eq 0 ]
	run grep -F 'Library/Application Support/eza/theme.yml' "$README"
	[ "$status" -eq 0 ]
}

@test "documentation uses the supported fx YAML and TOML invocation forms" {
	run grep -F 'fx --yaml < data.yaml' "$README"
	[ "$status" -eq 0 ]
	run grep -F 'fx --toml < config.toml' "$README"
	[ "$status" -eq 0 ]
}

@test "documentation deploys the new Eza parent directory as one scoped target" {
	run grep -F "chezmoi apply \"\$HOME/Library/Application Support/eza\"" "$README"
	[ "$status" -eq 0 ]
}

@test "the repository spelling policy preserves the exact ratatui crate name" {
	[ -f "$TYPOS_CONFIG" ]
	run grep -F 'ratatui = "ratatui"' "$TYPOS_CONFIG"
	[ "$status" -eq 0 ]
	run typos --config "$TYPOS_CONFIG" "$README"
	[ "$status" -eq 0 ]
}

@test "the repository spelling policy is not deployed as a home target" {
	run chezmoi --source "$REPO_ROOT" managed --include=files
	[ "$status" -eq 0 ]
	[[ "$output" != *".typos.toml"* ]]
}
