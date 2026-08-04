#!/usr/bin/env bash

set -u

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
SCRIPT=${READY_PROMPT_PARSER:-$ROOT/herdr/prototype/ready_prompt_parser.sh}
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

bare_divider=$TMP_ROOT/bare-divider.txt
printf '%s\n' \
    'Ready-to-paste prompt:' \
    '' \
    'Push local main to origin/main and verify the commit remotely.' \
    '' \
    '────────────────────────────────────────────────────────────────────────' \
    '' \
    '› Type a new request' >"$bare_divider"
assert_extract 'bare Codex response divider ends a rendered prompt' \
    'Push local main to origin/main and verify the commit remotely.' \
    "$bare_divider"

normal_closeout=$TMP_ROOT/normal-closeout.txt
printf '%s\n' \
    'Next move: Push main when ready.' \
    '' \
    'Ready-to-paste prompt:' \
    '' \
    'Push local main to origin/main and verify the commit remotely.' \
    'Preserve this line even though it mentions the Worked for divider.' \
    '' \
    '────────────────────────────────────────────────────────────────────────' \
    '' \
    '› Type a new request' >"$normal_closeout"
assert_extract 'explicit label overrides Next move fallback through bare divider' \
    $'Push local main to origin/main and verify the commit remotely.\nPreserve this line even though it mentions the Worked for divider.' \
    "$normal_closeout"

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

for agent in Codex claude /opt/homebrew/bin/opencode GEMINI agy \
        /opt/pi/bin/pi \
        /opt/node_modules/@earendil-works/pi-coding-agent/dist/cli.js; do
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

for agent in codex claude; do
    if "$SCRIPT" --clear-support "$agent"; then
        pass "clear support: $agent starts a fresh context with /clear"
    else
        fail "clear support: $agent should support /clear"
    fi
done
for agent in opencode gemini agy pi; do
    if "$SCRIPT" --clear-support "$agent"; then
        fail "clear support: $agent must fail closed"
    else
        pass "clear support: $agent fails closed"
    fi
done

bare_codex=$TMP_ROOT/bare-codex.txt
printf '%s\n' '›' >"$bare_codex"
if "$SCRIPT" --ready-screen codex "$bare_codex"; then
    pass 'bare Codex composer is ready'
else
    fail 'bare Codex composer should be ready'
fi

placeholder_plain=$TMP_ROOT/codex-placeholder-plain.txt
placeholder_styled=$TMP_ROOT/codex-placeholder-styled.txt
printf '%s\n' '› Summarize recent commits' >"$placeholder_plain"
printf '\033[1m›\033[0m \033[2mSummarize recent commits\033[0m\n' \
    >"$placeholder_styled"
if "$SCRIPT" --ready-screen codex "$placeholder_plain" "$placeholder_styled"; then
    pass 'dim Codex placeholder is semantically empty'
else
    fail 'dim Codex placeholder should be semantically empty'
fi

typed_codex=$TMP_ROOT/codex-typed.txt
printf '\033[1m›\033[0m typed composer text\n' >"$typed_codex"
if "$SCRIPT" --ready-screen codex "$placeholder_plain" "$typed_codex"; then
    fail 'typed Codex composer was accepted as empty'
else
    pass 'typed Codex composer is not empty'
fi

multiline_codex=$TMP_ROOT/codex-multiline-typed.txt
printf '%s\n' '›' '  typed second line' '' '  gpt-5.6-sol medium' \
    >"$multiline_codex"
if "$SCRIPT" --ready-screen codex "$multiline_codex" "$multiline_codex"; then
    fail 'multiline typed Codex composer was accepted as empty'
else
    pass 'multiline typed Codex composer is not empty'
fi

if "$SCRIPT" --ready-screen codex "$bare_codex" "$typed_codex"; then
    fail 'older bare Codex snapshot overrode newer typed composer text'
else
    pass 'styled Codex snapshot is authoritative over stale plain state'
fi

mixed_codex=$TMP_ROOT/codex-mixed-styles.txt
printf '\033[1m›\033[0m \033[2mSummarize\033[22m typed\n' >"$mixed_codex"
if "$SCRIPT" --ready-screen codex "$placeholder_plain" "$mixed_codex"; then
    fail 'partially dim Codex composer was accepted as empty'
else
    pass 'non-dim Codex composer content fails closed'
fi

typed_claude=$TMP_ROOT/claude-typed.txt
printf '%s\n' '❯ typed composer text' >"$typed_claude"
if "$SCRIPT" --ready-screen claude "$typed_claude" "$placeholder_styled"; then
    fail 'typed Claude composer was accepted through Codex placeholder styling'
else
    pass 'typed Claude composer remains non-empty'
fi

queued_codex=$TMP_ROOT/codex-queued.txt
printf '%s\n' 'Queued follow-up inputs' '› Summarize recent commits' >"$queued_codex"
if "$SCRIPT" --ready-screen codex "$queued_codex" "$placeholder_styled"; then
    fail 'dim Codex placeholder bypassed queued-input guard'
else
    pass 'queued Codex input remains non-ready'
fi

