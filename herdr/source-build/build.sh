#!/bin/sh
set -eu

source_build=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$source_build/../.." && pwd)
patch="$source_build/copy-mode-vim-muscle-memory.patch"
pins="$source_build/pins.env"
work=${HERDR_SOURCE_BUILD_WORK:-"$source_build/.work"}
source_dir="$work/source"
target_dir="$work/target"
output_dir="$work/bin"
output="$output_dir/herdr"
install_build=0
repin=0

# --repin rewrites the three digests in pins.env from what this run actually
# produced, instead of refusing to build when they drift. Every other gate still
# runs: the digests record a reviewed result, they do not authorize one. Use it
# after deliberately changing the patch or moving to a new upstream tag.
while [ "$#" -gt 0 ]; do
  case "$1" in
    --install) install_build=1 ;;
    --repin) repin=1 ;;
    *)
      echo "usage: build.sh [--install] [--repin]" >&2
      exit 64
      ;;
  esac
  shift
done

repin_pin() {
  pin_name=$1
  pin_value=$2
  if ! grep -q "^$pin_name=" "$pins"; then
    echo "pins.env has no $pin_name to rewrite" >&2
    exit 65
  fi
  pin_tmp=$(mktemp "$source_build/.pins.XXXXXX")
  awk -v name="$pin_name" -v value="$pin_value" \
    'index($0, name "=") == 1 { print name "=" value; next } { print }' \
    "$pins" >"$pin_tmp"
  mv "$pin_tmp" "$pins"
  echo "repinned $pin_name=$pin_value"
}

# shellcheck source=/dev/null
. "$pins"

if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != arm64 ]; then
  echo "reviewed Herdr binary pin requires arm64 macOS" >&2
  exit 69
fi

require_sha256() {
  name=$1
  value=$2
  case "$value" in
    *[!0-9a-f]*|"")
      echo "$name must be a lowercase SHA-256 digest, got: $value" >&2
      exit 65
      ;;
  esac
  if [ "${#value}" -ne 64 ]; then
    echo "$name must contain 64 hexadecimal characters" >&2
    exit 65
  fi
}

require_sha1() {
  name=$1
  value=$2
  case "$value" in
    *[!0-9a-f]*|"")
      echo "$name must be a lowercase Git object ID, got: $value" >&2
      exit 65
      ;;
  esac
  if [ "${#value}" -ne 40 ]; then
    echo "$name must contain 40 hexadecimal characters" >&2
    exit 65
  fi
}

require_sha1 HERDR_SOURCE_TAG_OBJECT "$HERDR_SOURCE_TAG_OBJECT"
require_sha1 HERDR_SOURCE_COMMIT "$HERDR_SOURCE_COMMIT"
require_sha256 HERDR_PATCH_SHA256 "$HERDR_PATCH_SHA256"
require_sha256 HERDR_PATCHED_SOURCE_SHA256 "$HERDR_PATCHED_SOURCE_SHA256"
require_sha256 HERDR_BINARY_SHA256 "$HERDR_BINARY_SHA256"

actual_patch_sha=$(shasum -a 256 "$patch" | awk '{print $1}')
if [ "$actual_patch_sha" != "$HERDR_PATCH_SHA256" ]; then
  if [ "$repin" -eq 1 ]; then
    repin_pin HERDR_PATCH_SHA256 "$actual_patch_sha"
    HERDR_PATCH_SHA256=$actual_patch_sha
  else
    echo "Herdr patch SHA-256 mismatch" >&2
    exit 66
  fi
fi

mkdir -p "$work" "$output_dir"
if [ ! -e "$source_dir/.git" ]; then
  if [ -e "$source_dir" ]; then
    echo "refusing non-Git source-build path: $source_dir" >&2
    exit 73
  fi
  git init --quiet "$source_dir"
  git -C "$source_dir" remote add origin "$HERDR_SOURCE_REPOSITORY"
  git -C "$source_dir" fetch --quiet --depth 1 origin \
    "refs/tags/$HERDR_SOURCE_TAG:refs/tags/$HERDR_SOURCE_TAG"
  git -C "$source_dir" checkout --quiet --detach "$HERDR_SOURCE_COMMIT"
fi

origin=$(git -C "$source_dir" remote get-url origin)
if [ "$origin" != "$HERDR_SOURCE_REPOSITORY" ]; then
  echo "Herdr source origin mismatch: $origin" >&2
  exit 66
fi
tag_object=$(git -C "$source_dir" rev-parse "refs/tags/$HERDR_SOURCE_TAG")
tag_commit=$(git -C "$source_dir" rev-parse "refs/tags/$HERDR_SOURCE_TAG^{}")
head_commit=$(git -C "$source_dir" rev-parse HEAD)
if [ "$tag_object" != "$HERDR_SOURCE_TAG_OBJECT" ] ||
   [ "$tag_commit" != "$HERDR_SOURCE_COMMIT" ] ||
   [ "$head_commit" != "$HERDR_SOURCE_COMMIT" ]; then
  echo "Herdr source identity does not match the reviewed v0.7.4 pin" >&2
  exit 66
fi

