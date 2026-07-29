#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
runtime="$prototype/.runtime/la"
config_home="$runtime/config"
fish_config="$config_home/fish/config.fish"
fixture="$prototype/login_attach_fixture.sh"
adapter="$prototype/herdr_login_attach.fish"
evidence_dir="$prototype/evidence"
evidence="$evidence_dir/login-attach-validation.jsonl"
evidence_tmp="$runtime/login-attach-validation.jsonl.tmp"
log="$runtime/launches.jsonl"
default_file="$runtime/default-multiplexer"

record() {
  jq -cn --arg check "$1" --argjson evidence "$2" \
    '{check:$check,evidence:$evidence}' >>"$evidence_tmp"
}

production_hashes() {
  jq -cn \
    --arg tmux "$(shasum -a 256 "$root/tmux/tmux.conf" | awk '{print $1}')" \
    --arg fish "$(shasum -a 256 "$root/fish/config.fish" | awk '{print $1}')" \
    --arg ghostty "$(shasum -a 256 "$root/ghostty/config" | awk '{print $1}')" \
    --arg neovim "$(shasum -a 256 "$HOME/.config/nvim/lua/plugin/tmux.lua" | awk '{print $1}')" \
    '{"tmux/tmux.conf":$tmux,"fish/config.fish":$fish,"ghostty/config":$ghostty,"~/.config/nvim/lua/plugin/tmux.lua":$neovim}'
}

launch_count() {
  wc -l <"$log" | tr -d ' '
}

run_case() {
  expected_delta=$1
  shift
  before=$(launch_count)
  env -u TMUX -u HERDR_ENV -u HERDR_PANE_ID -u HERDR_NO_AUTO_ATTACH \
    -u HERDR_LOGIN_SESSION XDG_CONFIG_HOME="$config_home" HERDR_BIN_PATH="$fixture" \
    HERDR_DEFAULT_FILE="$default_file" HERDR_LOGIN_ATTACH_LOG="$log" \
    HERDR_SKIP_PLUGIN_ENSURE=1 \
    "$@" </dev/null >/dev/null 2>&1
  after=$(launch_count)
  test $((after - before)) -eq "$expected_delta"
}

rm -rf "$runtime"
mkdir -p "$config_home/fish" "$evidence_dir"
: >"$evidence_tmp"
: >"$log"
printf 'herdr\n' >"$default_file"
printf 'source "%s"\n' "$adapter" >"$fish_config"
production_before=$(production_hashes)

fish --no-config -n "$adapter"
sh -n "$fixture"

run_case 1 fish --login --interactive --command 'exit 99'
default_args=$(sed -n '1p' "$log")
test "$default_args" = '["--session","main"]'

run_case 1 HERDR_LOGIN_SESSION=project-alpha fish --login --interactive --command 'exit 99'
custom_args=$(sed -n '2p' "$log")
test "$custom_args" = '["--session","project-alpha"]'

run_case 0 fish --interactive --command 'exit 0'
run_case 0 fish --login --command 'exit 0'
run_case 0 HERDR_ENV=1 fish --login --interactive --command 'exit 0'
run_case 0 HERDR_PANE_ID=w1:p1 fish --login --interactive --command 'exit 0'
run_case 0 TMUX=production fish --login --interactive --command 'exit 0'
run_case 0 HERDR_NO_AUTO_ATTACH=1 fish --login --interactive --command 'exit 0'
run_case 0 HERDR_LOGIN_SESSION='../bad' fish --login --interactive --command 'exit 0'
printf 'tmux\n' >"$default_file"
run_case 0 fish --login --interactive --command 'exit 0'
printf 'invalid\n' >"$default_file"
run_case 0 fish --login --interactive --command 'exit 0'
rm -f "$default_file"
run_case 0 fish --login --interactive --command 'exit 0'

record decisions "$(jq -cn --argjson default "$default_args" --argjson custom "$custom_args" '
  {top_level_login:{launched:true,args:$default},custom_session:{launched:true,args:$custom},
   guards:{non_login:true,non_interactive:true,herdr_env:true,herdr_pane:true,tmux:true,opt_out:true,invalid_session:true,tmux_default:true,invalid_default:true,missing_default:true},
   total_launches:2}
')"

production_after=$(production_hashes)
test "$production_after" = "$production_before"
artifact_hashes=$(jq -cn \
  --arg adapter "$(shasum -a 256 "$adapter" | awk '{print $1}')" \
  --arg fixture "$(shasum -a 256 "$fixture" | awk '{print $1}')" \
  --arg validator "$(shasum -a 256 "$0" | awk '{print $1}')" \
  '{adapter:$adapter,fixture:$fixture,validator:$validator}')
record scope_audit "$(jq -cn --argjson before "$production_before" \
  --argjson after "$production_after" --argjson artifacts "$artifact_hashes" \
  '{production_hashes_before:$before,production_hashes_after:$after,unchanged:($before==$after),artifact_hashes:$artifacts}')"
record result "$(jq -cn \
  '{status:"PASS",production_fish_modified:false,installed:false,migration_authorized:false}')"
mv "$evidence_tmp" "$evidence"
printf 'Herdr Fish login-attach validation: PASS (%s)\n' "$evidence"
