# ╔══════════════════════════════════════════════════════════════╗
# ║                 EZA — PREMIUM FILE LISTING                  ║
# ║          Modern • Beautiful • Git-Aware • macOS             ║
# ╚══════════════════════════════════════════════════════════════╝

# ────────────────────────────────────────────────────────────────
# 🎨 GLOBAL CONFIGURATION
# ────────────────────────────────────────────────────────────────

export EZA_ICON_SPACING=2

# Common visual defaults
EZA_BASE=(
  --icons=auto
  --color=auto
  --hyperlink=auto
  --group-directories-first
)

# Rich metadata presentation
EZA_LONG=(
  --long
  --header
  --binary
  --time-style=relative
  --color-scale=all
)


# ────────────────────────────────────────────────────────────────
# 📁 EVERYDAY FILE LISTING
# ────────────────────────────────────────────────────────────────

# Beautiful default listing
alias ls='eza "${EZA_BASE[@]}"'

# Quick compact listing
alias l='eza "${EZA_BASE[@]}" --oneline'

# Premium replacement for ls -lah
alias ll='eza "${EZA_BASE[@]}" "${EZA_LONG[@]}" --all --git'

# All files, including hidden
alias la='eza "${EZA_BASE[@]}" --all'

# Detailed listing without hidden files
alias lla='eza "${EZA_BASE[@]}" "${EZA_LONG[@]}"'

# Maximum detail, including extended attributes
alias lfull='eza "${EZA_BASE[@]}" "${EZA_LONG[@]}" --all --git --group --links --extended'


# ────────────────────────────────────────────────────────────────
# 🌳 DIRECTORY TREES
# ────────────────────────────────────────────────────────────────

# Beautiful directory tree (2 levels)
alias lt='eza "${EZA_BASE[@]}" --tree --level=2'

# Deeper directory tree (3 levels)
alias ltt='eza "${EZA_BASE[@]}" --tree --level=3'

# Detailed tree with metadata
alias ltl='eza "${EZA_BASE[@]}" "${EZA_LONG[@]}" --tree --level=2'

# Directories only
alias ld='eza "${EZA_BASE[@]}" --only-dirs'

# Directory tree only
alias ltd='eza "${EZA_BASE[@]}" --tree --only-dirs --level=3'


# ────────────────────────────────────────────────────────────────
# 🔀 GIT & DEVELOPMENT
# ────────────────────────────────────────────────────────────────

# Git-aware detailed listing
alias lg='eza "${EZA_BASE[@]}" "${EZA_LONG[@]}" --all --git'

# Git-aware tree
alias lgt='eza "${EZA_BASE[@]}" --tree --level=3 --git-ignore'

# Mark Git repository roots and their status (does not filter other entries)
alias lrepo='eza "${EZA_BASE[@]}" "${EZA_LONG[@]}" --git-repos'


# ────────────────────────────────────────────────────────────────
# 📊 SORTING & ANALYSIS
# ────────────────────────────────────────────────────────────────

# Newest modified files first
alias lnew='eza "${EZA_BASE[@]}" "${EZA_LONG[@]}" --all --sort=modified --reverse'

# Oldest modified files first
alias lold='eza "${EZA_BASE[@]}" "${EZA_LONG[@]}" --all --sort=modified'

# Largest files first
alias lsize='eza "${EZA_BASE[@]}" "${EZA_LONG[@]}" --all --sort=size --reverse'

# Directory sizes (recursive calculation)
alias ldu='eza "${EZA_BASE[@]}" "${EZA_LONG[@]}" --total-size --sort=size --reverse'

# Sort by file extension
alias lext='eza "${EZA_BASE[@]}" "${EZA_LONG[@]}" --sort=extension'

# Show files only
alias lf='eza "${EZA_BASE[@]}" --only-files'

# Keep the guide beside its aliases; repeat sourcing only refreshes its functions.
if [[ -r "${${(%):-%N}:A:h}/eza-help.zsh" ]]; then
  source "${${(%):-%N}:A:h}/eza-help.zsh"
fi
