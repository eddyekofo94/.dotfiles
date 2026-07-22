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

        function horizontal_divider(value, remainder) {
            value = trim(value)
            remainder = value
            gsub(/─/, "", remainder)
            gsub(/━/, "", remainder)
            return remainder == "" && length(value) >= 8
        }

        function terminal_chrome(value) {
            value = trim(value)
            return horizontal_divider(value) || \
                value ~ /^─.*Worked for/ || \
                value ~ /^━.*Worked for/ || \
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
                fallback_state = "done"

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
                if (terminal_chrome(line)) {
                    state = "malformed"
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

normalize_agent() {
    command_name=$(basename -- "$1" | tr '[:upper:]' '[:lower:]')
    case "$command_name" in
        codex|claude|opencode|gemini|agy)
            printf '%s\n' "$command_name"
            ;;
        *)
            return 1
            ;;
    esac
}

recognized_agent() {
    normalize_agent "$1" >/dev/null
}

agent_from_command_line() {
    command_line=$1
    if normalize_agent "$command_line"; then
        return 0
    fi
    read -r -a command_words <<<"$command_line"
    for candidate in "${command_words[@]}"; do
        candidate=${candidate//\"/}
        candidate=${candidate//\'/}
        if normalize_agent "$candidate"; then
            return 0
        fi
    done
    return 1
}

clear_supported_agent() {
    command_name=$(basename -- "$1" | tr '[:upper:]' '[:lower:]')
    case "$command_name" in
        codex|claude)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

agent_prompt_glyph() {
    command_name=$(basename -- "$1" | tr '[:upper:]' '[:lower:]')
    case "$command_name" in
        codex) printf '›' ;;
        claude) printf '❯' ;;
        *) return 1 ;;
    esac
}

latest_agent_prompt() {
    prompt_glyph=$1
    screen_file=$2
    awk -v glyph="$prompt_glyph" '
        $0 ~ "^[[:space:]]*" glyph { line = $0 }
        END { if (line != "") print line }
    ' "$screen_file"
}

