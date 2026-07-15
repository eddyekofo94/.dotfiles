#!/usr/bin/env bash

set -u

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SCRIPT=$ROOT/tmux/scripts/ready_prompt.sh
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/ready-prompt-tests.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

passed=0
failed=0

pass() {
    passed=$((passed + 1))
    printf 'ok %d - %s\n' "$passed" "$1"
}

fail() {
    failed=$((failed + 1))
    printf 'not ok - %s\n' "$1" >&2
}

assert_extract() {
    name=$1
    expected=$2
    fixture=$3
    output_file=$TMP_ROOT/output
    if READY_PROMPT_CAPTURE_LINES=2000 "$SCRIPT" --extract "$fixture" >"$output_file"; then
        actual=$(cat "$output_file")
        if [ "$actual" = "$expected" ]; then
            pass "$name"
        else
            fail "$name (expected [$expected], got [$actual])"
        fi
    else
        fail "$name (extractor returned $?)"
    fi
}

assert_status() {
    name=$1
    expected=$2
    fixture=$3
    READY_PROMPT_CAPTURE_LINES=2000 "$SCRIPT" --extract "$fixture" >"$TMP_ROOT/output" 2>"$TMP_ROOT/error"
    actual=$?
    if [ "$actual" -eq "$expected" ]; then
        pass "$name"
    else
        fail "$name (expected status $expected, got $actual)"
    fi
}

fenced=$TMP_ROOT/fenced.txt
printf '%s\n' \
    'ordinary output' \
    '**Ready-to-paste prompt**:' \
    '```text' \
    'First line' \
    'Second line' \
    '```' >"$fenced"
assert_extract 'fenced multiline prompt' $'First line\nSecond line' "$fenced"

inline=$TMP_ROOT/inline.txt
printf '%s\n' 'Ready-to-paste prompt: `Continue from the verified state.`' >"$inline"
assert_extract 'single-line backtick prompt' 'Continue from the verified state.' "$inline"

bold_colon=$TMP_ROOT/bold-colon.txt
printf '%s\n' \
    '**Ready-to-paste prompt:**' \
    '```text' \
    'Bold label with an internal colon.' \
    '```' >"$bold_colon"
assert_extract 'bold label accepts colon inside emphasis' \
    'Bold label with an internal colon.' "$bold_colon"

unlabeled=$TMP_ROOT/unlabeled.txt
printf '%s\n' '```text' 'do not extract me' '```' >"$unlabeled"
assert_status 'unlabeled fence is ignored' 10 "$unlabeled"

missing=$TMP_ROOT/missing.txt
printf '%s\n' 'no handoff is present' >"$missing"
assert_status 'missing prompt' 10 "$missing"

malformed=$TMP_ROOT/malformed.txt
printf '%s\n' '**Ready-to-paste prompt**:' 'not fenced or backticked' >"$malformed"
assert_status 'malformed prompt' 11 "$malformed"

newest_malformed=$TMP_ROOT/newest-malformed.txt
printf '%s\n' \
    '**Ready-to-paste prompt**:' \
    '```' \
    'older valid prompt' \
    '```' \
    '**Ready-to-paste prompt**:' \
    '`unterminated' >"$newest_malformed"
assert_status 'malformed newest prompt never falls back' 11 "$newest_malformed"

multiple=$TMP_ROOT/multiple.txt
printf '%s\n' \
    'Ready-to-paste prompt: `older prompt`' \
    'intervening text' \
    '### Ready-to-paste prompt' \
    '```sh' \
    'newer prompt' \
    '```' >"$multiple"
assert_extract 'newest labeled prompt wins' 'newer prompt' "$multiple"

label_inside=$TMP_ROOT/label-inside.txt
printf '%s\n' \
    '**Ready-to-paste prompt**:' \
    '```' \
    'Preserve the phrase Ready-to-paste prompt: inside this prompt.' \
    '```' >"$label_inside"
assert_extract 'label text inside fence remains prompt content' \
    'Preserve the phrase Ready-to-paste prompt: inside this prompt.' "$label_inside"

bounded=$TMP_ROOT/bounded.txt
printf '%s\n' 'Ready-to-paste prompt: `outside the capture bound`' >"$bounded"
i=0
while [ "$i" -lt 2000 ]; do
    printf 'filler %d\n' "$i" >>"$bounded"
    i=$((i + 1))
