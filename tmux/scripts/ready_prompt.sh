#!/usr/bin/env bash

# Replay labeled agent handoffs into the current tmux pane. Parsing and agent
# support stay intentionally narrow so uncertain states fail closed.

set -u

TMUX_BIN=${TMUX_BIN:-tmux}
CAPTURE_LINES=${READY_PROMPT_CAPTURE_LINES:-2000}
READY_ATTEMPTS=${READY_PROMPT_READY_ATTEMPTS:-50}
READY_INTERVAL=${READY_PROMPT_READY_INTERVAL:-0.1}
CLEAR_CONFIRM_INTERVAL=${READY_PROMPT_CLEAR_CONFIRM_INTERVAL:-0.2}

extract_prompt() {
    input=$1

    tail -n "$CAPTURE_LINES" "$input" | awk '
        function trim(value) {
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            return value
        }

        function label_line(value, rest, marker) {
            value = trim(value)
            sub(/^-[[:space:]]+/, "", value)
            sub(/^#+[[:space:]]+/, "", value)

            marker = "**Ready-to-paste prompt:**"
            if (index(value, marker) == 1) {
                rest = substr(value, length(marker) + 1)
            } else {
                marker = "**Ready-to-paste prompt**"
                if (index(value, marker) == 1) {
                    rest = substr(value, length(marker) + 1)
                } else {
                    marker = "Ready-to-paste prompt"
                    if (index(value, marker) != 1) {
                        return 0
                    }
                    rest = substr(value, length(marker) + 1)
                }
            }

            if (rest != "" && rest !~ /^([[:space:]]|:)/) {
                return 0
            }
            rest = trim(rest)
            sub(/^:[[:space:]]*/, "", rest)
            label_rest = rest
            return 1
        }

        function inline_prompt(value, closing, tail_value) {
            value = trim(value)
            if (substr(value, 1, 1) != "`" || substr(value, 1, 3) == "```") {
                return 0
            }
            closing = index(substr(value, 2), "`")
            if (closing == 0) {
                return 0
            }
            inline_value = substr(value, 2, closing - 1)
            tail_value = trim(substr(value, closing + 2))
            return inline_value != "" && tail_value == ""
        }

        function nonblank(value) {
            return value ~ /[^[:space:]]/
        }

        function next_move_line(value, rest) {
            value = trim(value)
            sub(/^-[[:space:]]+/, "", value)
            sub(/^\*\*/, "", value)
            if (index(value, "Next move:") != 1) {
                return 0
            }
            rest = trim(substr(value, length("Next move:") + 1))
            sub(/^\*\*[[:space:]]*/, "", rest)
            next_move_rest = rest
            return 1
        }

        function terminal_chrome(value) {
            value = trim(value)
            return value ~ /^[─━].*Worked for/ || \
                value ~ /^[›❯][[:space:]]/ || \
                value ~ /^gpt-[[:alnum:]._-]+[[:space:]]/
        }

        {
            line = $0

            if (trim(line) == "READY_TO_PASTE_BEGIN_V1") {
                saw_marker = 1
                marker_position = NR
                marker_status = 1
                marker_state = "collect"
                marker_value = ""
                next
            }

            if (marker_state == "collect") {
                if (trim(line) == "READY_TO_PASTE_END_V1") {
                    if (nonblank(marker_value)) {
                        marker_status = 2
                    }
                    marker_state = "done"
                } else if (marker_value == "") {
                    marker_value = line
                } else {
                    marker_value = marker_value "\n" line
                }
                next
            }

            if (state == "fence") {
                if (line ~ /^[[:space:]]*```[[:space:]]*$/) {
                    if (nonblank(fenced_value)) {
                        candidate = fenced_value
                        candidate_status = 2
                    } else {
                        candidate = ""
                        candidate_status = 1
                    }
                    state = "done"
                } else if (fenced_value == "") {
                    fenced_value = line
                } else {
                    fenced_value = fenced_value "\n" line
                }
                next
            }

            if (label_line(line)) {
                saw_label = 1
                label_position = NR
                candidate = ""
                candidate_status = 1
                fenced_value = ""
                state = "waiting"

                if (label_rest != "") {
                    if (inline_prompt(label_rest)) {
                        candidate = inline_value
                        candidate_status = 2
                        state = "done"
                    } else {
                        state = "malformed"
                    }
                }
                next
            }

            if (state == "plain") {
                if (terminal_chrome(line)) {
                    state = "done"
                } else if (!nonblank(line)) {
                    plain_blank_count++
                } else {
                    while (plain_blank_count > 0) {
                        candidate = candidate "\n"
                        plain_blank_count--
                    }
                    candidate = candidate "\n" line
                }
                next
            }

            # Older skill-finish closeouts occasionally omitted the explicit
            # label but still put the paste-ready paragraph immediately after
            # their "Next move:" line. Accept only that narrow structure.
            if (next_move_line(line)) {
                fallback_value = ""
                fallback_inline = next_move_rest
                fallback_state = "waiting"
                next
            }

            if (fallback_state == "waiting") {
                if (!nonblank(line)) {
                    next
                }
                if (terminal_chrome(line)) {
                    fallback_state = "done"
                    next
                }
                fallback_value = line
                fallback_state = "paragraph"
                next
            }

            if (fallback_state == "paragraph") {
                if (!nonblank(line)) {
                    fallback_state = "done"
                } else if (terminal_chrome(line)) {
                    fallback_state = "done"
                } else {
                    fallback_value = fallback_value "\n" line
                }
            }

            if (state == "waiting") {
                if (line ~ /^[[:space:]]*$/) {
                    next
                }
                if (line ~ /^[[:space:]]*```[^`]*$/) {
                    state = "fence"
                    next
                }
                if (inline_prompt(line)) {
                    candidate = inline_value
                    candidate_status = 2
                    state = "done"
                } else if (substr(trim(line), 1, 1) == "`") {
                    state = "malformed"
                } else {
                    candidate = line
                    candidate_status = 2
                    plain_blank_count = 0
                    state = "plain"
                }
            }
        }

        END {
            if (saw_marker && marker_position > label_position) {
                if (marker_status != 2) {
                    exit 11
                }
                printf "%s", marker_value
                exit 0
            }
            if (!saw_label) {
                if (nonblank(fallback_value)) {
                    printf "%s", fallback_value
                    exit 0
                }
                if (nonblank(fallback_inline)) {
                    printf "%s", fallback_inline
                    exit 0
                }
                exit 10
            }
            if (candidate_status != 2) {
                exit 11
            }
            printf "%s", candidate
        }
    '
}

recognized_agent() {
    command_name=$(basename -- "$1" | tr '[:upper:]' '[:lower:]')
    case "$command_name" in
        codex|claude|opencode|gemini|agy)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

clear_supported_agent() {
    command_name=$(basename -- "$1" | tr '[:upper:]' '[:lower:]')
    case "$command_name" in
        codex)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

wait_for_codex_ready() {
    ready_screen=$work_dir/ready-screen.txt
    attempt=0
    stable=0

    while [ "$attempt" -lt "$READY_ATTEMPTS" ]; do
        if ! "$TMUX_BIN" capture-pane -p -J -t "$pane" >"$ready_screen"; then
            return 1
        fi

        if grep -Eq '^[[:space:]]*›' "$ready_screen" && \
                ! grep -Eq '^[[:space:]]*›[[:space:]]*/clear([[:space:]]|$)' "$ready_screen" && \
                ! grep -Fq 'Queued follow-up inputs' "$ready_screen" && \
                ! grep -Eq 'model:[[:space:]]+loading' "$ready_screen"; then
            stable=$((stable + 1))
            if [ "$stable" -ge 2 ]; then
                return 0
            fi
        else
            stable=0
        fi

        sleep "$READY_INTERVAL" || return 1
        attempt=$((attempt + 1))
    done

    return 1
}

submit_codex_clear() {
    clear_screen=$work_dir/clear-submit-screen.txt

    "$TMUX_BIN" send-keys -t "$pane" -l '/clear' || return 1
    "$TMUX_BIN" send-keys -t "$pane" Enter || return 1
    sleep "$CLEAR_CONFIRM_INTERVAL" || return 1
    "$TMUX_BIN" capture-pane -p -J -t "$pane" >"$clear_screen" || return 1

    # Current Codex may use the first Enter to resolve the slash-command menu,
    # leaving /clear active in the multiline composer. Confirm it only when the
    # command is still visible; never send a blind second Enter.
    if grep -Eq '^[[:space:]]*›[[:space:]]*/clear([[:space:]]|$)' "$clear_screen"; then
        "$TMUX_BIN" send-keys -t "$pane" Enter || return 1
    fi
}

show_message() {
    "$TMUX_BIN" display-message -t "$pane" "$1"
}

case ${1:-} in
    --extract)
        [ "$#" -eq 2 ] || { echo "usage: ready_prompt.sh --extract FILE" >&2; exit 2; }
        case "$CAPTURE_LINES" in
            ""|*[!0-9]*) echo "READY_PROMPT_CAPTURE_LINES must be a positive integer" >&2; exit 2 ;;
            0) echo "READY_PROMPT_CAPTURE_LINES must be a positive integer" >&2; exit 2 ;;
        esac
        extract_prompt "$2"
        exit $?
        ;;
    --recognize)
        [ "$#" -eq 2 ] || { echo "usage: ready_prompt.sh --recognize COMMAND" >&2; exit 2; }
        recognized_agent "$2"
        exit $?
        ;;
    --clear-support)
        [ "$#" -eq 2 ] || { echo "usage: ready_prompt.sh --clear-support COMMAND" >&2; exit 2; }
        clear_supported_agent "$2"
        exit $?
        ;;
