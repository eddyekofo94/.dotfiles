#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
herdr=${HERDR_BIN_PATH:-herdr}
socket=${HERDR_SOCKET_PATH:?history-export requires the Herdr socket}
pane=${HERDR_TARGET_PANE_ID:-${HERDR_PANE_ID:-}}
[ -n "$pane" ] || pane=$("$prototype/focused_pane.sh")

command -v jq >/dev/null 2>&1 || {
  echo "history-export: jq is required" >&2
  exit 69
}

printf 'Save focused-pane scrollback to file: '
IFS= read -r output_path || exit 0
[ -n "$output_path" ] || exit 0

case "$output_path" in
  /*) ;;
  *) output_path=$PWD/$output_path ;;
esac
parent=$(dirname -- "$output_path")
[ -d "$parent" ] || {
  echo "history-export: parent directory does not exist: $parent" >&2
  exit 4
}
[ ! -d "$output_path" ] || {
  echo "history-export: target is a directory: $output_path" >&2
  exit 4
}

overwrite=0
existing_identity=
if [ -e "$output_path" ] || [ -L "$output_path" ]; then
  existing_identity=$(stat -f '%d:%i' "$output_path")
  printf 'File exists. Replace %s? [y/N] ' "$output_path"
  IFS= read -r answer || answer=
  case "$answer" in
    y|Y|yes|YES|Yes) overwrite=1 ;;
    *) echo "history-export: existing file preserved" >&2; exit 3 ;;
  esac
fi

umask 077
temporary=$(mktemp "$parent/.herdr-history.XXXXXX")
trap 'rm -f -- "$temporary"' EXIT HUP INT TERM
request_id="history-export-$$"
payload=$(jq -cn --arg id "$request_id" --arg pane "$pane" '{
  id:$id,method:"pane.read",
  params:{pane_id:$pane,source:"recent",lines:4294967295,
    format:"text",strip_ansi:true}
}')
printf '%s\n' "$payload" | nc -U -w 2 "$socket" |
  jq -jer --arg id "$request_id" '
    select(.id == $id and has("result") and (has("error") | not)) |
    (.result.read.text // .result.text // .result.content) |
    select(type == "string")
  ' >"$temporary"
bytes=$(wc -c <"$temporary" | tr -d ' ')

if [ "$overwrite" -eq 0 ]; then
  ln "$temporary" "$output_path" 2>/dev/null || {
    echo "history-export: target appeared before write; file preserved" >&2
    exit 4
  }
  rm -f -- "$temporary"
  trap - EXIT HUP INT TERM
else
  HISTORY_EXPORT_SOURCE="$temporary" \
  HISTORY_EXPORT_IDENTITY="$existing_identity" \
  HISTORY_EXPORT_PATH="$output_path" \
  HISTORY_EXPORT_BEFORE_OPEN_HOOK="${HERDR_HISTORY_TEST_BEFORE_OPEN_HOOK:-}" \
  HISTORY_EXPORT_AFTER_OPEN_HOOK="${HERDR_HISTORY_TEST_AFTER_OPEN_HOOK:-}" \
  perl -e '
    use strict;
    use warnings;
    use Fcntl qw(O_RDWR);
    open my $input, "<:raw", $ENV{HISTORY_EXPORT_SOURCE}
      or die "history-export: cannot read temporary export: $!\n";
    if (length $ENV{HISTORY_EXPORT_BEFORE_OPEN_HOOK}) {
      system($ENV{HISTORY_EXPORT_BEFORE_OPEN_HOOK}, $ENV{HISTORY_EXPORT_PATH}) == 0
        or die "history-export: before-open test hook failed\n";
    }
    sysopen my $output, $ENV{HISTORY_EXPORT_PATH}, O_RDWR
      or die "history-export: confirmed target is no longer available: $!\n";
    my @identity = stat($output);
    @identity or die "history-export: cannot identify confirmed target: $!\n";
    "$identity[0]:$identity[1]" eq $ENV{HISTORY_EXPORT_IDENTITY}
      or die "history-export: target changed after confirmation; file preserved\n";
    if (length $ENV{HISTORY_EXPORT_AFTER_OPEN_HOOK}) {
      system($ENV{HISTORY_EXPORT_AFTER_OPEN_HOOK}, $ENV{HISTORY_EXPORT_PATH}) == 0
        or die "history-export: after-open test hook failed\n";
    }
    truncate($output, 0)
      or die "history-export: cannot truncate confirmed target: $!\n";
    chmod 0600, $output
      or die "history-export: cannot protect confirmed target: $!\n";
    while (1) {
      my $count = read($input, my $buffer, 65536);
      defined $count or die "history-export: read failed: $!\n";
      last if $count == 0;
      print {$output} $buffer
        or die "history-export: write failed: $!\n";
    }
    close $output or die "history-export: close failed: $!\n";
  ' || exit 4
  current_identity=
  if [ -e "$output_path" ] || [ -L "$output_path" ]; then
    current_identity=$(stat -f '%d:%i' "$output_path")
  fi
  [ "$current_identity" = "$existing_identity" ] || {
    echo "history-export: target path changed during write; replacement preserved" >&2
    exit 4
  }
  rm -f -- "$temporary"
  trap - EXIT HUP INT TERM
fi

jq -cn --arg pane "$pane" --arg path "$output_path" \
  --argjson bytes "$bytes" --argjson replaced "$overwrite" \
  '{result:{pane_id:$pane,path:$path,bytes:$bytes,replaced_existing:($replaced == 1)}}'
