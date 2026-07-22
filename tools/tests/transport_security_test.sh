#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-transport-test.XXXXXX")
trap 'rm -rf -- "$test_dir"' EXIT HUP INT TERM

payload=$test_dir/payload
printf '%s\n' 'verified bootstrap fixture' > "$payload"

mkdir "$test_dir/bin"
mock_curl=$test_dir/bin/curl
cat > "$mock_curl" <<'EOF'
#!/bin/sh
set -eu

output=
while [ "$#" -gt 0 ]; do
    if [ "$1" = '--output' ]; then
        shift
        output=$1
    fi
    shift
done

test -n "$output"
cp "$TRANSPORT_TEST_PAYLOAD" "$output"
EOF
chmod +x "$mock_curl"

if command -v sha256sum >/dev/null 2>&1; then
    expected_sha256=$(sha256sum "$payload" | awk '{print $1}')
else
    expected_sha256=$(shasum -a 256 "$payload" | awk '{print $1}')
fi

TRANSPORT_TEST_PAYLOAD=$payload \
    PATH="$test_dir/bin:$PATH" \
    /bin/sh "$repo_dir/tools/fetch_verified.sh" \
    https://example.invalid/bootstrap "$expected_sha256" > "$test_dir/result"
cmp "$payload" "$test_dir/result"

bad_sha256=0000000000000000000000000000000000000000000000000000000000000000
if TRANSPORT_TEST_PAYLOAD=$payload \
    PATH="$test_dir/bin:$PATH" \
    /bin/sh "$repo_dir/tools/fetch_verified.sh" \
    https://example.invalid/bootstrap "$bad_sha256" > "$test_dir/rejected" 2>/dev/null; then
    echo 'transport security test: checksum mismatch was accepted' >&2
    exit 1
fi

if [ -s "$test_dir/rejected" ]; then
    echo 'transport security test: rejected content reached standard output' >&2
    exit 1
fi

echo 'transport security test: PASS'
