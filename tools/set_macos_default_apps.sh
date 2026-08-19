#!/bin/sh
# Hand every video container macOS otherwise gives to TV, QuickTime, or
# whatever installer claimed it last over to VLC. Safe to re-run: extensions
# already pointing at VLC are left untouched.
set -eu

vlc_bundle_id=org.videolan.vlc
video_extensions='mp4 m4v mkv avi mov'

if [ "$(uname -s)" != Darwin ]; then
    echo 'default apps: not macOS, nothing to do'
    exit 0
fi

if ! duti_bin=$(command -v duti 2>/dev/null); then
    if command -v brew >/dev/null 2>&1; then
        brew install duti
        duti_bin=$(command -v duti)
    else
        echo 'default apps: duti is required (brew install duti)' >&2
        exit 1
    fi
fi

if ! open -Ra VLC >/dev/null 2>&1; then
    echo 'default apps: VLC is not installed (brew install --cask vlc)' >&2
    exit 1
fi

# The third line of `duti -x` is the handler's bundle id; no handler at all
# exits non-zero, which is a mismatch rather than an error here.
current_handler() {
    "$duti_bin" -x "$1" 2>/dev/null | sed -n 3p || true
}

for extension in $video_extensions; do
    if [ "$(current_handler "$extension")" = "$vlc_bundle_id" ]; then
        echo "default apps: .$extension already opens in VLC"
        continue
    fi
    "$duti_bin" -s "$vlc_bundle_id" "$extension" all
    echo "default apps: .$extension now opens in VLC"
done

# Prove the stop condition rather than trusting duti's exit status: Launch
# Services can silently refuse a claim another app holds. It also answers from
# a cache that lags a fresh claim by a second or two, so give it time to settle
# before calling a mismatch a failure.
settle_seconds=${DEFAULT_APPS_SETTLE_SECONDS:-10}
elapsed=0
while :; do
    failed=
    for extension in $video_extensions; do
        if [ "$(current_handler "$extension")" != "$vlc_bundle_id" ]; then
            failed="$failed .$extension"
        fi
    done
    [ -n "$failed" ] || break
    [ "$elapsed" -lt "$settle_seconds" ] || break
    sleep 1
    elapsed=$((elapsed + 1))
done

if [ -n "$failed" ]; then
    echo "default apps: VLC did not take$failed" >&2
    exit 1
fi

echo 'default apps: VLC handles mp4, m4v, mkv, avi, mov'