codex_styled_prompt_is_empty() {
    screen_file=$1
    perl - "$screen_file" <<'PERL'
use strict;
use warnings;

my ($screen_file) = @ARGV;
open my $screen, '<', $screen_file or exit 1;
my @lines = <$screen>;
my $latest_index;
for my $index (0 .. $#lines) {
    my $line = $lines[$index];
    my $plain = $line;
    $plain =~ s/\e\[[0-9;]*m//g;
    $latest_index = $index if $plain =~ /^\s*›/;
}
exit 1 unless defined $latest_index;

my $latest = $lines[$latest_index];
for my $index (($latest_index + 1) .. $#lines) {
    my $plain = $lines[$index];
    $plain =~ s/\e\[[0-9;]*m//g;
    last if $plain =~ /^\s*$/;
    $latest .= $lines[$index];
}

my $glyph = index($latest, '›');
exit 1 if $glyph < 0;
my $rest = substr($latest, $glyph + length('›'));
my $dim = 0;
while (length $rest) {
    if ($rest =~ s/^\e\[([0-9;]*)m//) {
        my @params = length($1) ? split(/;/, $1) : (0);
        for my $param (@params) {
            $dim = 0 if $param == 0 || $param == 22;
            $dim = 1 if $param == 2;
        }
        next;
    }
    $rest =~ s/^(.)//s;
    my $character = $1;
    next if $character =~ /\s/;
    exit 1 unless $dim;
}
exit 0;
PERL
}

agent_screen_ready() {
    command_name=$1
    screen_file=$2
    styled_screen_file=${3:-$screen_file}
    prompt_glyph=$(agent_prompt_glyph "$command_name") || return 1
    latest_prompt=$(latest_agent_prompt "$prompt_glyph" "$screen_file")
    if grep -Fq 'Queued follow-up inputs' "$screen_file" || \
            grep -Eq 'model:[[:space:]]+loading' "$screen_file" || \
            grep -Eq 'Working \([^)]*esc to interrupt\)' "$screen_file"; then
        return 1
    fi
    if [ "$command_name" = codex ]; then
        codex_styled_prompt_is_empty "$styled_screen_file"
        return $?
    fi
    printf '%s\n' "$latest_prompt" | \
        grep -Eq "^[[:space:]]*$prompt_glyph[[:space:]]*$"
}

agent_clear_active() {
    command_name=$1
    screen_file=$2
    prompt_glyph=$(agent_prompt_glyph "$command_name") || return 1
    latest_prompt=$(latest_agent_prompt "$prompt_glyph" "$screen_file")
    printf '%s\n' "$latest_prompt" | \
        grep -Eq "^[[:space:]]*$prompt_glyph[[:space:]]*/clear([[:space:]]|$)"
}

wait_for_agent_ready() {
    ready_screen=$work_dir/ready-screen.txt
    styled_ready_screen=$work_dir/ready-screen-styled.txt
    attempt=0
    stable=0

    while [ "$attempt" -lt "$READY_ATTEMPTS" ]; do
        if ! "$TMUX_BIN" capture-pane -p -J -e -t "$pane" >"$styled_ready_screen"; then
            return 1
        fi
        if ! perl -pe 's/\e\[[0-9;]*m//g' \
                "$styled_ready_screen" >"$ready_screen"; then
            return 1
        fi

        if agent_screen_ready "$pane_command" "$ready_screen" "$styled_ready_screen"; then
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

submit_agent_clear() {
    clear_screen=$work_dir/clear-submit-screen.txt

    "$TMUX_BIN" send-keys -t "$pane" -l '/clear' || return 1
    "$TMUX_BIN" send-keys -t "$pane" Enter || return 1
    sleep "$CLEAR_CONFIRM_INTERVAL" || return 1
    "$TMUX_BIN" capture-pane -p -J -t "$pane" >"$clear_screen" || return 1

    # An agent may use the first Enter to resolve its slash-command menu,
    # leaving /clear active in the composer. Confirm it only when the command
    # is still visible; never send a blind second Enter.
    if agent_clear_active "$pane_command" "$clear_screen"; then
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
    --ready-screen)
        [ "$#" -eq 3 ] || [ "$#" -eq 4 ] || {
            echo "usage: ready_prompt.sh --ready-screen AGENT FILE [STYLED_FILE]" >&2
            exit 2
        }
        agent_screen_ready "$2" "$3" "${4:-$3}"
        exit $?
        ;;
    --clear-active)
        [ "$#" -eq 3 ] || { echo "usage: ready_prompt.sh --clear-active AGENT FILE" >&2; exit 2; }
        agent_clear_active "$2" "$3"
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

pane_agent=$("$TMUX_BIN" show-options -p -q -v -t "$pane" @agent_status_agent 2>/dev/null || true)
pane_current_command=$("$TMUX_BIN" display-message -p -t "$pane" '#{pane_current_command}' 2>/dev/null) || {
    show_message "prefix+b: unable to inspect current pane"
    exit 1
}
pane_start_command=$("$TMUX_BIN" display-message -p -t "$pane" '#{pane_start_command}' 2>/dev/null || true)
if pane_command=$(normalize_agent "$pane_agent" 2>/dev/null); then
    :
elif pane_command=$(agent_from_command_line "$pane_current_command" 2>/dev/null); then
    :
elif pane_command=$(agent_from_command_line "$pane_start_command" 2>/dev/null); then
    :
else
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
mkdir -p "$runtime_base" || {
    show_message "prefix+b: unable to prepare runtime directory"
    exit 1
}
socket_path=$("$TMUX_BIN" display-message -p -t "$pane" '#{socket_path}' 2>/dev/null || true)
socket_key=$(printf '%s' "$socket_path" | cksum | awk '{print $1}')
lock_dir="$runtime_base/tmux-ready-prompt-lock.$socket_key.${pane#%}"
work_dir=''
lock_acquired=0
cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
    [ -z "$work_dir" ] || rm -rf -- "$work_dir"
    if [ "$lock_acquired" -eq 1 ] && [ -d "$lock_dir" ]; then
        rmdir "$lock_dir" 2>/dev/null || true
    fi
    exit "$status"
}
trap cleanup EXIT HUP INT TERM
if ! mkdir "$lock_dir" 2>/dev/null; then
    show_message "prefix+b: another replay is already active for this pane"
    exit 75
fi
lock_acquired=1
work_dir=$(mktemp -d "$runtime_base/tmux-ready-prompt.XXXXXX") || {
    show_message "prefix+b: unable to create temporary workspace"
    exit 1
}
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
    if ! submit_agent_clear; then
        "$TMUX_BIN" delete-buffer -b "$buffer_name" 2>/dev/null || true
        show_message "prefix+B: unable to submit /clear"
        exit 1
    fi
    if ! wait_for_agent_ready; then
        "$TMUX_BIN" delete-buffer -b "$buffer_name" 2>/dev/null || true
        show_message "prefix+B: /clear submitted, but $pane_command did not become ready; prompt was not inserted"
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
