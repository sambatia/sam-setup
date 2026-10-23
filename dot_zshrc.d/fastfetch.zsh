# ~/.zshrc.d/fastfetch.zsh — restrained local Ghostty system splash.
# terminal-experience-fastfetch
#
# Keep this local and top-level only: nested shells inherit FASTFETCH_SHOWN;
# remote, Mosh, and tmux sessions stay banner-free.
if [[ -o interactive ]] \
  && [[ -t 0 && -t 1 ]] \
  && [[ -z "${FASTFETCH_SHOWN:-}" ]] \
  && [[ -z "${SSH_CONNECTION:-}${SSH_TTY:-}${MOSH_CONNECTION:-}${MOSH_IP:-}" ]] \
  && [[ -z "${TMUX:-}" ]] \
  && [[ "${TERM_PROGRAM:-}" == "ghostty" || -n "${GHOSTTY_RESOURCES_DIR:-}" ]] \
  && (( ${SHLVL:-1} <= 2 )) \
  && command -v fastfetch >/dev/null 2>&1; then
  export FASTFETCH_SHOWN=1
  fastfetch
fi
