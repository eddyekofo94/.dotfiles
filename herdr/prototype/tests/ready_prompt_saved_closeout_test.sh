#!/usr/bin/env bash
# prefix+b after /clear: the screen holds no handoff, so ready_prompt.sh falls
# back to the closeout the Claude Stop hook saved for the pane. Runs the real
# script and capture hook against a stub herdr, so it needs no server.

set -u

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
READY=$ROOT/herdr/prototype/ready_prompt.sh
CAPTURE=$ROOT/agent-config/claude/closeout_capture.py
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/ready-prompt-saved.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
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

# The capture hook exactly as Claude runs it inside pane w1:p2 of window-9.
hook() {
    HERDR_PANE_ID=w1:p2 HERDR_SESSION=window-9 TMPDIR=$records \
        CLOSEOUT_CAPTURE_WAIT=0 python3 "$CAPTURE" "$@"
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
        HERDR_SESSION=window-9 HERDR_READY_PROMPT_STATE_DIR="$TMP_ROOT/state" \
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

printf '%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
