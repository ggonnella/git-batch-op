#/usr/bin/env bash

_ggscripts_g_complete()
{
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  if [ "$COMP_CWORD" == 1  ]; then
    operations=$(g --list-operations)
    COMPREPLY=( $(compgen -W "${operations}" -- $cur) )
  elif [ "$COMP_CWORD"  == 2 ]; then
    if [ "$prev" == "up" ]; then
      targets=$(g --list-up-targets)
    else
      targets=$(g --list-targets)
    fi
    COMPREPLY=( $(compgen -W "${targets}" -- $cur) )
  fi
}
complete -F _ggscripts_g_complete g
