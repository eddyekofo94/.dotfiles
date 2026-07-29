#!/bin/sh
set -eu

mode=${HERDR_MANAGE_FIXTURE_MODE:-select}
case "$mode" in
  cancel) cat >/dev/null; exit 130 ;;
  fail) cat >/dev/null; exit 42 ;;
  select) ;;
  *) echo "unknown manage picker fixture mode: $mode" >&2; exit 64 ;;
esac

kind=${HERDR_MANAGE_FIXTURE_KIND:?}
id=${HERDR_MANAGE_FIXTURE_ID:?}
selection=$(awk -F '\t' -v kind="$kind" -v id="$id" \
  '$1 == kind && $2 == id { print; found=1; exit } END { if (!found) exit 4 }')

if [ -n "${HERDR_MANAGE_FIXTURE_MUTATION:-}" ]; then
  state=${HERDR_PICKER_REFERENCE_STATE:?}
  tmp="$state.tmp"
  case "$HERDR_MANAGE_FIXTURE_MUTATION" in
    pane)
      jq --arg id "$id" '
        .panes |= map(
          if .pane_id == $id then .terminal_id = (.terminal_id + "-changed")
          else . end
        )
      ' "$state" >"$tmp"
      ;;
    tab)
      jq --arg id "$id" '
        (.tabs[] | select(.tab_id == $id)) as $tab |
        .panes |= map(
          if .tab_id == $tab.tab_id
          then .terminal_id = (.terminal_id + "-changed")
          else . end
        )
      ' "$state" >"$tmp"
      ;;
    workspace)
      jq --arg id "$id" '
        .panes |= map(
          if .workspace_id == $id
          then .terminal_id = (.terminal_id + "-changed")
          else . end
        )
      ' "$state" >"$tmp"
      ;;
    *)
      echo "unknown manage fixture mutation" >&2
      exit 64
      ;;
  esac
  mv "$tmp" "$state"
fi

escape=$(printf '\033')
case "$selection" in
  *"$escape"*) echo "manage picker received an escape byte" >&2; exit 5 ;;
esac
printf '%s\n' "$selection"
