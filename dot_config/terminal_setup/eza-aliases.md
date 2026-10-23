# Eza aliases and lhelp

Run `lhelp` in a new Zsh terminal for a guide to all 20 listing shortcuts.
It groups commands by task and puts an example beside each description.

```sh
lhelp                 # Terminal guide with automatic color and icons
lhelp --plain         # ASCII without color or icons
lhelp --help          # Usage and display options
lhelp > eza-guide.txt  # Plain output, without ANSI escapes
NO_COLOR=1 lhelp       # Keep the layout and Unicode; suppress color
```

The guide reads the current shell's `aliases`, `EZA_BASE`, and `EZA_LONG`.
It does not run Eza, execute aliases, read directories, open a pager, or change
shell settings. If a shortcut has been removed or changed to an unrecognized
definition, the row says so and shows `alias <name>` as its inspection command.
The guide never substitutes a stale description for unknown options.

## Display

On a UTF-8 terminal, the guide uses a Nerd Font folder glyph, the four category
icons, and Catppuccin Mocha colors. The terminal's background is unchanged.
Ghostty's configured JetBrainsMono Nerd Font Mono supplies the header glyph.

At 80 columns or wider, commands, descriptions, and examples occupy aligned
columns. From 48 to 79 columns, examples move below descriptions. Below 48,
each field gets its own line. Text wraps to the current `COLUMNS` value; the
supported range is 16 columns and up, with a maximum content width of 104.

`--plain`, redirected output, and `TERM=dumb` use ASCII with no escape codes.
Setting `NO_COLOR`, even to an empty value, suppresses color. A non-UTF-8 locale
uses ASCII glyphs. Output stays in normal scrollback; no keys or cursor controls
are intercepted.

## Cheat sheet

These are the configured behaviors as of 2026-10-15. `lhelp` derives its current
descriptions from the live alias flags, so it also reflects later supported
changes to sorting, hidden entries, tree depth, and the shared option arrays.

| Category | Alias | What it shows | Example |
|---|---|---|---|
| Everyday File Listing | `ls` | Compact listing | `ls .` |
| Everyday File Listing | `l` | One entry per line | `l ~` |
| Everyday File Listing | `ll` | Details, hidden entries, Git status | `ll ~/Downloads` |
| Everyday File Listing | `la` | Compact listing including hidden entries | `la .` |
| Everyday File Listing | `lla` | Details without hidden entries | `lla ~` |
| Everyday File Listing | `lfull` | Details, hidden entries, Git, groups, links, xattrs | `lfull .` |
| Everyday File Listing | `ld` | Directories only | `ld .` |
| Everyday File Listing | `lf` | Files only | `lf .` |
| Directory Trees | `lt` | Tree, depth 2 | `lt .` |
| Directory Trees | `ltt` | Tree, depth 3 | `ltt .` |
| Directory Trees | `ltl` | Detailed tree, depth 2 | `ltl .` |
| Directory Trees | `ltd` | Directory-only tree, depth 3 | `ltd ~` |
| Git & Development | `lg` | Details, hidden entries, Git status | `lg .` |
| Git & Development | `lgt` | Tree, depth 3, respecting Git ignore rules | `lgt .` |
| Git & Development | `lrepo` | Repository status alongside other entries | `lrepo ~/Projects` |
| Sorting & Analysis | `lnew` | Newest modification first, including hidden entries | `lnew ~/Downloads` |
| Sorting & Analysis | `lold` | Oldest modification first, including hidden entries | `lold .` |
| Sorting & Analysis | `lsize` | Largest first, including hidden entries | `lsize ~/Downloads` |
| Sorting & Analysis | `ldu` | Recursive sizes, largest first | `ldu .` |
| Sorting & Analysis | `lext` | By extension | `lext .` |

The existing aliases group directories first, so sorting applies within each
group. Long views include headers, binary sizes, relative times, and color
scales. `lrepo` marks repository roots; it does not filter out other entries.
`ldu` traverses directory contents and can take time on a large tree. `lg` is an
Eza listing; use `lazygit` for the TUI.

Every listing accepts a path, including quoted paths with spaces:

```sh
ll "folder with spaces"
lt ~/Projects
```

## Ownership and verification

Chezmoi owns `~/.config/zsh/aliases/eza.zsh` and its sibling `eza-help.zsh`.
The existing final `.zshrc` loader sources `eza.zsh`, which loads the helper.
There is one public `lhelp` function and no extra startup plugin or dependency.
Its private helpers use the `_eza_help_` prefix.

To run the focused tests from either the source checkout or the deployed copy:

```sh
bats ~/.config/terminal_setup/tests/eza-aliases.bats \
     ~/.config/terminal_setup/tests/eza-help.bats
```

The lhelp test uses Python's standard library and fresh Zsh processes, including
pseudo-terminals at multiple widths. CI runs it without requiring Eza itself.
The alias behavior suite requires the installed Eza binary.

Existing shells do not automatically load new functions. Open a new tab, or
run `source ~/.config/zsh/aliases/eza.zsh` yourself in an idle Zsh shell.
`command ls`, `/bin/ls`, and the existing `pls` shortcut remain available.
