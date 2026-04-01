#!/bin/sh
# matrix.sh — Maps target keys (JSON array) to a GitHub Actions matrix include array.
# Usage: echo '["x86_64-unknown-linux-gnu","aarch64-apple-darwin"]' | sh matrix.sh
# Or:    TARGETS='["x86_64-unknown-linux-gnu"]' sh matrix.sh
set -eu

TARGETS="${TARGETS:-$(cat)}"

# Use a temp file so errors in the loop propagate (pipes swallow exit codes)
TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT

# Parse target list
target_list=$(echo "$TARGETS" | sed 's/\[//;s/\]//;s/"//g;s/,/ /g')

for target in $target_list; do
  [ -z "$target" ] && continue

  runner=""
  build_tool=""
  zigbuild_target=""
  rustflags=""
  rust_target=""
  archive_target=""

  case "$target" in
    x86_64-pc-windows-msvc)
      runner="windows-latest"
      build_tool="cargo"
      rust_target="x86_64-pc-windows-msvc"
      archive_target="$target"
      ;;
    aarch64-pc-windows-msvc)
      runner="windows-latest"
      build_tool="cargo"
      rust_target="aarch64-pc-windows-msvc"
      archive_target="$target"
      ;;
    aarch64-apple-darwin)
      runner="macos-latest"
      build_tool="cargo"
      rust_target="aarch64-apple-darwin"
      archive_target="$target"
      ;;
    x86_64-apple-darwin)
      runner="macos-latest"
      build_tool="cargo"
      rust_target="x86_64-apple-darwin"
      archive_target="$target"
      ;;
    x86_64-unknown-linux-gnu)
      runner="ubuntu-latest"
      build_tool="cargo-zigbuild"
      rust_target="x86_64-unknown-linux-gnu"
      zigbuild_target="x86_64-unknown-linux-gnu"
      archive_target="$target"
      ;;
    aarch64-unknown-linux-gnu)
      runner="ubuntu-latest"
      build_tool="cargo-zigbuild"
      rust_target="aarch64-unknown-linux-gnu"
      zigbuild_target="aarch64-unknown-linux-gnu"
      archive_target="$target"
      ;;
    x86_64-unknown-linux-musl)
      runner="ubuntu-latest"
      build_tool="cargo-zigbuild"
      rust_target="x86_64-unknown-linux-musl"
      zigbuild_target="x86_64-unknown-linux-musl"
      archive_target="$target"
      ;;
    aarch64-unknown-linux-musl)
      runner="ubuntu-latest"
      build_tool="cargo-zigbuild"
      rust_target="aarch64-unknown-linux-musl"
      zigbuild_target="aarch64-unknown-linux-musl"
      archive_target="$target"
      ;;
    x86_64-unknown-freebsd)
      runner="ubuntu-latest"
      build_tool="cross"
      rust_target="x86_64-unknown-freebsd"
      archive_target="$target"
      ;;
    x86_64-unknown-linux-gnu-glibc2.17)
      runner="ubuntu-latest"
      build_tool="cargo-zigbuild"
      rust_target="x86_64-unknown-linux-gnu"
      zigbuild_target="x86_64-unknown-linux-gnu.2.17"
      rustflags="-C target-cpu=x86-64"
      archive_target="x86_64-unknown-linux-gnu-glibc2.17"
      ;;
    aarch64-unknown-linux-gnu-glibc2.17)
      runner="ubuntu-latest"
      build_tool="cargo-zigbuild"
      rust_target="aarch64-unknown-linux-gnu"
      zigbuild_target="aarch64-unknown-linux-gnu.2.17"
      archive_target="aarch64-unknown-linux-gnu-glibc2.17"
      ;;
    *)
      echo "ERROR: Unknown target: $target" >&2
      exit 1
      ;;
  esac

  printf '{"target":"%s","rust-target":"%s","runner":"%s","build-tool":"%s","zigbuild-target":"%s","rustflags":"%s","archive-target":"%s"}\n' \
    "$target" "$rust_target" "$runner" "$build_tool" "$zigbuild_target" "$rustflags" "$archive_target" >> "$TMP_FILE"
done

# Assemble JSON array from temp file
first=true
printf '['
while IFS= read -r line; do
  if [ "$first" = true ]; then
    first=false
  else
    printf ','
  fi
  printf '%s' "$line"
done < "$TMP_FILE"
printf ']'
