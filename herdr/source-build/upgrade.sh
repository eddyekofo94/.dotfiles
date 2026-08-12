#!/bin/sh
set -eu

# Move the reviewed private build to a newer upstream Herdr release.
#
# The work this removes is the bookkeeping, not the judgement: it finds the
# newest tag, re-applies the reviewed patch with a three-way merge, reports
# whether upstream has adopted the patched behavior, then runs the same gates
# build.sh always runs and records the resulting digests. It refuses to leave a
# half-migrated state: if the patch conflicts or a gate fails, the pins and the
# source tree are restored to what they were.
#
# usage:
#   upgrade.sh                 report whether a newer release exists, change nothing
#   upgrade.sh --apply         migrate, build, and re-pin, leaving the binary staged
#   upgrade.sh --apply --install   also install it over ~/.local/bin/herdr
#   upgrade.sh --tag vX.Y.Z ...    target a specific tag instead of the newest

source_build=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$source_build/../.." && pwd)
# The patch series comes from pins.env so this script and build.sh cannot
# disagree about what "the reviewed patch" is. Set after pins.env is sourced.
patches=
pins="$source_build/pins.env"
sb_verify="$source_build/verify.sh"
known_binaries="$source_build/known-binaries.txt"
work=${HERDR_SOURCE_BUILD_WORK:-"$source_build/.work"}
source_dir="$work/source"

apply=0
install_build=0
target_tag=

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply) apply=1 ;;
    --install) install_build=1 ;;
    --tag)
      shift
      target_tag=${1:-}
      if [ -z "$target_tag" ]; then
        echo "--tag needs a value, e.g. --tag v0.7.5" >&2
        exit 64
      fi
      ;;
    *)
      echo "usage: upgrade.sh [--apply] [--install] [--tag vX.Y.Z]" >&2
      exit 64
      ;;
  esac
  shift
done

if [ "$install_build" -eq 1 ] && [ "$apply" -eq 0 ]; then
  echo "--install only makes sense together with --apply" >&2
  exit 64
fi

# shellcheck source=/dev/null
. "$pins"

patches=${HERDR_PATCH_SERIES:-}
if [ -z "$patches" ]; then
  echo "pins.env defines no HERDR_PATCH_SERIES" >&2
  exit 65
fi

# Newest release tag by version order. Tags that are not vMAJOR.MINOR.PATCH are
# ignored so release candidates and moving tags cannot be selected by accident.
latest_tag() {
  git ls-remote --tags --refs "$HERDR_SOURCE_REPOSITORY" 'v*' |
    awk '{print $2}' |
    sed 's#refs/tags/##' |
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' |
    sort -t. -k1.2,1n -k2,2n -k3,3n |
    tail -1
}

if [ -z "$target_tag" ]; then
  target_tag=$(latest_tag)
  if [ -z "$target_tag" ]; then
    echo "could not read any release tag from $HERDR_SOURCE_REPOSITORY" >&2
    exit 69
  fi
fi

echo "pinned:  $HERDR_SOURCE_TAG"
echo "target:  $target_tag"

if [ "$target_tag" = "$HERDR_SOURCE_TAG" ]; then
  echo "Herdr upgrade: already on the newest reviewed release"
  exit 0
fi

target_tag_object=$(
  git ls-remote "$HERDR_SOURCE_REPOSITORY" "refs/tags/$target_tag" | awk '{print $1}'
)
target_commit=$(
  git ls-remote "$HERDR_SOURCE_REPOSITORY" "refs/tags/$target_tag^{}" | awk '{print $1}'
)
# Lightweight tags have no peeled object; the tag itself is the commit.
if [ -z "$target_commit" ]; then
  target_commit=$target_tag_object
fi
if [ -z "$target_tag_object" ] || [ -z "$target_commit" ]; then
  echo "could not resolve $target_tag in $HERDR_SOURCE_REPOSITORY" >&2
  exit 69
fi

if [ "$apply" -eq 0 ]; then
  echo
  echo "A newer release exists. Nothing has changed."
  echo "Re-run with --apply (optionally --install) to migrate the reviewed build."
  exit 0
fi

staging=$(mktemp -d "$work/upgrade.XXXXXX")
cleanup_staging() {
  if [ -n "${staging:-}" ] && [ -d "$staging" ]; then
    rm -rf -- "$staging"
  fi
}
trap cleanup_staging EXIT HUP INT TERM

echo
echo "fetching $target_tag ..."
git init --quiet "$staging/source"
git -C "$staging/source" remote add origin "$HERDR_SOURCE_REPOSITORY"
git -C "$staging/source" fetch --quiet --depth 1 origin \
  "refs/tags/$target_tag:refs/tags/$target_tag"
git -C "$staging/source" checkout --quiet --detach "$target_commit"

