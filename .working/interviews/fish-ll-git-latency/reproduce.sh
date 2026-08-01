#!/bin/sh
set -eu

target_dir=${1:-/Users/eddyekofo/Documents/Family_Business/RubyandRiver}
test -d "$target_dir" || {
    echo "ll latency: missing directory: $target_dir" >&2
    exit 2
}

measure_seconds() {
    command_name=$1
    shift
    latency_time_file=$(mktemp "${TMPDIR:-/tmp}/fish-ll-time.XXXXXX")
    set +e
    (
        cd "$target_dir"
        /usr/bin/time -p "$@" >/dev/null
    ) 2>"$latency_time_file"
    measured_status=$?
    set -e
    if test "$measured_status" -ne 0; then
        echo "ll latency: $command_name failed with status $measured_status" >&2
        cat "$latency_time_file" >&2
        unlink "$latency_time_file"
        exit 2
    fi
    result=$(awk '$1 == "real" { print $2 }' "$latency_time_file")
    unlink "$latency_time_file"
    test -n "$result" || {
        echo "ll latency: could not measure $command_name" >&2
        exit 2
    }
    echo "$result"
}

median_three() {
    printf '%s\n%s\n%s\n' "$1" "$2" "$3" | sort -n | sed -n '2p'
}

ll_1=$(measure_seconds ll fish -c 'll >/dev/null')
ll_2=$(measure_seconds ll fish -c 'll >/dev/null')
ll_3=$(measure_seconds ll fish -c 'll >/dev/null')
plain_1=$(measure_seconds eza-no-git eza --group-directories-first --icons --sort=modified --long --all --header .)
plain_2=$(measure_seconds eza-no-git eza --group-directories-first --icons --sort=modified --long --all --header .)
plain_3=$(measure_seconds eza-no-git eza --group-directories-first --icons --sort=modified --long --all --header .)

ll_median=$(median_three "$ll_1" "$ll_2" "$ll_3")
plain_median=$(median_three "$plain_1" "$plain_2" "$plain_3")
printf 'll median=%ss; eza-no-git median=%ss\n' "$ll_median" "$plain_median"

if awk -v ll="$ll_median" -v plain="$plain_median" \
    'BEGIN { exit !(ll >= 0.25 && plain < 0.10) }'; then
    echo 'll latency: RED (synchronous Git status isolated)'
    exit 1
fi

echo 'll latency: symptom not reproduced'
