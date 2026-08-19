#!/bin/sh
# Drives tools/set_macos_default_apps.sh against a fake duti so the idempotency
# and verification behaviour can be checked without touching Launch Services.
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-default-apps-test.XXXXXX")
trap 'rm -rf -- "$test_dir"' EXIT HUP INT TERM

mkdir "$test_dir/bin"

cat > "$test_dir/bin/duti" <<'EOF'
#!/bin/sh
set -eu

state_dir=$DUTI_TEST_STATE

case $1 in
-x)
    handler=$(cat "$state_dir/$2" 2>/dev/null || true)
    test -n "$handler"
    printf 'Fake\n/Applications/Fake.app\n%s\n' "$handler"
    ;;
-s)
    printf '%s\n' "$2" > "$state_dir/$3"
    printf '%s\n' "$3" >> "$state_dir/.claimed"
    ;;
esac
EOF
chmod +x "$test_dir/bin/duti"

cat > "$test_dir/bin/open" <<'EOF'
#!/bin/sh
exit "${OPEN_TEST_STATUS:-0}"
EOF
chmod +x "$test_dir/bin/open"

state=$test_dir/state
mkdir "$state"
printf 'org.videolan.vlc\n' > "$state/mp4"

run_script() {
    DUTI_TEST_STATE=$state DEFAULT_APPS_SETTLE_SECONDS=0 \
        PATH="$test_dir/bin:$PATH" \
        /bin/sh "$repo_dir/tools/set_macos_default_apps.sh"
}

# A first run claims only the extensions VLC does not already hold.
run_script > "$test_dir/first"
claimed=$(tr '\n' ' ' < "$state/.claimed")
if [ "$claimed" != 'm4v mkv avi mov ' ]; then
    echo "default apps test: expected the four unclaimed extensions, got: $claimed" >&2
    exit 1
fi

# A second run is a no-op: every extension already reports VLC.
: > "$state/.claimed"
run_script > "$test_dir/second"
if [ -s "$state/.claimed" ]; then
    echo 'default apps test: re-running must not re-claim extensions' >&2
    exit 1
fi

# A handler that refuses to change is reported instead of passing silently.
cat > "$test_dir/bin/duti" <<'EOF'
#!/bin/sh
set -eu
case $1 in
-x) printf 'Fake\n/Applications/Fake.app\ncom.apple.TV\n' ;;
-s) : ;;
esac
EOF
chmod +x "$test_dir/bin/duti"
if run_script > "$test_dir/third" 2>"$test_dir/third.err"; then
    echo 'default apps test: a refused claim must fail the script' >&2
    exit 1
fi
if ! grep -q 'did not take' "$test_dir/third.err"; then
    echo 'default apps test: a refused claim must name the extensions' >&2
    exit 1
fi

echo 'default apps test: passed'
