#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    echo "usage: $0 HTTPS_URL SHA256" >&2
    exit 64
fi

url=$1
expected_sha256=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')

case "$url" in
    https://*) ;;
    *)
        echo "verified fetch: refusing non-HTTPS URL: $url" >&2
        exit 65
        ;;
esac

if [ "${#expected_sha256}" -ne 64 ] ||
    printf '%s' "$expected_sha256" | grep -q '[^0-9a-f]'; then
    echo 'verified fetch: expected SHA-256 must be 64 hexadecimal characters' >&2
    exit 65
fi

fetch_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-fetch.XXXXXX")
payload=$fetch_dir/payload
trap 'rm -rf -- "$fetch_dir"' EXIT HUP INT TERM

curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error \
    --output "$payload" "$url"

if command -v sha256sum >/dev/null 2>&1; then
    actual_sha256=$(sha256sum "$payload" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
    actual_sha256=$(shasum -a 256 "$payload" | awk '{print $1}')
else
    echo 'verified fetch: sha256sum or shasum is required' >&2
    exit 69
fi

if [ "$actual_sha256" != "$expected_sha256" ]; then
    echo "verified fetch: SHA-256 mismatch for $url" >&2
    echo "expected: $expected_sha256" >&2
    echo "actual:   $actual_sha256" >&2
    exit 66
fi

cat "$payload"