done
assert_status 'capture is bounded to 2000 lines' 10 "$bounded"

for agent in Codex claude /opt/homebrew/bin/opencode GEMINI agy; do
    if "$SCRIPT" --recognize "$agent"; then
        pass "recognition: $agent is supported"
    else
        fail "recognition: $agent should be supported"
    fi
done
for command_name in zsh node vim codex-helper; do
    if "$SCRIPT" --recognize "$command_name"; then
        fail "recognition: $command_name should be rejected"
    else
        pass "recognition: $command_name is rejected"
    fi
done

if "$SCRIPT" --clear-support codex; then
    pass 'clear support: codex starts a fresh context with /clear'
else
    fail 'clear support: codex should support /clear'
fi
for agent in claude opencode gemini agy; do
    if "$SCRIPT" --clear-support "$agent"; then
        fail "clear support: $agent must fail closed"
    else
        pass "clear support: $agent fails closed"
    fi
done

mock_state=$TMP_ROOT/mock-state
mkdir -p "$mock_state"
mock_tmux=$TMP_ROOT/tmux
cat >"$mock_tmux" <<'MOCK'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >>"$MOCK_TMUX_STATE/calls"
case "$1" in
    display-message)
        if [ "${2:-}" = "-p" ]; then
            if [ "${*: -1}" = '#{pane_in_mode}' ]; then
                printf '%s\n' "${MOCK_PANE_IN_MODE:-0}"
            else
                printf '%s\n' "${MOCK_PANE_COMMAND:-codex}"
            fi
        else
            printf '%s\n' "${*: -1}" >>"$MOCK_TMUX_STATE/messages"
        fi
        ;;
    capture-pane)
        case " $* " in
            *' -S '*) cat "$MOCK_HISTORY" ;;
            *) printf '%s\n' "${MOCK_READY_SCREEN:-› Ready}" ;;
        esac
        ;;
    show-options)
        [ -f "$MOCK_TMUX_STATE/fingerprint" ] && cat "$MOCK_TMUX_STATE/fingerprint"
        ;;
    load-buffer)
        cp "${*: -1}" "$MOCK_TMUX_STATE/buffer"
        ;;
    paste-buffer)
        :
        ;;
    send-keys)
        :
        ;;
    set-option)
        printf '%s\n' "${*: -1}" >"$MOCK_TMUX_STATE/fingerprint"
        ;;
    delete-buffer)
        :
        ;;
esac
MOCK
chmod +x "$mock_tmux"

run_mock() {
    mock_history=${MOCK_HISTORY:-$fenced}
    MOCK_TMUX_STATE=$mock_state MOCK_HISTORY=$mock_history TMUX_BIN=$mock_tmux "$SCRIPT" "$@"
}

if run_mock '%9'; then
    if cmp -s "$mock_state/buffer" <(printf '%s' $'First line\nSecond line') && \
            grep -q '^paste-buffer .* -t %9 -d$' "$mock_state/calls" && \
            ! grep -Eq 'send-keys|send ' "$mock_state/calls"; then
        pass 'multiline insertion uses paste-buffer without submitting'
    else
        fail 'multiline insertion did not preserve safe paste behavior'
    fi
else
    fail 'initial insertion failed'
fi

if run_mock '%9'; then
    fail 'consume-once allowed a duplicate insertion'
elif grep -q 'already inserted; use prefix+B' "$mock_state/messages"; then
    pass 'consume-once blocks duplicate insertion'
else
    fail 'consume-once did not report its specific failure'
fi

if MOCK_READY_SCREEN='› Ready' run_mock --clear '%9'; then
    clear_line=$(grep -n '^send-keys -t %9 -l /clear$' "$mock_state/calls" | cut -d: -f1)
    enter_line=$(grep -n '^send-keys -t %9 Enter$' "$mock_state/calls" | cut -d: -f1)
    last_paste_line=$(grep -n '^paste-buffer ' "$mock_state/calls" | tail -n1 | cut -d: -f1)
    enter_count=$(grep -c '^send-keys -t %9 Enter$' "$mock_state/calls")
    if [ "$enter_count" -eq 1 ] && [ "$clear_line" -lt "$enter_line" ] && \
            [ "$enter_line" -lt "$last_paste_line" ]; then
        pass 'uppercase submits /clear before pasting without submitting the prompt'
    else
        fail 'uppercase did not preserve the clear-then-safe-paste sequence'
    fi
