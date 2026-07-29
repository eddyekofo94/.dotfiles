#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
herdr=${HERDR_BIN_PATH:-herdr}
picker=${HERDR_REFERENCE_PICKER:-fzf}
opener=${HERDR_REFERENCE_OPENER:-open}
clipboard=${HERDR_REFERENCE_CLIPBOARD:-pbcopy}
lines=${HERDR_REFERENCE_LINES:-1000}
pane=${HERDR_TARGET_PANE_ID:-${HERDR_PANE_ID:-}}
[ -n "$pane" ] || pane=$("$prototype/focused_pane.sh")

command -v jq >/dev/null 2>&1 || {
  echo "visible-reference-picker: jq is required" >&2
  exit 69
}
command -v "$picker" >/dev/null 2>&1 || {
  echo "visible-reference-picker: picker is unavailable: $picker" >&2
  exit 69
}
command -v "$clipboard" >/dev/null 2>&1 || {
  echo "visible-reference-picker: clipboard command is unavailable" >&2
  exit 69
}
case "$lines" in
  ''|*[!0-9]*) echo "visible-reference-picker: invalid line limit" >&2; exit 64 ;;
esac
[ "$lines" -gt 0 ] || {
  echo "visible-reference-picker: line limit must be positive" >&2
  exit 64
}

current=$("$herdr" pane current --pane "$pane")
cwd=$(printf '%s\n' "$current" | jq -er '
  .result.pane |
  select(.pane_id | type == "string" and length > 0) |
  (.foreground_cwd // .cwd // "")
')
readback=$("$herdr" pane read "$pane" --source recent-unwrapped \
  --lines "$lines" --format text)
case "$readback" in
  \{*) content=$(printf '%s\n' "$readback" | jq -er '.result.read.text') ;;
  *) content=$readback ;;
esac
candidates=$(printf '%s' "$content" | "$prototype/visible_references.py")
[ -n "$candidates" ] || {
  echo "visible-reference-picker: no URI, path, or hash references found" >&2
  exit 4
}

tab=$(printf '\t')
set +e
result=$(printf '%s\n' "$candidates" |
  FZF_DEFAULT_OPTS= FZF_DEFAULT_OPTS_FILE= "$picker" \
  --delimiter="$tab" --with-nth=1,2,4 \
  --header='Recent pane references (not copy mode): Enter copy • Ctrl-O open URI/path' \
  --prompt='Reference> ' --layout=reverse --border \
  --preview-window='down,4,wrap' \
  --preview='printf "type: %s\nvalue: %s\nline: %s\ncontext: %s\n" {1} {2} {3} {4}' \
  --expect=ctrl-o)
picker_status=$?
set -e
case "$picker_status" in
  0) ;;
  1|130) exit 0 ;;
  *) echo "visible-reference-picker: picker failed" >&2; exit "$picker_status" ;;
esac

key=$(printf '%s\n' "$result" | sed -n '1p')
selection=$(printf '%s\n' "$result" | sed -n '2p')
[ -n "$selection" ] || exit 0
old_ifs=$IFS
IFS=$tab
read -r kind reference line_number context <<EOF
$selection
EOF
IFS=$old_ifs
case "$kind" in
  uri|path|hash) ;;
  *) echo "visible-reference-picker: malformed reference type" >&2; exit 4 ;;
esac
[ -n "$reference" ] || {
  echo "visible-reference-picker: empty reference" >&2
  exit 4
}

if [ "$key" = "ctrl-o" ]; then
  [ "$kind" != hash ] || {
    echo "visible-reference-picker: hashes can be copied but not opened" >&2
    exit 4
  }
  command -v "$opener" >/dev/null 2>&1 || {
    echo "visible-reference-picker: opener is unavailable" >&2
    exit 69
  }
  target=$reference
  if [ "$kind" = path ]; then
    case "$target" in
      "~/"*) target=${HOME}/${target#\~/} ;;
      /*) ;;
      *) target=${cwd%/}/$target ;;
    esac
  fi
  printf '%s\n' "$target"
  exec "$opener" "$target"
fi

printf '%s' "$reference" | "$clipboard"
printf 'visible-reference-picker: copied %s reference\n' "$kind"