esac

clear_first=0
if [ "${1:-}" = "--clear" ]; then
    clear_first=1
    shift
fi

pane=${1:-}
if [ -z "$pane" ]; then
    echo "usage: ready_prompt.sh [--clear] PANE_ID" >&2
    exit 2
fi

case "$CAPTURE_LINES" in
    ""|*[!0-9]*|0)
        show_message "prefix+b: invalid capture bound"
        exit 2
        ;;
esac

pane_command=$("$TMUX_BIN" display-message -p -t "$pane" '#{pane_current_command}' 2>/dev/null) || {
    show_message "prefix+b: unable to inspect current pane"
    exit 1
}
if ! recognized_agent "$pane_command"; then
    show_message "prefix+b: current pane is not a supported agent"
    exit 1
fi
if [ "$clear_first" -eq 1 ] && ! clear_supported_agent "$pane_command"; then
    show_message "prefix+B: this agent cannot safely context-clear with /clear"
    exit 1
fi
pane_in_mode=$("$TMUX_BIN" display-message -p -t "$pane" '#{pane_in_mode}' 2>/dev/null) || {
    show_message "prefix+b: unable to inspect current pane mode"
    exit 1
}
if [ "$pane_in_mode" = "1" ]; then
    if ! "$TMUX_BIN" send-keys -X -t "$pane" cancel; then
        show_message "prefix+b: unable to exit copy mode"
        exit 1
    fi