loading_codex=$TMP_ROOT/codex-loading.txt
printf '%s\n' 'model: loading' '› Summarize recent commits' >"$loading_codex"
if "$SCRIPT" --ready-screen codex "$loading_codex" "$placeholder_styled"; then
    fail 'dim Codex placeholder bypassed model-loading guard'
else
    pass 'loading Codex state remains non-ready'
fi

working_codex=$TMP_ROOT/codex-working.txt
printf '%s\n' '• Working (3s • esc to interrupt)' '› Summarize recent commits' \
    >"$working_codex"
if "$SCRIPT" --ready-screen codex "$working_codex" "$placeholder_styled"; then
    fail 'dim Codex placeholder bypassed working-state guard'
else
    pass 'working Codex state remains non-ready'
fi


# --extract-closeout shares the state machine with --extract, so the two must
# agree on which closeout is newest and where its prompt block ends.
closeout_fixture=$HOME/.config/nvim/tests/fixtures/closeout_capture.txt
empty_fixture=$HOME/.config/nvim/tests/fixtures/no_closeout_capture.txt

if [ -r "$closeout_fixture" ]; then
    if READY_PROMPT_CAPTURE_LINES=2000 "$SCRIPT" --extract-closeout \
            "$closeout_fixture" >"$TMP_ROOT/closeout"; then
        if head -n 1 "$TMP_ROOT/closeout" | grep -q 'Status.*DONE — newer run' && \
                grep -q 'Ready-to-paste prompt' "$TMP_ROOT/closeout" && \
                grep -q 'NEWER PROMPT BODY LINE TWO' "$TMP_ROOT/closeout" && \
                ! grep -q 'OLDER' "$TMP_ROOT/closeout"; then
            pass 'closeout mode returns the newest whole closeout with its prompt block'
        else
            fail "closeout mode returned the wrong block: $(cat "$TMP_ROOT/closeout")"
        fi
    else
        fail "closeout mode returned $? on a valid capture"
    fi

    READY_PROMPT_CAPTURE_LINES=2000 "$SCRIPT" --extract "$closeout_fixture" \
        >"$TMP_ROOT/closeout-prompt" 2>/dev/null
    if grep -q 'NEWER PROMPT BODY LINE ONE' "$TMP_ROOT/closeout-prompt" && \
            ! grep -q 'Status' "$TMP_ROOT/closeout-prompt"; then
        pass 'prompt mode is unchanged by closeout bookkeeping'
    else
        fail "prompt mode drifted: $(cat "$TMP_ROOT/closeout-prompt")"
    fi

    set +e
    READY_PROMPT_CAPTURE_LINES=2000 "$SCRIPT" --extract-closeout \
        "$empty_fixture" >"$TMP_ROOT/closeout-empty" 2>/dev/null
    closeout_empty_status=$?
    set -e
    if [ "$closeout_empty_status" -ne 0 ] && \
            [ ! -s "$TMP_ROOT/closeout-empty" ]; then
        pass 'closeout mode exits non-zero when no closeout is present'
    else
        fail "closeout mode accepted a capture without a closeout (status $closeout_empty_status)"
    fi
else
    printf '# skipping closeout fixtures: %s is unreadable\n' "$closeout_fixture"
fi

# Claude's TUI strips the Markdown fence, so a rendered prompt runs straight
# into the duration line and the optional recap block below it.
claude_recap=$TMP_ROOT/claude-recap.txt
printf '%s\n' \
    '⏺ **Status:** DONE' \
    '  **Next move:** review the diff' \
    '' \
    '  **Ready-to-paste prompt:**' \
    '' \
    '  Review the uncommitted diff and report Standards and Fidelity findings.' \
    '  Stop when both axes are clean and the gate is still green.' \
    '' \
    '  ✻ Crunched for 11m 20s' \
    '' \
    '  ※ recap: Goal was fixing the red test; next is the review.' \
    '    (disable recaps in /config)' \
    '' \
    '❯ ' >"$claude_recap"
assert_extract 'Claude duration and recap chrome end a rendered prompt' \
    $'  Review the uncommitted diff and report Standards and Fidelity findings.\n  Stop when both axes are clean and the gate is still green.' \
    "$claude_recap"

claude_recap_only=$TMP_ROOT/claude-recap-only.txt
printf '%s\n' \
    'Ready-to-paste prompt:' \
    '' \
    'Re-run the gate and report the result.' \
    '' \
    '※ recap: the duration line scrolled off, the recap did not.' \
    '  (disable recaps in /config)' >"$claude_recap_only"
assert_extract 'recap block alone still ends a rendered prompt' \
    'Re-run the gate and report the result.' "$claude_recap_only"

duration_prose=$TMP_ROOT/duration-prose.txt
printf '%s\n' \
    'Ready-to-paste prompt:' \
    '' \
    'Run the soak for 30m and record the result.' \
    'Keep this line even though it reads like a duration.' \
    '' \
    '✻ Crunched for 4s' >"$duration_prose"
assert_extract 'ASCII prose mentioning a duration survives the chrome rule' \
    $'Run the soak for 30m and record the result.\nKeep this line even though it reads like a duration.' \
    "$duration_prose"

printf '1..%d\n' "$((passed + failed))"
if [ "$failed" -ne 0 ]; then
    printf '%d test(s) failed\n' "$failed" >&2
    exit 1
fi
