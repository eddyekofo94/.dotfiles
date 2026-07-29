#!/bin/sh
set -eu

state_file=${HERDR_PLUGIN_FIXTURE_STATE:?}
state=0
if [ -r "$state_file" ]; then
  read -r state <"$state_file"
fi

case "$*" in
  *' plugin link '*)
    printf '1\n' >"$state_file"
    exit 0
    ;;
  *' plugin list '*)
    case "$state" in
      0) printf '%s\n' '{"result":{"plugins":[]}}' ;;
      1)
        printf '2\n' >"$state_file"
        printf '%s\n' '{not-ready'
        ;;
      *)
        printf '%s\n' '{"result":{"plugins":[{"plugin_id":"prototype.golden-focus","enabled":true}]}}'
        ;;
    esac
    exit 0
    ;;
esac

exit 64
