#!/bin/sh
set -eu

# Stand-in for the herdr CLI in ensure_plugins.sh's tests. Line 1 of the state
# file records whether the one-off unparseable answer has been served; line 2 is
# the set of plugin ids linked so far, which is what the gate asserts on.
state_file=${HERDR_PLUGIN_FIXTURE_STATE:?}
glitched=0
linked=
if [ -r "$state_file" ]; then
  glitched=$(sed -n '1p' "$state_file")
  linked=$(sed -n '2p' "$state_file")
fi

save() {
  printf '%s\n%s\n' "$glitched" "$linked" >"$state_file"
}

# Joined once: `${*##...}` is not portable, and every match below is on the
# whole command line rather than a fixed argument position.
args="$*"

case "$args" in
  *' plugin link '*)
    root=${args##* plugin link }
    root=${root%% *}
    # These prototypes all declare `prototype.<directory>` as their id.
    linked="$linked prototype.$(basename "$root")"
    save
    exit 0
    ;;
  *' plugin list '*)
    id=${args##*--plugin }
    id=${id%% *}
    case " $linked " in
      *" $id "*)
        if [ "$glitched" -eq 0 ]; then
          # One unparseable answer, so the caller's retry loop is exercised
          # rather than merely present.
          glitched=1
          save
          printf '%s\n' '{not-ready'
          exit 0
        fi
        printf '{"result":{"plugins":[{"plugin_id":"%s","enabled":true}]}}\n' "$id"
        ;;
      *) printf '%s\n' '{"result":{"plugins":[]}}' ;;
    esac
    exit 0
    ;;
esac

exit 64
