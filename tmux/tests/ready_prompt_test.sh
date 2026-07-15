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

canonical=$TMP_ROOT/canonical.txt
printf '%s\n' \
    '**Ready-to-paste prompt:**' \
    '```text' \
    'Canonical first line.' \
    'Canonical second line.' \
    '```' >"$canonical"
assert_extract 'readable labeled fence is the canonical handoff' \
    $'Canonical first line.\nCanonical second line.' "$canonical"

legacy_marker=$TMP_ROOT/legacy-marker.txt
printf '%s\n' \
    'READY_TO_PASTE_BEGIN_V1' \
    'Legacy marker prompt.' \
    'READY_TO_PASTE_END_V1' >"$legacy_marker"
assert_extract 'v1 markers remain compatible with older handoffs' \
    'Legacy marker prompt.' "$legacy_marker"

malformed_marker=$TMP_ROOT/malformed-marker.txt
printf '%s\n' \
    'Ready-to-paste prompt: `older valid prompt`' \
    'READY_TO_PASTE_BEGIN_V1' \
    'newer prompt without an end marker' >"$malformed_marker"
assert_status 'unterminated newest v1 marker fails closed' 11 "$malformed_marker"

inline=$TMP_ROOT/inline.txt
printf '%s\n' 'Ready-to-paste prompt: `Continue from the verified state.`' >"$inline"
assert_extract 'single-line backtick prompt' 'Continue from the verified state.' "$inline"

skill_finish=$TMP_ROOT/skill-finish.txt
printf '%s\n' \
    'Status: AWAITING USER APPROVAL' \
    '' \
    'Next move: confirm the live interaction.' \
    '' \
    'Confirm prefix+b inserts this instruction without submitting it.' \
    'Keep the current implementation if it works.' >"$skill_finish"
assert_extract 'unlabeled skill-finish handoff after Next move' \
    $'Confirm prefix+b inserts this instruction without submitting it.\nKeep the current implementation if it works.' \
    "$skill_finish"

inline_next_move=$TMP_ROOT/inline-next-move.txt
printf '%s\n' \
    'Status: AWAITING USER APPROVAL' \
    '' \
    'Next move: Confirm whether you want issue #2 closed strictly as workflow-test housekeeping.' \
    '' \
    '─ Worked for 1m 02s ─────────────────────────' \
    '' \
    '› _ Worked for 1m 02s' \
    '' \
    'gpt-5.6-sol medium · ~/project' >"$inline_next_move"
assert_extract 'inline Next move wins over Codex worked-for chrome' \
    'Confirm whether you want issue #2 closed strictly as workflow-test housekeeping.' \
    "$inline_next_move"

rendered=$TMP_ROOT/rendered.txt
printf '%s\n' \
    'Ready-to-paste prompt:' \
    '' \
    'Validate the repaired shortcut in the normal terminal.' \
    'Confirm it leaves this prompt unsubmitted.' >"$rendered"
assert_extract 'rendered labeled paragraph after Markdown fences are stripped' \
    $'Validate the repaired shortcut in the normal terminal.\nConfirm it leaves this prompt unsubmitted.' \
    "$rendered"

multi_paragraph=$TMP_ROOT/multi-paragraph.txt
printf '%s\n' \
    'Ready-to-paste prompt:' \
    '' \
    'Perform the to-tickets phase using the approved specification.' \
    'Continue the first paragraph on its wrapped line.' \
    '' \
    'Create an ordered, dependency-aware set of implementation tickets.' \
    '' \
    'Map every acceptance criterion to exactly one owning ticket.' \
    'Stop when traceability is complete.' \
    '' \
    '─ Worked for 7m 13s ─────────────────────────' \
    '' \
    '› Summarize recent commits' >"$multi_paragraph"
assert_extract 'rendered labeled multi-paragraph prompt preserves every paragraph' \
    $'Perform the to-tickets phase using the approved specification.\nContinue the first paragraph on its wrapped line.\n\nCreate an ordered, dependency-aware set of implementation tickets.\n\nMap every acceptance criterion to exactly one owning ticket.\nStop when traceability is complete.' \
    "$multi_paragraph"

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
printf '%s\n' '**Ready-to-paste prompt**:' '`unterminated' >"$malformed"
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

