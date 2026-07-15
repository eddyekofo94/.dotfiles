#!/bin/sh
set -eu

package_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
repo_dir=$(CDPATH= cd -- "$package_dir/.." && pwd)

find "$package_dir" -type f -name '*.fish' ! -path '*/.fisher/*' -print |
    while IFS= read -r file; do
        fish --no-execute "$file"
    done

if rg -n 'fish -c .*&[[:space:]]*disown|__[Ff]ish_(vcs|venv)_info_' \
    "$package_dir/functions" "$package_dir/conf.d" "$package_dir/config.fish" \
    "$package_dir/fish_variables"; then
    echo 'fish verification: unsafe async prompt worker or persistent prompt cache found' >&2
    exit 1
fi

"$package_dir/tests/fif_integration.sh"
"$package_dir/tests/fif_real_fzf.sh"

before=$(ps -axo command= | rg -c '^(/opt/homebrew/bin/)?fish -c ' || true)
i=0
while [ "$i" -lt 20 ]; do
    fish -i -c true >/dev/null 2>&1
    i=$((i + 1))
done
after=$(ps -axo command= | rg -c '^(/opt/homebrew/bin/)?fish -c ' || true)
if [ "$after" -gt "$before" ]; then
    echo "fish verification: repeated shells left workers behind ($before -> $after)" >&2
    exit 1
fi

git -C "$repo_dir" diff --check -- fish
echo 'fish verification: PASS'