else
    fail 'clear-and-replay failed'
fi

before_pastes=$(grep -c '^paste-buffer ' "$mock_state/calls")
if MOCK_READY_SCREEN='model: loading' READY_PROMPT_READY_ATTEMPTS=1 \
        READY_PROMPT_READY_INTERVAL=0 run_mock --clear '%9'; then
    fail 'uppercase pasted before Codex became ready'
else
    after_pastes=$(grep -c '^paste-buffer ' "$mock_state/calls")
    if [ "$before_pastes" -eq "$after_pastes" ] && \
            grep -q 'Codex did not become ready; prompt was not inserted' \
                "$mock_state/messages"; then
        pass 'uppercase fails closed when Codex readiness never appears'
    else
        fail 'uppercase readiness timeout did not fail closed'
    fi
fi

before_calls=$(wc -l <"$mock_state/calls")
if MOCK_PANE_COMMAND=gemini run_mock --clear '%9'; then
    fail 'Gemini clear-and-replay was accepted despite display-only /clear semantics'
else
    after_calls=$(wc -l <"$mock_state/calls")
    if [ "$after_calls" -eq $((before_calls + 2)) ] && \
            grep -q 'cannot safely context-clear with /clear' "$mock_state/messages"; then
        pass 'unsupported clear semantics fail closed before capture or insertion'
    else
        fail 'unsupported clear semantics performed work beyond its failure message'
    fi
fi

before_pastes=$(grep -c '^paste-buffer ' "$mock_state/calls")
if MOCK_HISTORY=$missing run_mock '%9'; then
    fail 'missing prompt reached insertion'
else
    after_pastes=$(grep -c '^paste-buffer ' "$mock_state/calls")
    if [ "$before_pastes" -eq "$after_pastes" ] && \
            grep -q 'no Ready-to-paste prompt label found; Enter only dismisses this message' \
                "$mock_state/messages"; then
        pass 'missing label fails closed with actionable dismissal guidance'
    else
        fail 'missing label did not fail closed with actionable dismissal guidance'
    fi
fi

before_pastes=$(grep -c '^paste-buffer ' "$mock_state/calls")
if MOCK_HISTORY=$newest_malformed run_mock '%9'; then
    fail 'malformed newest prompt reached insertion'
else
    after_pastes=$(grep -c '^paste-buffer ' "$mock_state/calls")
    if [ "$before_pastes" -eq "$after_pastes" ] && \
            grep -q 'newest ready-to-paste prompt is malformed' "$mock_state/messages"; then
        pass 'malformed newest prompt fails closed without older fallback'
    else
        fail 'malformed newest prompt did not fail closed with its specific message'
    fi
fi

rm -f "$mock_state/fingerprint"
before_pastes=$(grep -c '^paste-buffer ' "$mock_state/calls")
if MOCK_PANE_IN_MODE=1 run_mock '%9'; then
    fail 'copy-mode pane was accepted'
else
    after_pastes=$(grep -c '^paste-buffer ' "$mock_state/calls")
    if [ "$before_pastes" -eq "$after_pastes" ] && \
            grep -q 'exit copy mode before replaying a prompt' "$mock_state/messages"; then
        pass 'copy-mode pane fails closed before capture or insertion'
    else
        fail 'copy-mode pane did not fail closed with recovery guidance'
    fi
fi

before_calls=$(wc -l <"$mock_state/calls")
if MOCK_PANE_COMMAND=zsh run_mock '%9'; then
    fail 'non-agent pane was accepted'
else
    after_calls=$(wc -l <"$mock_state/calls")
    if [ "$after_calls" -eq $((before_calls + 2)) ] && \
            grep -q 'current pane is not a supported agent' "$mock_state/messages"; then
        pass 'non-agent pane fails closed before capture or insertion'
    else
        fail 'non-agent pane performed work beyond its failure message'
    fi
fi

printf '1..%d\n' "$((passed + failed))"
if [ "$failed" -ne 0 ]; then
    printf '%d test(s) failed\n' "$failed" >&2
    exit 1
fi