binding_socket=ready-prompt-binding-$$
if tmux -L "$binding_socket" -f "$ROOT/tmux/tmux.conf" new-session -d -s binding-test; then
    binding=$(tmux -L "$binding_socket" list-keys -T prefix | awk '$4 == "b"')
    tmux -L "$binding_socket" kill-server
    if printf '%s\n' "$binding" | grep -Fq 'run-shell -b -t "#{pane_id}"'; then
        pass 'prefix+b preserves the invoking pane as the background job target'
    else
        fail 'prefix+b loses its pane context when run-shell goes into the background'
    fi
    if printf '%s\n' "$binding" | grep -Fq '|| true'; then
        pass 'prefix+b keeps handled helper failures out of the pane'
    else
        fail 'prefix+b leaks handled helper failures as raw tmux errors'
    fi
else
    fail 'prefix+b binding could not be loaded in an isolated tmux server'
fi

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

if MOCK_READY_SCREEN=$'Ready-to-paste prompt:\n› Ready' run_mock --clear '%9'; then
    clear_line=$(grep -n '^send-keys -t %9 -l /clear$' "$mock_state/calls" | cut -d: -f1)
    enter_line=$(grep -n '^send-keys -t %9 Enter$' "$mock_state/calls" | cut -d: -f1)
    last_paste_line=$(grep -n '^paste-buffer ' "$mock_state/calls" | tail -n1 | cut -d: -f1)
    enter_count=$(grep -c '^send-keys -t %9 Enter$' "$mock_state/calls")
    if [ "$enter_count" -eq 1 ] && [ "$clear_line" -lt "$enter_line" ] && \
            [ "$enter_line" -lt "$last_paste_line" ]; then
        pass 'uppercase waits for an idle prompt even when the old handoff remains visible'
    else
        fail 'uppercase did not preserve the clear-then-safe-paste sequence'
    fi
else
    fail 'clear-and-replay failed'
fi

before_pastes=$(grep -c '^paste-buffer ' "$mock_state/calls")
if MOCK_READY_SCREEN='› /clear' READY_PROMPT_READY_ATTEMPTS=1 \
        READY_PROMPT_READY_INTERVAL=0 run_mock --clear '%9'; then
    fail 'uppercase pasted while /clear was still in the input'
else
    after_pastes=$(grep -c '^paste-buffer ' "$mock_state/calls")
    if [ "$before_pastes" -eq "$after_pastes" ]; then
        pass 'uppercase waits while /clear remains unsubmitted'
    else
        fail 'uppercase pasted before /clear submission completed'
    fi
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
            grep -q 'no replayable handoff found' \
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
            grep -q 'handoff is incomplete; copy the whole Ready-to-paste prompt block' \
                "$mock_state/messages"; then
        pass 'malformed newest prompt fails closed without older fallback'
    else
        fail 'malformed newest prompt did not fail closed with its specific message'
    fi
fi

rm -f "$mock_state/fingerprint"
before_pastes=$(grep -c '^paste-buffer ' "$mock_state/calls")
before_calls=$(wc -l <"$mock_state/calls")
if MOCK_PANE_IN_MODE=1 run_mock '%9'; then
    after_pastes=$(grep -c '^paste-buffer ' "$mock_state/calls")
    new_calls=$(tail -n "+$((before_calls + 1))" "$mock_state/calls")
    cancel_line=$(printf '%s\n' "$new_calls" | grep -n '^send-keys -X -t %9 cancel$' | cut -d: -f1)
    capture_line=$(printf '%s\n' "$new_calls" | grep -n '^capture-pane .* -S ' | cut -d: -f1)
    if [ "$after_pastes" -eq $((before_pastes + 1)) ] && \
            [ "$cancel_line" -lt "$capture_line" ]; then
        pass 'copy-mode is cancelled before capture and insertion'
    else
        fail 'copy-mode cancellation did not precede capture and insertion'
    fi
else
    fail 'copy-mode pane was not recovered'
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
