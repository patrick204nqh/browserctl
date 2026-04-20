# bash completion for browserctl
# Source this file or add to /etc/bash_completion.d/browserctl

_browserctl() {
  local cur prev
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  local commands="open close pages goto fill click shot snap url eval watch record run workflows describe ping shutdown"

  case "${prev}" in
    browserctl)
      COMPREPLY=( $(compgen -W "${commands} --help --version --daemon" -- "${cur}") )
      return 0
      ;;
    open)   COMPREPLY=( $(compgen -W "--url -u --help" -- "${cur}") ); return 0 ;;
    shot)   COMPREPLY=( $(compgen -W "--out -o --full -f --help" -- "${cur}") ); return 0 ;;
    snap)   COMPREPLY=( $(compgen -W "--format -f --diff -d --help" -- "${cur}") ); return 0 ;;
    fill)   COMPREPLY=( $(compgen -W "--ref -r --value -V --help" -- "${cur}") ); return 0 ;;
    click)  COMPREPLY=( $(compgen -W "--ref -r --help" -- "${cur}") ); return 0 ;;
    watch)  COMPREPLY=( $(compgen -W "--timeout -t --help" -- "${cur}") ); return 0 ;;
    record) COMPREPLY=( $(compgen -W "start stop status" -- "${cur}") ); return 0 ;;
    stop)   COMPREPLY=( $(compgen -W "--out -o --help" -- "${cur}") ); return 0 ;;
    run)    COMPREPLY=( $(compgen -f -- "${cur}") ); return 0 ;;
    --format|-f) COMPREPLY=( $(compgen -W "ai html" -- "${cur}") ); return 0 ;;
  esac
}

complete -F _browserctl browserctl
