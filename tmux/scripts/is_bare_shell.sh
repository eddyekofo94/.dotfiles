#!/bin/sh

set -u

tty=${1:-}
test -n "$tty" || exit 1

ps_bin=${BARE_SHELL_PS_BIN:-ps}
foreground_command=$(
    "$ps_bin" -o pid=,tpgid=,comm= -t "$tty" 2>/dev/null |
        awk '$1 == $2 {
            $1 = ""
            $2 = ""
            sub(/^[[:space:]]+/, "")
            print
            exit
        }'
) || exit 1

foreground_command=${foreground_command##*/}
foreground_command=${foreground_command#-}

case "$foreground_command" in
    sh | bash | dash | fish | zsh) exit 0 ;;
    *) exit 1 ;;
esac
