#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
herdr="$prototype/.runtime/bin/herdr"
evidence_dir="$prototype/evidence"
evidence="$evidence_dir/capability-gap-validation.jsonl"
evidence_tmp=$(mktemp /tmp/herdr-capability-gap-validation.XXXXXX)

[ -x "$herdr" ] || {
  echo "capability-gap validation requires the prototype Herdr binary" >&2
  exit 2
}
"$root/herdr/source-build/verify.sh" >/dev/null

production_hashes() {
  jq -cn \
    --arg tmux "$(shasum -a 256 "$root/tmux/tmux.conf" | awk '{print $1}')" \
    --arg fish "$(shasum -a 256 "$root/fish/config.fish" | awk '{print $1}')" \
    --arg ghostty "$(shasum -a 256 "$root/ghostty/config" | awk '{print $1}')" \
    --arg nvim "$(shasum -a 256 "$HOME/.config/nvim/lua/plugin/tmux.lua" | awk '{print $1}')" \
    '{"tmux/tmux.conf":$tmux,"fish/config.fish":$fish,"ghostty/config":$ghostty,"~/.config/nvim/lua/plugin/tmux.lua":$nvim}'
}

record() {
  jq -cn --arg check "$1" --argjson evidence "$2" \
    '{check:$check,evidence:$evidence}' >>"$evidence_tmp"
}

cleanup() {
  exit_code=$?
  trap - EXIT INT TERM
  rm -f "$evidence_tmp"
  exit "$exit_code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p "$evidence_dir"
: >"$evidence_tmp"
production_before=$(production_hashes)
defaults=$($herdr --default-config)
version=$($herdr --version)

# These names represent the legacy tmux affordances, not broad substrings such
# as "copy" that legitimately describe Herdr's supported ordinary copy mode.
if printf '%s\n' "$defaults" | grep -Eiq \
  'rectangle[_-]?select|copy[_-]?line|copy[_-]?url|open[_-]?url|set[_-]?mark|goto[_-]?mark|prompt[_-]?jump|osc[ _-]?133'; then
  echo "v0.7.4 now exposes a previously unavailable capability; re-audit the tracker" >&2
  exit 1
fi

grep -Fq 'copy_mode = "prefix+s"' "$prototype/config.toml"
grep -Fq 'last_pane = ["prefix+tab", "ctrl+^"]' "$prototype/config.toml"
if grep -Eiq 'alt\+tab|9;3u|rectangle[_-]?select|copy[_-]?line|set[_-]?mark|goto[_-]?mark|prompt[_-]?jump|osc[ _-]?133' \
  "$prototype/config.toml" "$prototype/herdr_nav.fish"; then
  echo "unsupported capability emulation is installed in the prototype" >&2
  exit 1
fi

record surface "$(jq -cn --arg version "$version" \
  --arg defaults_sha256 "$(printf '%s\n' "$defaults" | shasum -a 256 | awk '{print $1}')" \
  '{version:$version,default_config_sha256:$defaults_sha256,
    upstream_configurable_actions_absent:["rectangle-selection","copy-line-Y","marks","OSC-133-prompt-jumps","copy-mode-cursor-URL"],
    reviewed_source_extensions:["copy-line-Y"],
    absence_deterministic:true}')"
record alternatives "$(jq -cn \
  '{ordinary_selection:{keys:["v","Space","y","Y","Enter"],evidence:"copy-mode-validation.jsonl"},
    paging:{keys:["Ctrl-u","Ctrl-d","PageUp","PageDown"],evidence:"copy-mode-validation.jsonl"},
    visible_url:{key:"prefix+u",evidence:"url-validation.jsonl"},
    last_location:{keys:["prefix+Tab","Ctrl-^/Ctrl-6"],semantics:"last-pane"}}')"
record policy "$(jq -cn \
  '{alt_tab:"retired",rectangle_selection:"unavailable",copy_line_Y:"reviewed-source-build",
    marks:"unavailable",prompt_jumps:"unavailable",copy_mode_O:"unavailable",
    input_emulation_installed:false,global_alt_binding_installed:true,
    production_config_change_required:false}')"

production_after=$(production_hashes)
test "$production_after" = "$production_before"
record scope_audit "$(jq -cn --argjson before "$production_before" \
  --argjson after "$production_after" \
  --arg config "$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')" \
  --arg nav "$(shasum -a 256 "$prototype/herdr_nav.fish" | awk '{print $1}')" \
  --arg source_patch "$(shasum -a 256 "$root/herdr/source-build/copy-mode-vim-muscle-memory.patch" | awk '{print $1}')" \
  --arg validator "$(shasum -a 256 "$0" | awk '{print $1}')" \
  '{production_hashes_before:$before,production_hashes_after:$after,unchanged:($before==$after),
    artifact_hashes:{config:$config,nav:$nav,source_patch:$source_patch,validator:$validator}}')"
record result "$(jq -cn \
  '{status:"PASS",production_configuration_modified:false,
    unsupported_emulation_installed:false,migration_authorized:false}')"

mv "$evidence_tmp" "$evidence"
printf 'Herdr capability-gap validation: PASS (%s)\n' "$evidence"
