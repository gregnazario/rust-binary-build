#!/bin/sh
# build.sh — Build a Rust binary for a single target.
#
# Required env vars:
#   BINARY_NAME       - Name of the binary to build
#   BUILD_TOOL        - One of: cargo, cargo-zigbuild, cross
#   RUST_TARGET       - Rust target triple (e.g. x86_64-unknown-linux-gnu)
#   PROFILE           - Cargo profile (release, dev, etc.)
#
# Optional env vars:
#   PACKAGE_NAME      - Cargo package name if different from BINARY_NAME
#   ZIGBUILD_TARGET   - Target for cargo-zigbuild (may include .2.17 suffix)
#   RUSTFLAGS_EXTRA   - Additional RUSTFLAGS (appended to existing)
#   FEATURES          - Comma-separated features
#   ALL_FEATURES      - Set to "true" to enable --all-features
#   NO_DEFAULT_FEATURES - Set to "true" to enable --no-default-features
#   EXTRA_BUILD_ARGS  - Additional cargo build arguments
#   MANIFEST_PATH     - Path to Cargo.toml (default: Cargo.toml)
set -eu

: "${BINARY_NAME:?BINARY_NAME is required}"
: "${BUILD_TOOL:?BUILD_TOOL is required}"
: "${RUST_TARGET:?RUST_TARGET is required}"
: "${PROFILE:=release}"
: "${PACKAGE_NAME:=$BINARY_NAME}"
: "${ZIGBUILD_TARGET:=$RUST_TARGET}"
: "${RUSTFLAGS_EXTRA:=}"
: "${FEATURES:=}"
: "${ALL_FEATURES:=false}"
: "${NO_DEFAULT_FEATURES:=false}"
: "${EXTRA_BUILD_ARGS:=}"
: "${MANIFEST_PATH:=Cargo.toml}"

# Append extra rustflags if provided
if [ -n "$RUSTFLAGS_EXTRA" ]; then
  export RUSTFLAGS="${RUSTFLAGS:-} $RUSTFLAGS_EXTRA"
fi

# Build common args
build_args="--profile $PROFILE --target"

case "$BUILD_TOOL" in
  cargo-zigbuild)
    build_args="$build_args $ZIGBUILD_TARGET"
    ;;
  *)
    build_args="$build_args $RUST_TARGET"
    ;;
esac

build_args="$build_args --package $PACKAGE_NAME"

if [ -n "$FEATURES" ]; then
  build_args="$build_args --features $FEATURES"
fi

if [ "$ALL_FEATURES" = "true" ]; then
  build_args="$build_args --all-features"
fi

if [ "$NO_DEFAULT_FEATURES" = "true" ]; then
  build_args="$build_args --no-default-features"
fi

if [ "$MANIFEST_PATH" != "Cargo.toml" ]; then
  build_args="$build_args --manifest-path $MANIFEST_PATH"
fi

if [ -n "$EXTRA_BUILD_ARGS" ]; then
  build_args="$build_args $EXTRA_BUILD_ARGS"
fi

echo "::group::Building $BINARY_NAME for $RUST_TARGET via $BUILD_TOOL"
echo "Command: $BUILD_TOOL build $build_args"

case "$BUILD_TOOL" in
  cargo)
    # shellcheck disable=SC2086
    cargo build $build_args
    ;;
  cargo-zigbuild)
    # shellcheck disable=SC2086
    cargo zigbuild $build_args
    ;;
  cross)
    # shellcheck disable=SC2086
    cross build $build_args
    ;;
  *)
    echo "Unknown build tool: $BUILD_TOOL" >&2
    exit 1
    ;;
esac

echo "::endgroup::"

# Determine binary path
# When --manifest-path is used, cargo outputs to <manifest-dir>/target/ unless CARGO_TARGET_DIR is set
if [ -z "${CARGO_TARGET_DIR:-}" ]; then
  if [ "$MANIFEST_PATH" != "Cargo.toml" ]; then
    MANIFEST_DIR=$(dirname "$MANIFEST_PATH")
    CARGO_TARGET_DIR="$MANIFEST_DIR/target"
  else
    CARGO_TARGET_DIR="target"
  fi
fi
PROFILE_DIR="$PROFILE"
if [ "$PROFILE" = "dev" ]; then
  PROFILE_DIR="debug"
fi

case "$RUST_TARGET" in
  *-windows-*)
    binary_path="$CARGO_TARGET_DIR/$RUST_TARGET/$PROFILE_DIR/$BINARY_NAME.exe"
    ;;
  *)
    binary_path="$CARGO_TARGET_DIR/$RUST_TARGET/$PROFILE_DIR/$BINARY_NAME"
    ;;
esac

if [ ! -f "$binary_path" ]; then
  echo "ERROR: Binary not found at $binary_path" >&2
  exit 1
fi

echo "Built: $binary_path"
echo "binary-path=$binary_path" >> "${GITHUB_OUTPUT:-/dev/null}"
