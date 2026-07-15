#!/usr/bin/env bash

# THROWAWAY PROTOTYPE: pure state and presentation functions.

agent_status_next_state() {
    current=$1
    event=$2

    case "$event" in
        start) printf '%s\n' ready ;;
        prompt) printf '%s\n' running ;;
        question) printf '%s\n' question ;;
        permission) printf '%s\n' permission ;;
        complete) printf '%s\n' finished ;;
        fail) printf '%s\n' failed ;;
        exit)
            if [ "$current" = failed ]; then
                printf '%s\n' failed
            else
                printf '%s\n' absent
            fi
            ;;
        *) return 2 ;;
    esac
}
agent_status_icon() {
    state=$1
    frame=${2:-0}

    case "$state" in
        ready|finished) printf '%s' '' ;;
        question) printf '%s' '' ;;
        permission) printf '%s' '' ;;
        failed) printf '%s' '' ;;
        running)
            case $((frame % 8)) in
                0) printf '%s' '⠋' ;;
                1) printf '%s' '⠙' ;;
                2) printf '%s' '⠹' ;;
                3) printf '%s' '⠸' ;;
                4) printf '%s' '⠼' ;;
                5) printf '%s' '⠴' ;;
                6) printf '%s' '⠦' ;;
                7) printf '%s' '⠧' ;;
            esac
            ;;
        *) return 2 ;;
    esac
}

agent_status_color() {
    case "$1" in
        running) printf '%s' '#89b4fa' ;;
        question) printf '%s' '#fab387' ;;
        permission|failed) printf '%s' '#f38ba8' ;;
        ready|finished) printf '%s' '#a6e3a1' ;;
        *) return 2 ;;
    esac
}

agent_status_project() {
    project=$1
    max_length=16

    if [ "${#project}" -le "$max_length" ]; then
        printf '%s' "$project"
        return
    fi

    printf '%s…%s' "${project:0:8}" "${project: -7}"
}
