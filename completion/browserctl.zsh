#compdef browserctl
# zsh completion for browserctl
# Copy to a directory in $fpath, e.g. /usr/local/share/zsh/site-functions/_browserctl

_browserctl() {
  local state

  _arguments \
    '(-v --version)'{-v,--version}'[Print version and exit]' \
    '(-h --help)'{-h,--help}'[Show help]' \
    '--daemon[Connect to named daemon instance]:name:' \
    '1:command:->commands' \
    '*::args:->args'

  case $state in
    commands)
      local commands=(
        'open:Open or focus a named page'
        'close:Close a named page'
        'pages:List open pages'
        'goto:Navigate a page to a URL'
        'fill:Fill an input field'
        'click:Click an element'
        'shot:Take a screenshot'
        'snap:Snapshot DOM'
        'url:Print current URL'
        'eval:Evaluate a JS expression'
        'watch:Wait for a selector to appear'
        'record:Recording commands'
        'run:Run a workflow'
        'workflows:List available workflows'
        'describe:Describe a workflow'
        'ping:Check if browserd is alive'
        'shutdown:Stop browserd'
      )
      _describe 'command' commands
      ;;
    args)
      case ${words[1]} in
        open)
          _arguments \
            '(-u --url)'{-u,--url}'[URL to navigate to]:url:' \
            '(-h --help)'{-h,--help}'[Show help]' \
            '1:page:'
          ;;
        close|pages|goto|url|eval|ping|shutdown)
          _arguments '(-h --help)'{-h,--help}'[Show help]' '1:page:'
          ;;
        shot)
          _arguments \
            '(-o --out)'{-o,--out}'[Output file path]:file:_files' \
            '(-f --full)'{-f,--full}'[Capture full page]' \
            '(-h --help)'{-h,--help}'[Show help]' \
            '1:page:'
          ;;
        snap)
          _arguments \
            '(-f --format)'{-f,--format}'[Output format]:format:(ai html)' \
            '(-d --diff)'{-d,--diff}'[Return only changed elements]' \
            '(-h --help)'{-h,--help}'[Show help]' \
            '1:page:'
          ;;
        fill)
          _arguments \
            '(-r --ref)'{-r,--ref}'[Snapshot ref to fill]:ref:' \
            '(-V --value)'{-V,--value}'[Value to fill]:value:' \
            '(-h --help)'{-h,--help}'[Show help]' \
            '1:page:'
          ;;
        click)
          _arguments \
            '(-r --ref)'{-r,--ref}'[Snapshot ref to click]:ref:' \
            '(-h --help)'{-h,--help}'[Show help]' \
            '1:page:'
          ;;
        watch)
          _arguments \
            '(-t --timeout)'{-t,--timeout}'[Seconds to wait]:seconds:' \
            '(-h --help)'{-h,--help}'[Show help]' \
            '1:page:' '2:selector:'
          ;;
        record)
          local subcommands=('start:Start recording' 'stop:Stop recording and save workflow' 'status:Show recording status')
          _describe 'subcommand' subcommands
          case ${words[2]} in
            stop)
              _arguments \
                '(-o --out)'{-o,--out}'[Output path for workflow file]:file:_files' \
                '(-h --help)'{-h,--help}'[Show help]'
              ;;
          esac
          ;;
        run)
          _arguments '1:workflow:_files'
          ;;
      esac
      ;;
  esac
}

_browserctl "$@"