if git -C "$source_dir" apply --check "$patch" 2>/dev/null; then
  git -C "$source_dir" apply "$patch"
elif ! git -C "$source_dir" apply --reverse --check "$patch" 2>/dev/null; then
  echo "Herdr source is neither the pinned base nor the exact reviewed patch" >&2
  exit 73
fi

actual_diff_sha=$(
  git -C "$source_dir" diff --binary --no-ext-diff |
    shasum -a 256 | awk '{print $1}'
)
if [ "$actual_diff_sha" != "$HERDR_PATCH_SHA256" ]; then
  echo "Herdr source has changes beyond the reviewed patch" >&2
  exit 73
fi
patched_source_sha=$(
  shasum -a 256 "$source_dir/src/app/input/copy_mode.rs" | awk '{print $1}'
)
if [ "$patched_source_sha" != "$HERDR_PATCHED_SOURCE_SHA256" ]; then
  if [ "$repin" -eq 1 ]; then
    repin_pin HERDR_PATCHED_SOURCE_SHA256 "$patched_source_sha"
    HERDR_PATCHED_SOURCE_SHA256=$patched_source_sha
  else
    echo "Herdr patched source SHA-256 mismatch" >&2
    exit 66
  fi
fi

zig=${ZIG:-}
if [ -z "$zig" ] && command -v brew >/dev/null 2>&1; then
  zig="$(brew --prefix zig@0.15 2>/dev/null)/bin/zig"
fi
if [ -z "$zig" ] || [ ! -x "$zig" ]; then
  echo "Herdr source build requires Zig $HERDR_ZIG_VERSION" >&2
  exit 69
fi
if [ "$("$zig" version)" != "$HERDR_ZIG_VERSION" ]; then
  echo "Herdr source build requires Zig $HERDR_ZIG_VERSION" >&2
  exit 69
fi

rust_version=$(cd "$source_dir" && rustc --version | awk '{print $2}')
if [ "$rust_version" != "$HERDR_RUST_TOOLCHAIN" ]; then
  echo "Herdr source build requires Rust $HERDR_RUST_TOOLCHAIN" >&2
  exit 69
fi

(
  cd "$source_dir"
  export CARGO_TARGET_DIR="$target_dir"
  export ZIG="$zig"
  export LIBGHOSTTY_VT_OPTIMIZE=ReleaseFast
  export LIBGHOSTTY_VT_SIMD=true
  cargo fmt --check
  cargo clippy --all-targets --locked -- -D warnings
  cargo test --locked copy_mode_
  cargo build --release --locked
)

built="$target_dir/release/herdr"
built_sha=$(shasum -a 256 "$built" | awk '{print $1}')
if [ "$built_sha" != "$HERDR_BINARY_SHA256" ]; then
  if [ "$repin" -eq 1 ]; then
    repin_pin HERDR_BINARY_SHA256 "$built_sha"
    HERDR_BINARY_SHA256=$built_sha
  else
    echo "Herdr patched binary SHA-256 mismatch" >&2
    echo "expected: $HERDR_BINARY_SHA256" >&2
    echo "actual:   $built_sha" >&2
    exit 66
  fi
fi
staged=$(mktemp "$output_dir/.herdr.XXXXXX")
install -m 0755 "$built" "$staged"
mv "$staged" "$output"

if [ "$install_build" -eq 1 ]; then
  official_sha=24992e1625dbdcb18354a59e299e4b263c312400b31396cdc07cd46ed57f24a7
  prototype_bin="$root/herdr/prototype/.runtime/bin/herdr"
  if [ -e "$prototype_bin" ]; then
    prototype_sha=$(shasum -a 256 "$prototype_bin" | awk '{print $1}')
    case "$prototype_sha" in
      "$HERDR_BINARY_SHA256"|"$official_sha") ;;
      *)
        echo "refusing to replace unrelated prototype Herdr binary" >&2
        exit 73
        ;;
    esac
  fi

  HERDR_INSTALL_SOURCE="$output" \
  HERDR_INSTALL_EXPECTED_SHA256="$HERDR_BINARY_SHA256" \
  HERDR_INSTALL_REPLACE_SHA256="$official_sha" \
  HERDR_ACTIVATE=0 \
    "$root/herdr/install.sh"

  mkdir -p "$(dirname -- "$prototype_bin")"
  if [ ! -e "$prototype_bin" ]; then
    staged_prototype=$(mktemp "$(dirname -- "$prototype_bin")/.herdr.XXXXXX")
    install -m 0755 "$output" "$staged_prototype"
    mv "$staged_prototype" "$prototype_bin"
  else
    prototype_sha=$(shasum -a 256 "$prototype_bin" | awk '{print $1}')
    if [ "$prototype_sha" != "$HERDR_BINARY_SHA256" ]; then
      case "$prototype_sha" in
        "$official_sha")
          staged_prototype=$(mktemp "$(dirname -- "$prototype_bin")/.herdr.XXXXXX")
          install -m 0755 "$output" "$staged_prototype"
          mv "$staged_prototype" "$prototype_bin"
          ;;
      esac
    fi
  fi
fi

printf 'Herdr source build: PASS (%s)\n' "$built_sha"
