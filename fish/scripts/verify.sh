#!/bin/sh
set -eu

package_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
repo_dir=$(CDPATH= cd -- "$package_dir/.." && pwd)

"$repo_dir/agent-config/tests/install_test.sh"
"$repo_dir/agent-config/verify.sh"

/bin/sh "$repo_dir/tools/audit_transport_security.sh"
/bin/sh "$package_dir/scripts/audit_environment.sh"
/bin/sh "$package_dir/scripts/audit_startup_ownership.sh"

find "$package_dir" -type f -name '*.fish' ! -path '*/.fisher/*' -print |
    while IFS= read -r file; do
        fish --no-execute "$file"
    done

fish -i -c 'functions -q fzf_complete'

if rg -n 'fish -c .*&[[:space:]]*disown|__[Ff]ish_(vcs|venv)_info_' \
    "$package_dir/functions" "$package_dir/conf.d" "$package_dir/config.fish" \
    "$package_dir/fish_variables"; then
    echo 'fish verification: unsafe async prompt worker or persistent prompt cache found' >&2
    exit 1
fi

"$package_dir/tests/fif_integration.sh"
"$package_dir/tests/fif_real_fzf.sh"
"$package_dir/tests/fcat_integration.sh"
"$package_dir/tests/fzf_preview_integration.sh"
"$package_dir/tests/startup_consumer_integration.sh"
"$package_dir/tests/interactive_consumer_pty.sh"
"$package_dir/tests/interactive_consumer_tmux.sh"
/usr/bin/expect "$package_dir/tests/measure_prompt_latency.exp" "$repo_dir"
count_short_fish_workers() {
    ps -axo command= |
        awk '$0 ~ /^((\/opt\/homebrew\/bin\/)?fish) -c / { count++ }
             END { print count + 0 }'
}

before=$(count_short_fish_workers)
i=0
while [ "$i" -lt 20 ]; do
    fish -i -c true >/dev/null 2>&1
    i=$((i + 1))
done
after=$(count_short_fish_workers)
if [ "$after" -gt "$before" ]; then
    echo "fish verification: repeated shells left workers behind ($before -> $after)" >&2
    exit 1
fi

python3 "$package_dir/scripts/benchmark_startup.py"

git -C "$repo_dir" diff --check -- fish
echo 'fish verification: PASS'
