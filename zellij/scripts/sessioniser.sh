#!/bin/bash

zellij "$@"

zfile="/tmp/zellij_last_session"
sleep .1
while [ -f "$zfile" ] ; do
    last_session="$(/bin/cat $zfile)"
    rm "$zfile"
    new_session="$(zellij list-sessions -n -s | fzf)"
    if [[ "$new_session" == "" ]] ; then
        new_session="$last_session"
    fi
    zellij a "$new_session"
    sleep .1
done

