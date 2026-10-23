# Validate and load the explicitly ordered ~/.zshrc.d modules.

_terminal_zsh_module_error() {
  print -u2 -r -- "zsh-module-loader: $*"
}

terminal_validate_zsh_modules() {
  emulate -L zsh
  setopt local_options extended_glob no_aliases no_glob_dots

  if (( $# != 2 )); then
    _terminal_zsh_module_error 'validation requires MODULE_DIR and MANIFEST'
    return 2
  fi

  local module_dir="$1"
  local manifest="$2"
  local module_name module_file disk_path
  local -A seen
  local -a modules
  reply=()

  [[ -d "$module_dir" ]] || {
    _terminal_zsh_module_error "module directory unavailable: $module_dir"
    return 1
  }
  [[ -f "$manifest" && -r "$manifest" ]] || {
    _terminal_zsh_module_error "manifest unavailable: $manifest"
    return 1
  }

  while IFS= read -r module_name || [[ -n "$module_name" ]]; do
    [[ -z "$module_name" || "$module_name" == \#* ]] && continue
    [[ "$module_name" == [A-Za-z0-9][A-Za-z0-9._-]#.zsh ]] || {
      _terminal_zsh_module_error "invalid module name: $module_name"
      return 1
    }
    (( ${+seen[$module_name]} == 0 )) || {
      _terminal_zsh_module_error "duplicate module: $module_name"
      return 1
    }
    module_file="${module_dir}/${module_name}"
    [[ -f "$module_file" && ! -L "$module_file" ]] || {
      _terminal_zsh_module_error "listed module unavailable: $module_name"
      return 1
    }
    seen[$module_name]=1
    modules+=("$module_file")
  done <"$manifest"

  for disk_path in "$module_dir"/*.zsh(N); do
    module_name="${disk_path:t}"
    (( ${+seen[$module_name]} )) || {
      _terminal_zsh_module_error "unlisted module: $module_name"
      return 1
    }
  done

  reply=("${modules[@]}")
}

terminal_load_zsh_modules() {
  terminal_validate_zsh_modules "$@" || return

  # `module_path` is a special Zsh array used by zmodload. Never shadow it while
  # a child module is sourced or binary modules such as zsh/regex cannot load.
  local module_file module_status
  for module_file in "${reply[@]}"; do
    source "$module_file"
    module_status=$?
    if (( module_status != 0 )); then
      _terminal_zsh_module_error "module failed: ${module_file:t} (status ${module_status})"
      return "$module_status"
    fi
  done
}

if [[ "${ZSH_EVAL_CONTEXT:-}" == toplevel ]]; then
  if (( $# == 3 )) && [[ "$1" == --validate ]]; then
    terminal_validate_zsh_modules "$2" "$3"
    exit $?
  fi
  print -u2 -r -- 'Usage: .module-loader.zsh --validate MODULE_DIR MANIFEST'
  exit 2
fi
