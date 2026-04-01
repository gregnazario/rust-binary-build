#!/bin/sh
# generate-install-sh.sh — Generate a POSIX install script from the template.
#
# Required env vars:
#   BINARY_NAME - Name of the binary
#   REPO        - GitHub repository (owner/repo)
#   TARGETS     - JSON array of built targets
set -eu

: "${BINARY_NAME:?BINARY_NAME is required}"
: "${REPO:?REPO is required}"
: "${TARGETS:?TARGETS is required}"

# Build the target mapping case block from the built targets
# We parse the JSON array and generate case patterns for platform detection
build_target_map() {
  # Parse available targets to determine which platforms are available
  has_linux_gnu_x86="false"
  has_linux_gnu_arm="false"
  has_linux_musl_x86="false"
  has_linux_musl_arm="false"
  has_linux_gnu_x86_compat="false"
  has_linux_gnu_arm_compat="false"
  has_darwin_arm="false"
  has_darwin_x86="false"
  has_freebsd_x86="false"

  for target in $(echo "$TARGETS" | sed 's/\[//;s/\]//;s/"//g;s/,/ /g'); do
    case "$target" in
      x86_64-unknown-linux-gnu) has_linux_gnu_x86="true" ;;
      aarch64-unknown-linux-gnu) has_linux_gnu_arm="true" ;;
      x86_64-unknown-linux-musl) has_linux_musl_x86="true" ;;
      aarch64-unknown-linux-musl) has_linux_musl_arm="true" ;;
      x86_64-unknown-linux-gnu-glibc2.17) has_linux_gnu_x86_compat="true" ;;
      aarch64-unknown-linux-gnu-glibc2.17) has_linux_gnu_arm_compat="true" ;;
      aarch64-apple-darwin) has_darwin_arm="true" ;;
      x86_64-apple-darwin) has_darwin_x86="true" ;;
      x86_64-unknown-freebsd) has_freebsd_x86="true" ;;
    esac
  done

  # Generate the resolve_target function body
  # Priority: if musl available on Linux and musl detected, use musl; else use gnu
  cat << 'RESOLVE_START'
resolve_target() {
  _os="$1"
  _arch="$2"
  _libc="$3"

  case "$_os" in
RESOLVE_START

  # Darwin cases
  if [ "$has_darwin_arm" = "true" ]; then
    echo '    Darwin)'
    echo '      case "$_arch" in'
    echo "        aarch64) echo \"aarch64-apple-darwin\" ;;"
    if [ "$has_darwin_x86" = "true" ]; then
      echo "        x86_64) echo \"x86_64-apple-darwin\" ;;"
    fi
    echo '        *) echo ""; return 1 ;;'
    echo '      esac'
    echo '      ;;'
  elif [ "$has_darwin_x86" = "true" ]; then
    echo '    Darwin)'
    echo '      case "$_arch" in'
    echo "        x86_64) echo \"x86_64-apple-darwin\" ;;"
    echo '        *) echo ""; return 1 ;;'
    echo '      esac'
    echo '      ;;'
  fi

  # Linux cases
  if [ "$has_linux_gnu_x86" = "true" ] || [ "$has_linux_musl_x86" = "true" ] || \
     [ "$has_linux_gnu_arm" = "true" ] || [ "$has_linux_musl_arm" = "true" ] || \
     [ "$has_linux_gnu_x86_compat" = "true" ] || [ "$has_linux_gnu_arm_compat" = "true" ]; then
    echo '    Linux)'
    echo '      case "$_arch" in'

    # x86_64 Linux
    if [ "$has_linux_musl_x86" = "true" ] || [ "$has_linux_gnu_x86" = "true" ] || [ "$has_linux_gnu_x86_compat" = "true" ]; then
      echo '        x86_64)'
      echo '          case "$_libc" in'
      if [ "$has_linux_musl_x86" = "true" ]; then
        echo "            musl) echo \"x86_64-unknown-linux-musl\" ;;"
      fi
      if [ "$has_linux_gnu_x86" = "true" ]; then
        echo "            *) echo \"x86_64-unknown-linux-gnu\" ;;"
      elif [ "$has_linux_gnu_x86_compat" = "true" ]; then
        echo "            *) echo \"x86_64-unknown-linux-gnu-glibc2.17\" ;;"
      elif [ "$has_linux_musl_x86" = "true" ]; then
        echo "            *) echo \"x86_64-unknown-linux-musl\" ;;"
      fi
      echo '          esac'
      echo '          ;;'
    fi

    # aarch64 Linux
    if [ "$has_linux_musl_arm" = "true" ] || [ "$has_linux_gnu_arm" = "true" ] || [ "$has_linux_gnu_arm_compat" = "true" ]; then
      echo '        aarch64)'
      echo '          case "$_libc" in'
      if [ "$has_linux_musl_arm" = "true" ]; then
        echo "            musl) echo \"aarch64-unknown-linux-musl\" ;;"
      fi
      if [ "$has_linux_gnu_arm" = "true" ]; then
        echo "            *) echo \"aarch64-unknown-linux-gnu\" ;;"
      elif [ "$has_linux_gnu_arm_compat" = "true" ]; then
        echo "            *) echo \"aarch64-unknown-linux-gnu-glibc2.17\" ;;"
      elif [ "$has_linux_musl_arm" = "true" ]; then
        echo "            *) echo \"aarch64-unknown-linux-musl\" ;;"
      fi
      echo '          esac'
      echo '          ;;'
    fi

    echo '        *) echo ""; return 1 ;;'
    echo '      esac'
    echo '      ;;'
  fi

  # FreeBSD cases
  if [ "$has_freebsd_x86" = "true" ]; then
    echo '    FreeBSD)'
    echo '      case "$_arch" in'
    echo "        x86_64) echo \"x86_64-unknown-freebsd\" ;;"
    echo '        *) echo ""; return 1 ;;'
    echo '      esac'
    echo '      ;;'
  fi

  cat << 'RESOLVE_END'
    *)
      echo ""
      return 1
      ;;
  esac
}
RESOLVE_END
}

