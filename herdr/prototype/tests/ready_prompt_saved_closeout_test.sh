#!/usr/bin/env bash
# prefix+b after /clear: the screen holds no handoff, so ready_prompt.sh falls
# back to the closeout the Claude Stop hook saved for the pane. Runs the real
# script and capture hook against a stub herdr, so it needs no server.

set -u

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
READY=$ROOT/herdr/prototype/ready_prompt.sh
CAPTURE=$ROOT/agent-config/claude/closeout_capture.py
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/ready-prompt-saved.XXXXXX")
window=window-9
pane_tmp=$TMP_ROOT/records
trap 'rm -rf "$TMP_ROOT"; rm -f /tmp/agent-prompt-turn-closeout.rp-test-'"$$"'.*' EXIT HUP INT TERM
records=$TMP_ROOT/records
mkdir -p "$records"

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

# The stub answers only what ready_prompt.sh asks. The pane's agent, screen, and
# Claude session come from files each case rewrites; inserted text is logged.
stub=$TMP_ROOT/herdr
cat >"$stub" <<'EOF'
#!/bin/sh
dir=$(dirname "$0")
case "$1 $2" in
  "pane process-info")
    printf '{"result":{"process_info":{"foreground_processes":[{"pid":4242,"argv0":"%s"}]}}}\n' \
      "$(cat "$dir/agent")" ;;
  "pane read") cat "$dir/screen" ;;
  "pane get")
    printf '{"result":{"pane":{"agent_session":{"agent":"claude","value":"%s"}}}}\n' \
      "$(cat "$dir/session")" ;;
  "pane send-text") printf '%s' "$4" >>"$dir/sent" ;;
  "notification show") ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$stub"

closeout() {
    printf 'Body.\n\n**Status:** DONE\nArtifacts: none\n**Next move:** go\n\n'
    printf '**Ready-to-paste prompt:**\n```\n%s\n```\n' "$1"
}

# The capture hook exactly as Claude runs it inside pane w1:p2 of $window. An
# empty $pane_tmp is a pane with no $TMPDIR, which writes to /tmp.
hook() {
    if [ -n "$pane_tmp" ]; then
        set -- env TMPDIR="$pane_tmp" python3 "$CAPTURE" "$@"
    else
        set -- env -u TMPDIR python3 "$CAPTURE" "$@"
    fi
    HERDR_PANE_ID=w1:p2 HERDR_SESSION=$window CLOSEOUT_CAPTURE_WAIT=0 "$@"
}

# One finished Claude turn whose closeout hands over <prompt>.
turn() {
    transcript=$TMP_ROOT/$1.jsonl
    closeout "$2" | python3 -c 'import json, sys
print(json.dumps({"type": "assistant",
    "message": {"content": [{"type": "text", "text": sys.stdin.read()}]}}))' >>"$transcript"
    printf '{"session_id":"%s","transcript_path":"%s"}' "$1" "$transcript" | hook
}

end_session() {
    printf '{"session_id":"%s","reason":"%s"}' "$1" "$2" | hook --session-end
}

# prefix+b in a pane: <agent> <session>, with the screen already written.
press() {
    printf '%s' "$1" >"$TMP_ROOT/agent"
    printf '%s' "$2" >"$TMP_ROOT/session"
    rm -rf "$TMP_ROOT/sent" "$TMP_ROOT/state"
    env -u HERDR_SOCKET_PATH HERDR_BIN_PATH="$stub" HERDR_PANE_ID=w1:p2 \
        HERDR_SESSION=${press_window-$window} HERDR_READY_PROMPT_STATE_DIR="$TMP_ROOT/state" \
        HERDR_READY_PROMPT_LOG="$TMP_ROOT/ready-prompt.log" \
        TMPDIR="$records" "$READY" >/dev/null 2>&1
}

inserted() {
    grep -Fq "$1" "$TMP_ROOT/sent" 2>/dev/null
}

turn s1 "Replay s1."

closeout "From the screen." >"$TMP_ROOT/screen"
if press claude s1 && inserted "From the screen." && ! inserted "Replay s1."; then
    pass "a handoff on screen wins over the saved closeout"
else
    fail "a handoff on screen wins over the saved closeout"
fi

: >"$TMP_ROOT/screen"
if press claude s1 && inserted "Replay s1."; then
    pass "a blank screen falls back to the session's saved closeout"
else
    fail "a blank screen falls back to the session's saved closeout"
fi

end_session s1 clear
if press claude s2 && inserted "Replay s1."; then
    pass "after /clear the new session replays the carried closeout"
else
    fail "after /clear the new session replays the carried closeout"
fi

if ! press codex s2 && ! inserted "Replay s1."; then
    pass "a non-Claude pane never reads Claude's saved closeout"
else
    fail "a non-Claude pane never reads Claude's saved closeout"
fi

end_session s2 prompt_input_exit
if ! press claude s3 && ! inserted "Replay s1."; then
    pass "a real session end leaves nothing for the next occupant"
else
    fail "a real session end leaves nothing for the next occupant"
fi

# The Herdr client that runs prefix+b can have another $TMPDIR than the pane:
# window-81's panes had none (/tmp) while its client had /var/folders/.../T/.
window=rp-test-$$
pane_tmp=
turn s10 "Replay from /tmp."
: >"$TMP_ROOT/screen"
if press claude s10 && inserted "Replay from /tmp."; then
    pass "the client finds a record the pane wrote under another TMPDIR"
else
    fail "the client finds a record the pane wrote under another TMPDIR"
fi

# The keybinding may name no Herdr session. The session id still finds the
# pane's own record, and a single carry for this pane id is still this pane's.
window=window-9
pane_tmp=$records
press_window=
turn s20 "No session name."
if press claude s20 && inserted "No session name."; then
    pass "a press with no Herdr session finds the session's own record"
else
    fail "a press with no Herdr session finds the session's own record"
fi
end_session s20 clear
if press claude s21 && inserted "No session name."; then
    pass "a press with no Herdr session finds the only carried closeout"
else
    fail "a press with no Herdr session finds the only carried closeout"
fi
unset press_window

# Every press is logged, so a failure in the real keybinding environment can be
# read afterwards instead of guessed at.
end_session s21 logout
if ! press claude s22 && grep -q "no saved closeout" "$TMP_ROOT/ready-prompt.log"; then
    pass "a press that finds nothing logs why"
else
    fail "a press that finds nothing logs why"
fi

printf '%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
