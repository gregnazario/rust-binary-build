#!/bin/sh
# archive.sh — Package a built binary into an archive with SHA-256 checksum.
#
# Required env vars:
#   BINARY_NAME     - Name of the binary
#   BINARY_PATH     - Path to the compiled binary
#   ARCHIVE_TARGET  - Target identifier for archive naming (e.g. x86_64-unknown-linux-gnu-glibc2.17)
#   VERSION         - Release version (e.g. v1.0.0)
#
# Optional env vars:
#   ARCHIVE_NAME_TEMPLATE - Template: {name}-{target}-{version} (default)
#   INCLUDE_FILES         - Space-separated globs of extra files to include (default: "LICENSE* README*")
#   STAGING_DIR           - Directory for staging archive contents (default: auto-created)
#   OUTPUT_DIR            - Directory for final archives (default: dist/)
set -eu

: "${BINARY_NAME:?BINARY_NAME is required}"
: "${BINARY_PATH:?BINARY_PATH is required}"
: "${ARCHIVE_TARGET:?ARCHIVE_TARGET is required}"
: "${VERSION:?VERSION is required}"
if [ -z "${ARCHIVE_NAME_TEMPLATE:-}" ]; then
  ARCHIVE_NAME_TEMPLATE='{name}-{target}-{version}'
fi
: "${INCLUDE_FILES:=LICENSE* README*}"
: "${OUTPUT_DIR:=dist}"

# Resolve archive name from template
archive_base=$(echo "$ARCHIVE_NAME_TEMPLATE" | \
  sed "s/{name}/$BINARY_NAME/g" | \
  sed "s/{target}/$ARCHIVE_TARGET/g" | \
  sed "s/{version}/$VERSION/g")

# Detect Windows target for zip vs tar.gz
case "$ARCHIVE_TARGET" in
  *-windows-*)
    archive_name="${archive_base}.zip"
    ;;
  *)
    archive_name="${archive_base}.tar.gz"
    ;;
esac

mkdir -p "$OUTPUT_DIR"
# Resolve to absolute path so it works from any working directory
OUTPUT_DIR=$(cd "$OUTPUT_DIR" && pwd)

# Create staging directory
staging_dir=$(mktemp -d)
staging_inner="$staging_dir/$archive_base"
mkdir -p "$staging_inner"
trap 'rm -rf "$staging_dir"' EXIT

echo "::group::Packaging $archive_name"

# Copy binary
cp "$BINARY_PATH" "$staging_inner/"

# Copy included files (glob expansion, ignore missing)
if [ -n "$INCLUDE_FILES" ]; then
  for pattern in $INCLUDE_FILES; do
    # shellcheck disable=SC2086
    for file in $pattern; do
      if [ -f "$file" ]; then
        cp "$file" "$staging_inner/"
      fi
    done
  done
fi

echo "Archive contents:"
ls -la "$staging_inner/"

# Create archive
case "$ARCHIVE_TARGET" in
  *-windows-*)
    # On Windows runners, use PowerShell; on Linux (cross-compile), use 7z or zip
    if command -v pwsh >/dev/null 2>&1; then
      pwsh -NoProfile -Command "Compress-Archive -Path '$staging_inner/*' -DestinationPath '$OUTPUT_DIR/$archive_name'"
    elif command -v 7z >/dev/null 2>&1; then
      (cd "$staging_dir" && 7z a -tzip "$OUTPUT_DIR/$archive_name" "$archive_base/")
    elif command -v zip >/dev/null 2>&1; then
      (cd "$staging_dir" && zip -r "$OUTPUT_DIR/$archive_name" "$archive_base/")
    else
      echo "ERROR: No zip tool available (need pwsh, 7z, or zip)" >&2
      exit 1
    fi
    ;;
  *)
    (cd "$staging_dir" && tar czf "$OUTPUT_DIR/$archive_name" "$archive_base/")
    ;;
esac

# Generate SHA-256 checksum
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$OUTPUT_DIR" && sha256sum "$archive_name" > "${archive_name}.sha256")
elif command -v shasum >/dev/null 2>&1; then
  (cd "$OUTPUT_DIR" && shasum -a 256 "$archive_name" > "${archive_name}.sha256")
else
  echo "ERROR: No sha256sum or shasum available" >&2
  exit 1
fi

echo "::endgroup::"

echo "Archive: $OUTPUT_DIR/$archive_name"
echo "Checksum: $OUTPUT_DIR/${archive_name}.sha256"
cat "$OUTPUT_DIR/${archive_name}.sha256"

# Output for GitHub Actions
{
  echo "archive-path=$OUTPUT_DIR/$archive_name"
  echo "archive-name=$archive_name"
  echo "checksum-path=$OUTPUT_DIR/${archive_name}.sha256"
} >> "${GITHUB_OUTPUT:-/dev/null}"