# Generate the full install script
cat << 'HEADER'
#!/bin/sh
# Auto-generated install script
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/main/install.sh | sh
#   curl -fsSL .../install.sh | sh -s -- --version v1.0.0
#   curl -fsSL .../install.sh | sh -s -- --target x86_64-unknown-linux-musl
#   curl -fsSL .../install.sh | sh -s -- --install-dir /usr/local/bin
set -eu

HEADER

cat << EOF
BINARY_NAME="$BINARY_NAME"
REPO="$REPO"
EOF

cat << 'BODY'

VERSION=""
TARGET=""
INSTALL_DIR="${HOME}/.local/bin"

usage() {
  cat << USAGE_EOF
Install ${BINARY_NAME}

Usage:
  install.sh [OPTIONS]

Options:
  --version VERSION    Install a specific version (e.g. v1.0.0)
  --target TARGET      Override auto-detected target triple
  --install-dir DIR    Installation directory (default: ~/.local/bin)
  -h, --help           Show this help message
USAGE_EOF
}

# Parse arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --target)
      TARGET="$2"
      shift 2
      ;;
    --install-dir)
      INSTALL_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# Check for required tools
check_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    return 1
  fi
}

DOWNLOADER=""
if check_cmd curl; then
  DOWNLOADER="curl"
elif check_cmd wget; then
  DOWNLOADER="wget"
else
  echo "ERROR: curl or wget is required but neither was found." >&2
  echo "Install with your package manager:" >&2
  echo "  apt-get install curl    # Debian/Ubuntu" >&2
  echo "  dnf install curl        # Fedora/RHEL" >&2
  echo "  pacman -S curl          # Arch" >&2
  echo "  apk add curl            # Alpine" >&2
  echo "  brew install curl       # macOS" >&2
  exit 1
fi

if ! check_cmd tar; then
  echo "ERROR: tar is required but was not found." >&2
  exit 1
fi

# Download helper
download() {
  _url="$1"
  _output="$2"
  if [ "$DOWNLOADER" = "curl" ]; then
    curl -fsSL -o "$_output" "$_url"
  else
    wget -q -O "$_output" "$_url"
  fi
}

# Download to stdout
download_stdout() {
  _url="$1"
  if [ "$DOWNLOADER" = "curl" ]; then
    curl -fsSL "$_url"
  else
    wget -q -O - "$_url"
  fi
}

# Detect platform
detect_os() {
  _uname_s=$(uname -s)
  case "$_uname_s" in
    Linux*)  echo "Linux" ;;
    Darwin*) echo "Darwin" ;;
    FreeBSD*) echo "FreeBSD" ;;
    *)
      echo "ERROR: Unsupported OS: $_uname_s" >&2
      exit 1
      ;;
  esac
}

detect_arch() {
  _uname_m=$(uname -m)
  case "$_uname_m" in
    x86_64|amd64)  echo "x86_64" ;;
    aarch64|arm64)  echo "aarch64" ;;
    *)
      echo "ERROR: Unsupported architecture: $_uname_m" >&2
      exit 1
      ;;
  esac
}

detect_libc() {
  # Check for musl
  if [ -f /etc/alpine-release ]; then
    echo "musl"
    return
  fi
  if command -v ldd >/dev/null 2>&1; then
    _ldd_version=$(ldd --version 2>&1 || true)
    case "$_ldd_version" in
      *musl*) echo "musl"; return ;;
    esac
  fi
  # Check for musl dynamic linker
  # shellcheck disable=SC2039
  for _f in /lib/ld-musl-*; do
    if [ -e "$_f" ]; then
      echo "musl"
      return
    fi
  done
  echo "gnu"
}

BODY

# Insert the dynamically generated target resolver
build_target_map

cat << 'FOOTER'

