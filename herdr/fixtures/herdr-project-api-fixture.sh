#!/bin/sh
set -eu

real_bin=${HERDR_FIXTURE_REAL_BIN:?real Herdr binary required}
mode=${HERDR_FIXTURE_MODE:?fixture mode required}

case "$mode:$*" in
  "malformed-workspaces:"*" workspace list")
    printf '%s\n' '{"result":{"workspaces":"malformed"}}'
    exit 0
    ;;
  "malformed-panes:"*" pane list")
    printf '%s\n' '{"result":{"panes":[{"workspace_id":7,"cwd":[]}]}}'
    exit 0
    ;;
  "malformed-pane-envelope:"*" pane list")
    printf '%s\n' '{"result":{"panes":[]}}'
    exit 0
    ;;
  "create-failure:"*" workspace create "*)
    "$real_bin" "$@" >/dev/null
    exit 1
    ;;
  "focus-failure:"*" workspace focus "*)
    "$real_bin" "$@" >/dev/null
    exit 1
    ;;
  "metadata-failure:"*" workspace report-metadata "*)
    case " $* " in
      *" --clear-token "*)
        exec "$real_bin" "$@"
        ;;
    esac
    "$real_bin" "$@" >/dev/null
    exit 1
    ;;
  "malformed-create:"*" workspace create "*)
    "$real_bin" "$@" >/dev/null
    printf '%s\n' '{"result":{"workspace":"malformed"}}'
    exit 0
    ;;
  "malformed-unexpected-create:"*" workspace create "*)
    "$real_bin" --session "${HERDR_PROJECT_SESSION:?session required}" \
      workspace create \
      --cwd "${HERDR_FIXTURE_WRONG_CWD:?wrong cwd required}" \
      --label wrong-project --no-focus >/dev/null
    printf '%s\n' '{"result":{"workspace":"malformed"}}'
    exit 0
    ;;
  "wrong-create-state:"*" workspace create "*)
    "$real_bin" "$@" |
      jq '.result.workspace.label = "wrong-project"'
    exit 0
    ;;
  "wrong-live-create-state:"*" workspace create "*)
    "$real_bin" --session "${HERDR_PROJECT_SESSION:?session required}" \
      workspace create \
      --cwd "${HERDR_FIXTURE_WRONG_CWD:?wrong cwd required}" \
      --label "${HERDR_FIXTURE_EXPECTED_LABEL:?expected label required}" \
      --no-focus |
      jq --arg cwd "${HERDR_FIXTURE_EXPECTED_CWD:?expected cwd required}" '
        .result.root_pane.cwd = $cwd |
        .result.root_pane.foreground_cwd = $cwd
      '
    exit 0
    ;;
  "rewritten-existing-id:"*" workspace create "*)
    "$real_bin" "$@" |
      jq --arg workspace \
        "${HERDR_FIXTURE_EXISTING_ID:?existing workspace id required}" '
        .result.workspace.workspace_id = $workspace |
        .result.tab.workspace_id = $workspace |
        .result.root_pane.workspace_id = $workspace
      '
    exit 0
    ;;
  "metadata-noop:"*" workspace report-metadata "*)
    case " $* " in
      *" --clear-token "*)
        exec "$real_bin" "$@"
        ;;
    esac
    exit 0
    ;;
  "unrelated-create-failure:"*" workspace create "*)
    "$real_bin" "$@" >/dev/null
    "$real_bin" --session "${HERDR_PROJECT_SESSION:?session required}" \
      workspace create \
      --cwd "${HERDR_FIXTURE_UNRELATED_CWD:?unrelated cwd required}" \
      --label unrelated --no-focus >/dev/null
    exit 1
    ;;
  "slow-create:"*" workspace create "*)
    sleep 0.5
    exec "$real_bin" "$@"
    ;;
  "malformed-post-focus:"*" workspace focus "*)
    "$real_bin" "$@" >/dev/null
    : >"${HERDR_FIXTURE_STATE:?fixture state path required}"
    exit 0
    ;;
  "malformed-post-focus:"*" workspace list")
    if [ -f "${HERDR_FIXTURE_STATE:?fixture state path required}" ]; then
      "$real_bin" "$@" |
        jq '.result.workspaces += [{"workspace_id":7,"focused":"yes"}]'
      exit 0
    fi
    ;;
esac

exec "$real_bin" "$@"
