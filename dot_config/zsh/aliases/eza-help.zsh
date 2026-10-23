# lhelp reads the current shell's aliases; it never executes their definitions.

_eza_help_wrap() {
  emulate -L zsh
  local text="$1" word line=''
  local -i limit=$2
  reply=()
  for word in ${(s: :)text}; do
    if [[ -n $line ]] && (( ${#line} + ${#word} + 1 > limit )); then
      reply+=("$line")
      line=''
    fi
    while (( ${#word} > limit )); do
      reply+=("${word[1,limit]}")
      word="${word[limit+1,-1]}"
    done
    [[ -n $word ]] && line+="${line:+ }$word"
  done
  [[ -n $line ]] && reply+=("$line")
  (( ${#reply} )) || reply=('')
  return 0
}

_eza_help_describe() {
  emulate -L zsh
  local body="${aliases[$1]-}" token sort_field='' depth='' description
  local -a tokens options notes
  local -i long=0 hidden=0 tree=0 dirs=0 files=0 reverse=0 total=0
  local -i git=0 repos=0 ignored=0 group=0 links=0 extended=0
  REPLY='Not defined in this shell'
  [[ -n $body ]] || return 1
  tokens=(${(z)body})
  if [[ ${(Q)tokens[1]} != eza ]]; then
    REPLY='Custom alias; inspect definition'
    return 1
  fi
  # Expand only these two known arrays. Tokenization and quote removal do not
  # evaluate substitutions, redirects, commands, or arbitrary parameter names.
  for token in "${tokens[@]:1}"; do
    case $token in
      '"${EZA_BASE[@]}"'|'${EZA_BASE[@]}') options+=("${EZA_BASE[@]}") ;;
      '"${EZA_LONG[@]}"'|'${EZA_LONG[@]}') options+=("${EZA_LONG[@]}") ;;
      *) options+=("${(Q)token}") ;;
    esac
  done
  for token in "${options[@]}"; do
    case $token in
      --long) long=1 ;;
      --all) hidden=1 ;;
      --tree) tree=1 ;;
      --level=<->) depth=${token#*=} ;;
      --only-dirs) dirs=1 ;;
      --only-files) files=1 ;;
      --reverse) reverse=1 ;;
      --total-size) total=1 ;;
      --git) git=1 ;;
      --git-repos) repos=1 ;;
      --git-ignore) ignored=1 ;;
      --group) group=1 ;;
      --links) links=1 ;;
      --extended) extended=1 ;;
      --sort=modified|--sort=date|--sort=age|--sort=size|--sort=extension|--sort=ext|--sort=name)
        sort_field=${token#*=} ;;
      --oneline) sort_field=${sort_field:-oneline} ;;
      --icons=auto|--icons=always|--icons=never|--color=auto|--color=always|--color=never|\
      --hyperlink=auto|--hyperlink=always|--hyperlink=never|--group-directories-first|\
      --header|--binary|--time-style=relative|--color-scale=all) ;;
      *) REPLY='Custom options; inspect definition'; return 1 ;;
    esac
  done

  if (( tree )); then
    description='Tree'
    (( long )) && description='Detailed tree'
    (( dirs )) && description='Directory tree'
    description+=", ${depth:+depth }${depth:-all depths}"
  elif (( repos )); then
    description='Repository status; includes other entries'
  elif (( total )); then
    description='Recursive sizes'
    if [[ $sort_field == size ]]; then
      (( reverse )) && description+='; largest first' || description+='; smallest first'
    fi
  elif [[ $sort_field == modified || $sort_field == date || $sort_field == age ]]; then
    if { [[ $sort_field != age ]] && (( reverse )); } ||
       { [[ $sort_field == age ]] && (( ! reverse )); }; then
      description='Newest modified first'
    else
      description='Oldest modified first'
    fi
  elif [[ $sort_field == size ]]; then
    (( reverse )) && description='Largest first' || description='Smallest first'
  elif [[ $sort_field == extension || $sort_field == ext ]]; then
    description='By extension'
    (( reverse )) && description+=' (reverse)'
  elif (( dirs )); then
    description='Directories only'
  elif (( files )); then
    description='Files only'
  elif [[ $sort_field == oneline ]]; then
    description='One entry per line'
  elif [[ $sort_field == name ]] || (( reverse )); then
    description='By name'
    (( reverse )) && description+=' (reverse)'
  elif (( long )); then
    description='Details'
    (( hidden )) || description+='; visible entries'
  else
    description='Compact listing'
  fi
  (( hidden )) && notes+=(hidden)
  (( git && ! repos )) && notes+=('Git status')
  (( group )) && notes+=(groups)
  (( links )) && notes+=(links)
  (( extended )) && notes+=(xattrs)
  (( ignored )) && notes+=('respects .gitignore')
  (( ${#notes} )) && description+="; ${(j:, :)notes}"
  REPLY=$description
  return 0
}

_eza_help_text() {
  emulate -L zsh
  local text="$1" indent="$2" color="$3" line
  local -a reply
  _eza_help_wrap "$text" "$(( _eh_width - ${#indent} ))"
  for line in "${reply[@]}"; do
    print -r -- "${indent}${color}${line}${_eh_reset}"
  done
}

lhelp() {
  emulate -L zsh
  local option REPLY name title icon description example line rule
  local _eh_reset='' _eh_text='' muted='' command_color='' example_color='' accent=''
  local -a names titles icons palette examples reply wrapped
  local -i plain=0 help=0 rich=0 color=0 _eh_width=80 desc_width live=0 index category

  for option in "$@"; do
    case $option in
      --plain) plain=1 ;;
      --help|-h) help=1 ;;
      *)
        print -u2 -r -- 'Usage: lhelp [--plain] [--help]'
        return 2 ;;
    esac
  done
  if (( help )); then
    print -r -- 'Usage: lhelp [--plain] [--help]