# Resolve latest version if not specified
if [ -z "$VERSION" ]; then
  echo "Fetching latest release..."
  _api_url="https://api.github.com/repos/${REPO}/releases/latest"
  _response=$(download_stdout "$_api_url")
  VERSION=$(echo "$_response" | grep '"tag_name"' | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  if [ -z "$VERSION" ]; then
    echo "ERROR: Could not determine latest version" >&2
    exit 1
  fi
  echo "Latest version: $VERSION"
fi

# Detect target if not overridden
if [ -z "$TARGET" ]; then
  OS=$(detect_os)
  ARCH=$(detect_arch)
  LIBC="gnu"
  if [ "$OS" = "Linux" ]; then
    LIBC=$(detect_libc)
  fi
  TARGET=$(resolve_target "$OS" "$ARCH" "$LIBC")
  if [ -z "$TARGET" ]; then
    echo "ERROR: No pre-built binary available for $OS $ARCH ($LIBC)" >&2
    exit 1
  fi
  echo "Detected target: $TARGET"
fi

# Determine archive name and URL
ARCHIVE_NAME="${BINARY_NAME}-${TARGET}-${VERSION}.tar.gz"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${ARCHIVE_NAME}"
CHECKSUMS_URL="https://github.com/${REPO}/releases/download/${VERSION}/checksums-sha256.txt"

# Create temp directory with cleanup trap
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Download archive
echo "Downloading ${ARCHIVE_NAME}..."
download "$DOWNLOAD_URL" "$TMP_DIR/$ARCHIVE_NAME"

# Verify checksum
echo "Verifying checksum..."
download "$CHECKSUMS_URL" "$TMP_DIR/checksums-sha256.txt"

EXPECTED_HASH=$(grep "$ARCHIVE_NAME" "$TMP_DIR/checksums-sha256.txt" | cut -d' ' -f1)
if [ -z "$EXPECTED_HASH" ]; then
  echo "WARNING: No checksum found for $ARCHIVE_NAME — skipping verification" >&2
else
  if command -v sha256sum >/dev/null 2>&1; then
    ACTUAL_HASH=$(sha256sum "$TMP_DIR/$ARCHIVE_NAME" | cut -d' ' -f1)
  elif command -v shasum >/dev/null 2>&1; then
    ACTUAL_HASH=$(shasum -a 256 "$TMP_DIR/$ARCHIVE_NAME" | cut -d' ' -f1)
  else
    echo "WARNING: sha256sum/shasum not found — skipping verification" >&2
    ACTUAL_HASH=""
  fi

  if [ -n "$ACTUAL_HASH" ] && [ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]; then
    echo "ERROR: Checksum mismatch!" >&2
    echo "  Expected: $EXPECTED_HASH" >&2
    echo "  Actual:   $ACTUAL_HASH" >&2
    exit 1
  fi
  echo "Checksum verified."
fi

# Extract
echo "Extracting..."
tar xzf "$TMP_DIR/$ARCHIVE_NAME" -C "$TMP_DIR"

# Install
mkdir -p "$INSTALL_DIR"
# Find the binary inside the extracted directory
_extract_dir="$TMP_DIR/${BINARY_NAME}-${TARGET}-${VERSION}"
if [ -d "$_extract_dir" ]; then
  cp "$_extract_dir/$BINARY_NAME" "$INSTALL_DIR/"
else
  # Fallback: binary might be at top level
  cp "$TMP_DIR/$BINARY_NAME" "$INSTALL_DIR/"
fi
chmod +x "$INSTALL_DIR/$BINARY_NAME"

echo "Installed $BINARY_NAME to $INSTALL_DIR/$BINARY_NAME"

# Print binary checksum for audit
if command -v sha256sum >/dev/null 2>&1; then
  echo "Binary SHA-256: $(sha256sum "$INSTALL_DIR/$BINARY_NAME" | cut -d' ' -f1)"
elif command -v shasum >/dev/null 2>&1; then
  echo "Binary SHA-256: $(shasum -a 256 "$INSTALL_DIR/$BINARY_NAME" | cut -d' ' -f1)"
fi

# Check if install dir is in PATH
case ":${PATH}:" in
  *":${INSTALL_DIR}:"*)
    echo "Done! Run '$BINARY_NAME --help' to get started."
    ;;
  *)
    echo ""
    echo "NOTE: $INSTALL_DIR is not in your PATH."
    _shell_name=$(basename "${SHELL:-/bin/sh}")
    case "$_shell_name" in
      zsh)  echo "  Add to ~/.zshrc:    export PATH=\"$INSTALL_DIR:\$PATH\"" ;;
      bash) echo "  Add to ~/.bashrc:   export PATH=\"$INSTALL_DIR:\$PATH\"" ;;
      fish) echo "  Run: fish_add_path $INSTALL_DIR" ;;
      *)    echo "  Add to ~/.profile:  export PATH=\"$INSTALL_DIR:\$PATH\"" ;;
    esac
    echo "  Then restart your shell or run: export PATH=\"$INSTALL_DIR:\$PATH\""
    ;;
esac
FOOTER
