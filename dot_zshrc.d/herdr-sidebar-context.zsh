# ~/.zshrc.d/herdr-sidebar-context.zsh — concise local context for Herdr.
#
# Herdr's terminal_title_stripped row is intentionally blank unless a pane
# reports title metadata. In Herdr-managed Zsh panes, report only PWD's
# basename (never the full path) as a title and as the $project fallback token.
if [[ "${HERDR_ENV:-}" == "1" && -n "${HERDR_PANE_ID:-}" ]] \
  && command -v herdr >/dev/null 2>&1 \
  && [[ -z "${_HERDR_SIDEBAR_CONTEXT_HOOKED:-}" ]]; then
  typeset -g _HERDR_SIDEBAR_CONTEXT_HOOKED=1
  typeset -g _HERDR_SIDEBAR_CONTEXT_LAST=""

  _herdr_sidebar_report_context() {
    local _herdr_sidebar_project="${PWD:t}"
    local _herdr_sidebar_context_key="${HERDR_PANE_ID}:${_herdr_sidebar_project}"
    [[ "$_herdr_sidebar_context_key" == "${_HERDR_SIDEBAR_CONTEXT_LAST:-}" ]] && return 0
    _HERDR_SIDEBAR_CONTEXT_LAST="$_herdr_sidebar_context_key"

    command herdr pane report-metadata "$HERDR_PANE_ID" \
      --source zsh-sidebar-context \
      --title "$_herdr_sidebar_project" \
      --token "project=$_herdr_sidebar_project" \
      --ttl-ms 86400000 >/dev/null 2>&1 &!
  }

  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _herdr_sidebar_report_context
  add-zsh-hook chpwd _herdr_sidebar_report_context
  if [[ -z "${REFRESH_SENTINEL:-}" ]]; then
    _herdr_sidebar_report_context
  fi
fi
