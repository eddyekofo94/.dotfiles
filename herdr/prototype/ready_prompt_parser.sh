#!/usr/bin/env bash

# Parse labeled agent handoffs out of captured terminal scrollback.
#
# This is the single parser behind both consumers: Herdr's `prefix+b` replay
# (herdr/prototype/ready_prompt.sh) and the ctrl+g prompt editor's $VISUAL
# shim (~/.config/nvim/tools/agent_prompt_editor.sh). It reads a file and
# writes to stdout — it owns no terminal, spawns no multiplexer, and knows
# nothing about panes. Keeping it transport-free is what stops the two
# callers from drifting apart.
#
# Parsing and agent support stay intentionally narrow so uncertain states
# fail closed.

set -u

CAPTURE_LINES=${READY_PROMPT_CAPTURE_LINES:-2000}

PARSER_AWK='
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

        # A closeout opens at its Status line. Accept the shapes the skill
        # contract actually produces, including a terminal bullet glyph.
        function status_heading(value) {
            value = trim(value)
            sub(/^(⏺|●|•)[[:space:]]+/, "", value)
            value = trim(value)
            sub(/^-[[:space:]]+/, "", value)
            sub(/^#+[[:space:]]+/, "", value)
            sub(/^\*\*[[:space:]]*/, "", value)
            return index(value, "Status:") == 1 || index(value, "Status**") == 1
        }

        function commit_closeout(end_nr) {
            if (mode != "closeout" || pending_start == 0 || end_nr < pending_start) {
                return
            }
            closeout_start = pending_start
            closeout_end = end_nr
            pending_start = 0
            status_start = 0
        }

        {
            line = $0
            if (mode == "closeout") {
                lines[NR] = line
            }

            if (trim(line) == "READY_TO_PASTE_BEGIN_V1") {
                saw_marker = 1
                marker_position = NR
                marker_status = 1
                marker_state = "collect"
                marker_value = ""
                if (pending_start == 0) {
                    pending_start = (status_start > 0 ? status_start : NR)
                }
                next
            }

            if (marker_state == "collect") {
                if (trim(line) == "READY_TO_PASTE_END_V1") {
                    if (nonblank(marker_value)) {
                        marker_status = 2
                        commit_closeout(NR)
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
                        commit_closeout(NR)
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

            # Only outside a prompt body: a "Status:" line inside a replayed
            # prompt belongs to that prompt, not to a new closeout.
            if (mode == "closeout" && state != "plain" && status_heading(line)) {
                status_start = NR
            }

            if (label_line(line)) {
                saw_label = 1
                label_position = NR
                candidate = ""
                candidate_status = 1
                fenced_value = ""
                state = "waiting"
                fallback_state = "done"
                pending_start = (status_start > 0 ? status_start : NR)

                if (label_rest != "") {
                    if (inline_prompt(label_rest)) {
                        candidate = inline_value
                        candidate_status = 2
                        state = "done"
                        commit_closeout(NR)
                    } else {
                        state = "malformed"
                    }
                }
                next
            }

            if (state == "plain") {
                if (terminal_chrome(line)) {
                    state = "done"
                    commit_closeout(plain_last)
                } else if (!nonblank(line)) {
                    plain_blank_count++
                } else {
                    while (plain_blank_count > 0) {
                        candidate = candidate "\n"
                        plain_blank_count--
                    }
                    candidate = candidate "\n" line
                    plain_last = NR
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
                    commit_closeout(NR)
                } else if (substr(trim(line), 1, 1) == "`") {
                    state = "malformed"
                } else {
                    candidate = line
                    candidate_status = 2
                    plain_blank_count = 0
                    plain_last = NR
                    state = "plain"
                }
            }
        }

        END {
            if (mode == "closeout") {
                if (state == "plain") {
                    commit_closeout(plain_last)
                }
                if (closeout_start > 0) {
                    for (index_nr = closeout_start; index_nr <= closeout_end; index_nr++) {
                        print lines[index_nr]
                    }
                    exit 0
                }
                if (saw_label || saw_marker) {
                    exit 11
                }
                exit 10
            }

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

run_parser() {
    tail -n "$CAPTURE_LINES" "$2" | awk -v mode="$1" "$PARSER_AWK"
}

extract_prompt() {
    run_parser prompt "$1"
}

extract_closeout() {
    run_parser closeout "$1"
}

normalize_agent() {
    command_path=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    case "$command_path" in
        */@earendil-works/pi-coding-agent/*/cli.js|*/pi-coding-agent/dist/cli.js)
            printf '%s\n' pi
            return 0
            ;;
    esac
    command_name=$(basename -- "$command_path")
    case "$command_name" in
        codex|claude|opencode|gemini|agy|pi)
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
    position=0
    for candidate in "${command_words[@]}"; do
        candidate=${candidate//\"/}
        candidate=${candidate//\'/}
        if normalized=$(normalize_agent "$candidate" 2>/dev/null); then
            if [ "$normalized" != pi ] || [ "$position" -eq 0 ]; then
                printf '%s\n' "$normalized"
                return 0
            fi
            case "$(printf '%s' "$candidate" | tr '[:upper:]' '[:lower:]')" in
                */@earendil-works/pi-coding-agent/*/cli.js|*/pi-coding-agent/dist/cli.js)
                    printf '%s\n' pi
                    return 0
                    ;;
            esac
        fi
        position=$((position + 1))
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


case ${1:-} in
    --extract)
        [ "$#" -eq 2 ] || { echo "usage: ready_prompt_parser.sh --extract FILE" >&2; exit 2; }
        case "$CAPTURE_LINES" in
            ""|*[!0-9]*) echo "READY_PROMPT_CAPTURE_LINES must be a positive integer" >&2; exit 2 ;;
            0) echo "READY_PROMPT_CAPTURE_LINES must be a positive integer" >&2; exit 2 ;;
        esac
        extract_prompt "$2"
        exit $?
        ;;
    --extract-closeout)
        [ "$#" -eq 2 ] || { echo "usage: ready_prompt_parser.sh --extract-closeout FILE" >&2; exit 2; }
        case "$CAPTURE_LINES" in
            ""|*[!0-9]*) echo "READY_PROMPT_CAPTURE_LINES must be a positive integer" >&2; exit 2 ;;
            0) echo "READY_PROMPT_CAPTURE_LINES must be a positive integer" >&2; exit 2 ;;
        esac
        extract_closeout "$2"
        exit $?
        ;;
    --recognize)
        [ "$#" -eq 2 ] || { echo "usage: ready_prompt_parser.sh --recognize COMMAND" >&2; exit 2; }
        recognized_agent "$2"
        exit $?
        ;;
    --normalize)
        [ "$#" -eq 2 ] || { echo "usage: ready_prompt_parser.sh --normalize COMMAND" >&2; exit 2; }
        normalize_agent "$2"
        exit $?
        ;;
    --clear-support)
        [ "$#" -eq 2 ] || { echo "usage: ready_prompt_parser.sh --clear-support COMMAND" >&2; exit 2; }
        clear_supported_agent "$2"
        exit $?
        ;;
    --ready-screen)
        [ "$#" -eq 3 ] || [ "$#" -eq 4 ] || {
            echo "usage: ready_prompt_parser.sh --ready-screen AGENT FILE [STYLED_FILE]" >&2
            exit 2
        }
        agent_screen_ready "$2" "$3" "${4:-$3}"
        exit $?
        ;;
    --clear-active)
        [ "$#" -eq 3 ] || { echo "usage: ready_prompt_parser.sh --clear-active AGENT FILE" >&2; exit 2; }
        agent_clear_active "$2" "$3"
        exit $?
        ;;
esac

echo "usage: ready_prompt_parser.sh --extract|--extract-closeout FILE" >&2
echo "       ready_prompt_parser.sh --recognize|--normalize|--clear-support COMMAND" >&2
echo "       ready_prompt_parser.sh --ready-screen AGENT FILE [STYLED_FILE]" >&2
echo "       ready_prompt_parser.sh --clear-active AGENT FILE" >&2
exit 2