fi

runtime_base=${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}
work_dir=$(mktemp -d "$runtime_base/tmux-ready-prompt.XXXXXX") || {
    show_message "prefix+b: unable to create temporary workspace"
    exit 1
}
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM
history_file=$work_dir/history.txt
prompt_file=$work_dir/prompt.txt

if ! "$TMUX_BIN" capture-pane -p -J -S "-$CAPTURE_LINES" -t "$pane" >"$history_file"; then
    show_message "prefix+b: unable to capture recent pane history"
    exit 1
fi

extract_prompt "$history_file" >"$prompt_file"
extract_status=$?
case "$extract_status" in
    0) ;;
    10)
        show_message "prefix+b: no replayable handoff found"
        exit 1
        ;;
    11)
        show_message "prefix+b: handoff is incomplete; copy the whole Ready-to-paste prompt block"
        exit 1
        ;;
    *)
        show_message "prefix+b: prompt extraction failed"
        exit 1
        ;;
esac

fingerprint=$(cksum <"$prompt_file" | awk '{ print $1 ":" $2 }')
consumed=$("$TMUX_BIN" show-options -p -q -v -t "$pane" @ready_prompt_fingerprint 2>/dev/null || true)
if [ "$clear_first" -eq 0 ] && [ "$consumed" = "$fingerprint" ]; then
    show_message "prefix+b: newest prompt was already inserted; use prefix+B to clear and replay"
    exit 1
fi

buffer_name=ready-prompt-${pane#%}
if ! "$TMUX_BIN" load-buffer -b "$buffer_name" "$prompt_file"; then
    show_message "prefix+b: unable to load extracted prompt"
    exit 1
fi
if [ "$clear_first" -eq 1 ]; then
    if ! submit_codex_clear; then
        "$TMUX_BIN" delete-buffer -b "$buffer_name" 2>/dev/null || true
        show_message "prefix+B: unable to submit /clear"
        exit 1
    fi
    if ! wait_for_codex_ready; then
        "$TMUX_BIN" delete-buffer -b "$buffer_name" 2>/dev/null || true
        show_message "prefix+B: /clear submitted, but Codex did not become ready; prompt was not inserted"
        exit 1
    fi
fi
if ! "$TMUX_BIN" paste-buffer -b "$buffer_name" -t "$pane" -d; then
    "$TMUX_BIN" delete-buffer -b "$buffer_name" 2>/dev/null || true
    show_message "prefix+b: unable to insert extracted prompt"
    exit 1
fi
if ! "$TMUX_BIN" set-option -p -t "$pane" @ready_prompt_fingerprint "$fingerprint"; then
    show_message "prefix+b: prompt inserted, but consume-once state was not saved"
    exit 1
fi

if [ "$clear_first" -eq 1 ]; then
    show_message "prefix+B: /clear submitted and prompt inserted; review and press Enter"
else
    show_message "prefix+b: prompt inserted; review and press Enter"
fi