# Has upstream adopted what the patch adds? Each marker is text the patch
# introduces and the pinned base does not contain, so finding one in a pristine
# checkout means that behavior now ships natively and the patch should shrink or
# retire. Markers are matched as fixed strings and scoped to the narrowest path
# that can carry the feature: a loose marker like a bare "copy_mode_search"
# matches Herdr's own long-standing internals such as
# handle_copy_mode_search_prompt_key and would block every future upgrade.
adopted=0
check_adoption() {
  marker=$1
  scope=$2
  label=$3
  # shellcheck disable=SC2086
  if git -C "$staging/source" grep -qF "$marker" -- $scope 2>/dev/null; then
    echo "upstream $target_tag already provides $label"
    adopted=1
  fi
}
check_adoption "enter_copy_mode_search" "src" \
  "an entry point that opens copy mode already searching"
check_adoption "copy_mode_search" "src/config" \
  "a bindable copy-mode-search action"
check_adoption "'a' | 'i' | 'q'" "src/app/input/copy_mode.rs" \
  "the a/i/q copy-mode exit aliases"
check_adoption "HostCursorBlink" "src/client/mod.rs" \
  "client-owned native host-cursor blinking"
if [ "$adopted" -eq 1 ]; then
  echo
  echo "Herdr upgrade: STOPPED — upstream appears to ship part of the patch."
  echo "Re-review the patch against $target_tag and drop what is now native"
  echo "before upgrading. Nothing has changed."
  exit 75
fi

echo "applying the reviewed patch series with a three-way merge ..."
if ! for patch_name in $patches; do
  git -C "$staging/source" apply --3way "$source_build/$patch_name" || exit $?
done 2>"$staging/apply.err"; then
  conflicts=$(git -C "$staging/source" diff --name-only --diff-filter=U || true)
  echo
  echo "Herdr upgrade: STOPPED — the reviewed patch does not apply to $target_tag." >&2
  if [ -n "$conflicts" ]; then
    echo "conflicting files:" >&2
    printf '  %s\n' $conflicts >&2
  fi
  sed 's/^/  /' "$staging/apply.err" >&2 || true
  echo >&2
  echo "Nothing has changed. The patch needs a human rebase onto $target_tag." >&2
  exit 70
fi

# --3way implies --index, so the merged result lands staged. build.sh reads the
# patch as an unstaged working-tree diff, so unstage it here and leave the files
# modified; the tree then looks exactly like the plain-apply path.
git -C "$staging/source" reset --quiet

# A three-way merge rebases the patch onto the new base, so the recorded patch
# file no longer describes the tree: its context lines have moved. Regenerate it
# from the merged result, which is what build.sh hashes, and show the shape of
# the rebased patch so a human can still recognize their own change.
# Regenerated per patch, from the paths that patch owns, so the series survives
# the rebase as a series instead of collapsing into one unreviewable blob. The
# owned paths are read from the pre-rebase file: a three-way merge moves context
# lines, never which files a change touches.
for patch_name in $patches; do
  patch_paths=$(
    awk '/^diff --git a\// { sub(/^diff --git a\//, ""); sub(/ b\/.*$/, ""); print }' \
      "$source_build/$patch_name"
  )
  if [ -z "$patch_paths" ]; then
    echo "Herdr upgrade: STOPPED — $patch_name names no files." >&2
    exit 70
  fi
  # shellcheck disable=SC2086
  git -C "$staging/source" diff --binary --no-ext-diff -- $patch_paths \
    >"$staging/rebased.$patch_name"
done
cat_rebased() {
  for patch_name in $patches; do
    cat "$staging/rebased.$patch_name"
  done
}
cat_rebased >"$staging/rebased.patch"
# A per-patch regeneration can silently drop a hunk that moved between files;
# the whole-tree diff is the authority, so require the series to reconstruct it.
if ! git -C "$staging/source" diff --binary --no-ext-diff |
    diff -q - "$staging/rebased.patch" >/dev/null; then
  echo "Herdr upgrade: STOPPED — the regenerated series does not reconstruct" >&2
  echo "the rebased tree. A change moved between files; rebase by hand." >&2
  exit 70
fi
if [ ! -s "$staging/rebased.patch" ]; then
  echo "Herdr upgrade: STOPPED — the rebased patch is empty." >&2
  echo "That means $target_tag already contains the reviewed change." >&2
  exit 75
fi
echo
echo "rebased patch against $target_tag:"
git -C "$staging/source" diff --stat | sed 's/^/  /'

# Everything below can fail, so keep what is needed to put the build back.
backup=$(mktemp -d "$work/upgrade-backup.XXXXXX")
cp "$pins" "$backup/pins.env"
mkdir -p "$backup/patches"
for patch_name in $patches; do
  cp "$source_build/$patch_name" "$backup/patches/$patch_name"
