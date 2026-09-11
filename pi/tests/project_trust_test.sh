#!/bin/sh
set -eu

pi_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
pilot=${1:-"$pi_dir/pilot.sh"}
case "$pilot" in
  /*) ;;
  *) pilot="$PWD/${pilot#./}" ;;
esac
runtime=$(mktemp -d /private/tmp/pi-project-trust.XXXXXX)
cleanup() { rm -rf "$runtime"; }
trap cleanup EXIT HUP INT TERM

trusted_parent="$runtime/trusted-parent"
trusted="$trusted_parent/project"
untrusted="$runtime/untrusted-parent/project"
for project in "$trusted" "$untrusted"; do
  skill="$project/.agents/skills/project-trust-fixture"
  mkdir -p "$skill"
  printf '%s\n' \
    '---' \
    'name: project-trust-fixture' \
    'description: Project trust regression fixture.' \
    '---' \
    '# Project trust fixture' >"$skill/SKILL.md"
done

trust_store="$PI_PILOT_STATE_DIR/config/trust.json"
printf '{"%s":true}\n' "$trusted_parent" >"$trust_store"
chmod 600 "$trust_store"

commands() {
  project=$1
  output=$2
  (cd "$project" && printf '%s\n' \
    '{"id":"commands","type":"get_commands"}' |
    "$pilot" --mode rpc --no-session) >"$output"
}

commands "$trusted" "$runtime/trusted.jsonl"
jq -e '
  select(.id == "commands") |
  any(.data.commands[]?; .name == "skill:project-trust-fixture")
' "$runtime/trusted.jsonl" >/dev/null

commands "$untrusted" "$runtime/untrusted.jsonl"
jq -e '
  select(.id == "commands") |
  any(.data.commands[]?; .name == "skill:project-trust-fixture") | not
' "$runtime/untrusted.jsonl" >/dev/null

printf 'Pi saved project trust and unknown-project refusal: PASS\n'
