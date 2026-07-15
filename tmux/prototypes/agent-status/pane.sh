#!/usr/bin/env bash

# THROWAWAY PROTOTYPE: static instructions for a simulated agent pane.

set -u

agent=$1
project=$2

clear
printf '\033[1m%s:%s\033[0m\n\n' "$agent" "$project"
printf 'Select this pane, then press Ctrl-a followed by:\n\n'
printf '  n  ready/start       r  running\n'
printf '  q  question          p  permission\n'
printf '  g  finished          f  failed\n'
printf '  x  exit              d  detach/clean up\n\n'
printf '\033[2mThe pane border and window tab re-render after every event.\033[0m\n'

while :; do
    sleep 3600
done