done
cp "$sb_verify" "$backup/verify.sh"
restored=0
restore() {
  if [ "$restored" -eq 1 ]; then
    return
  fi
  restored=1
  cp "$backup/pins.env" "$pins"
  for patch_name in $patches; do
    cp "$backup/patches/$patch_name" "$source_build/$patch_name"
  done
  cp "$backup/verify.sh" "$sb_verify"
  if [ -d "$backup/source" ]; then
    rm -rf -- "$source_dir"
    mv "$backup/source" "$source_dir"
  fi
  rm -rf -- "$backup"
  echo "restored the previous pins, patch, and source tree" >&2
}

set_pin() {
  pin_tmp=$(mktemp "$source_build/.pins.XXXXXX")
  awk -v name="$1" -v value="$2" \
    'index($0, name "=") == 1 { print name "=" value; next } { print }' \
    "$pins" >"$pin_tmp"
  mv "$pin_tmp" "$pins"
}

if [ -d "$source_dir" ]; then
  mv "$source_dir" "$backup/source"
fi
mv "$staging/source" "$source_dir"
for patch_name in $patches; do
  cp "$staging/rebased.$patch_name" "$source_build/$patch_name"
done

# source-build/verify.sh carries its own hardcoded copy of the reviewed identity
# on purpose: it is the independent cross-check that catches a tampered or
# half-finished re-pin, so reading the value it is meant to police would defeat
# it. That only works if an upgrade actually rewrites it — leaving it stale makes
# every later verification fail on the version comparison before it reaches a
# single digest check, which is exactly what happened on the 0.7.4 -> 0.7.5 move.
set_verify_literal() {
  literal_tmp=$(mktemp "$source_build/.verify.XXXXXX")
  awk -v name="$1" -v value="$2" '
    index($0, "test \"$" name "\" = ") == 1 {
      print "test \"$" name "\" = " value
      next
    }
    { print }
  ' "$sb_verify" >"$literal_tmp"
  chmod --reference="$sb_verify" "$literal_tmp" 2>/dev/null ||
    chmod 0755 "$literal_tmp"
  mv "$literal_tmp" "$sb_verify"
}

target_version=${target_tag#v}

# The official release binary for the new tag: install.sh's download target and
# the fixture herdr/verify.sh uses to exercise atomic replacement.
echo "resolving the official $target_tag release binary ..."
official_asset=${HERDR_OFFICIAL_ASSET:-herdr-macos-aarch64}
official_url="https://github.com/ogulcancelik/herdr/releases/download/$target_tag/$official_asset"
if ! curl -fsSL "$official_url" -o "$staging/official" 2>/dev/null; then
  echo "Herdr upgrade: STOPPED — no official $official_asset for $target_tag." >&2
  echo "  $official_url" >&2
  exit 69
fi
target_official_sha=$(shasum -a 256 "$staging/official" | awk '{print $1}')
echo "official $target_tag: $target_official_sha"

set_pin HERDR_SOURCE_TAG "$target_tag"
set_pin HERDR_SOURCE_TAG_OBJECT "$target_tag_object"
set_pin HERDR_SOURCE_COMMIT "$target_commit"
set_pin HERDR_VERSION "$target_version"
set_pin HERDR_OFFICIAL_SHA256 "$target_official_sha"

set_verify_literal HERDR_SOURCE_TAG "$target_tag"
set_verify_literal HERDR_SOURCE_TAG_OBJECT "$target_tag_object"
set_verify_literal HERDR_SOURCE_COMMIT "$target_commit"

if ! awk -v d="$target_official_sha" '$1 == d { f = 1 } END { exit f ? 0 : 1 }' \
     "$known_binaries"; then
  printf '%s  official %s release (%s)\n' \
    "$target_official_sha" "$target_tag" "$official_asset" >>"$known_binaries"
fi

echo
echo "running the reviewed gates against $target_tag ..."
build_args="--repin"
if [ "$install_build" -eq 1 ]; then
  build_args="--install $build_args"
fi
# shellcheck disable=SC2086
if ! "$source_build/build.sh" $build_args; then
  echo >&2
  echo "Herdr upgrade: FAILED — the gates rejected $target_tag." >&2
  restore
  exit 66
fi

rm -rf -- "$backup"
echo
echo "Herdr upgrade: PASS — reviewed build now tracks $target_tag"
if [ "$install_build" -eq 0 ]; then
  echo "The binary is staged but not installed. Re-run with --install to replace"
  echo "~/.local/bin/herdr, or run build.sh --install."
fi
echo
echo "Changed in this repo: source-build/pins.env, the rebased patch,"
echo "source-build/verify.sh identity, known-binaries.txt. Commit them so the"
echo "build stays reproducible."