Show the 20 Eza shortcuts, grouped by task, with examples.
Descriptions follow the aliases and EZA arrays in this shell.

  --plain  ASCII output without color or icons.
  --help   Show this help. -h works too.

Color is automatic on terminals; NO_COLOR disables it.
Redirected output and TERM=dumb use plain formatting.
The layout follows COLUMNS. Nothing is executed or paged.'
    return 0
  fi

  [[ ${COLUMNS:-} == <-> ]] && _eh_width=$COLUMNS
  (( _eh_width < 16 )) && _eh_width=16
  (( _eh_width > 104 )) && _eh_width=104
  if (( ! plain )) && [[ -t 1 && -n ${TERM:-} && $TERM != dumb ]]; then
    [[ ${(U)${LC_ALL:-${LC_CTYPE:-${LANG:-}}}} == *UTF*8* ]] && rich=1
    (( ${+NO_COLOR} )) || color=1
  fi
  if (( color )); then
    _eh_reset=$'\e[0m'
    _eh_text=$'\e[38;2;205;214;244m'
    muted=$'\e[38;2;147;153;178m'
    command_color=$'\e[38;2;137;180;250m\e[1m'
    example_color=$'\e[38;2;180;190;254m'
    palette=($'\e[38;2;148;226;213m' $'\e[38;2;166;227;161m'
      $'\e[38;2;203;166;247m' $'\e[38;2;250;179;135m')
  else
    palette=('' '' '' '')
  fi
  names=(ls l ll la lla lfull ld lf lt ltt ltl ltd lg lgt lrepo lnew lold lsize ldu lext)
  titles=('Everyday File Listing' 'Directory Trees' 'Git & Development' 'Sorting & Analysis')
  icons=('📁' '🌳' '🔀' '📊')
  examples=('ls .' 'l ~' 'll ~/Downloads' 'la .' 'lla ~' 'lfull .'
    'ld .' 'lf .' 'lt .' 'ltt .' 'ltl .' 'ltd ~' 'lg .' 'lgt .'
    'lrepo ~/Projects' 'lnew ~/Downloads' 'lold .' 'lsize ~/Downloads' 'ldu .' 'lext .')
  for name in "${names[@]}"; do
    [[ -n ${aliases[$name]-} ]] && (( live += 1 ))
  done

  rule=${(pl:$((_eh_width - 4))::-:)}
  (( rich )) && rule=${rule//-/─}
  print
  print -r -- "  ${muted}${rule}${_eh_reset}"
  icon=''
  (( rich )) && icon=$'\uf07c  '
  # The Nerd Font header glyph occupies one terminal cell; section emoji use two.
  _eza_help_text "${icon}EZA / ALIAS GUIDE" '  ' "$command_color"
  _eza_help_text "$live live aliases | Your filesystem, at a glance" '  ' "$muted"
  print -r -- "  ${muted}${rule}${_eh_reset}"

  for (( index = 1; index <= ${#names}; index++ )); do
    case $index in
      1) category=1 ;;
      9) category=2 ;;
      13) category=3 ;;
      16) category=4 ;;
      *) category=0 ;;
    esac
    if (( category )); then
      print
      accent=${palette[$category]}
      title=${titles[$category]}
      if (( rich )); then
        _eza_help_wrap "$title" "$(( _eh_width - 5 ))"
        print -r -- "  ${accent}${icons[$category]} ${reply[1]}${_eh_reset}"
        for line in "${reply[@]:1}"; do
          print -r -- "     ${accent}${line}${_eh_reset}"
        done
      else
        _eza_help_text "$title" '  ' "$accent"
      fi
    fi

    name=${names[$index]}
    example=${examples[$index]}
    _eza_help_describe "$name" || example="alias $name"
    description=$REPLY
    if (( _eh_width >= 80 )); then
      desc_width=$(( _eh_width - 34 ))
      _eza_help_wrap "$description" "$desc_width"
      wrapped=("${reply[@]}")
      printf '  %s%-7s%s  %s%-*s%s  %s%s%s\n' \
        "$command_color" "$name" "$_eh_reset" "$_eh_text" "$desc_width" "${wrapped[1]}" \
        "$_eh_reset" "$example_color" "$example" "$_eh_reset"
      for line in "${wrapped[@]:1}"; do
        print -r -- "           ${_eh_text}${line}${_eh_reset}"
      done
    elif (( _eh_width >= 48 )); then
      _eza_help_wrap "$description" "$(( _eh_width - 11 ))"
      wrapped=("${reply[@]}")
      printf '  %s%-7s%s  %s%s%s\n' "$command_color" "$name" "$_eh_reset" \
        "$_eh_text" "${wrapped[1]}" "$_eh_reset"
      for line in "${wrapped[@]:1}"; do
        print -r -- "           ${_eh_text}${line}${_eh_reset}"
      done
      _eza_help_text "Try: $example" '           ' "$example_color"
    else
      _eza_help_text "$name" '  ' "$command_color"
      _eza_help_text "$description" '    ' "$_eh_text"
      _eza_help_text "Try: $example" '    ' "$example_color"
    fi
  done
  print
  print -r -- "  ${muted}${rule}${_eh_reset}"
  _eza_help_text 'Quote paths with spaces. Use alias <name> to inspect a shortcut.' '  ' "$muted"
  _eza_help_text 'lhelp --plain | lhelp --help' '  ' "$example_color"
  print
}
