# rust-binary-build

Reusable GitHub Actions workflow for building, releasing, and distributing Rust binaries across 11 platforms with package manager publishing.

## Features

- **11 platform targets** — Windows, macOS, Linux (gnu/musl), FreeBSD, older glibc
- **cargo-binstall compatible** — archives auto-discovered by `cargo binstall`
- **Auto-download scripts** — dynamically generated `install.sh` (POSIX) and `install.ps1` (PowerShell)
- **SHA-256 checksums** — per-archive and combined checksums file
- **Package manager publishing** — Homebrew, Scoop, WinGet, Chocolatey, AUR, apt, RPM, Alpine, Pacman, Gentoo, mise/asdf
- **Pre/post build hooks** — run custom scripts before or after compilation
- **Tag-based releases** — automatic pre-release detection from tag format

## Quick Start

Create `.github/workflows/release.yml` in your Rust project:

```yaml
name: Release
on:
  push:
    tags: ['v[0-9]*.[0-9]*.[0-9]*']

jobs:
  build-and-release:
    uses: OWNER/rust-binary-build/.github/workflows/build.yml@v1
    with:
      binary-name: my-tool
      targets: '["x86_64-unknown-linux-gnu", "aarch64-apple-darwin", "x86_64-pc-windows-msvc"]'
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}
```

Then tag and push:

```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

## Available Targets

| Key | Platform | Runner | Build Tool |
|-----|----------|--------|------------|
| `x86_64-pc-windows-msvc` | Windows x86_64 | windows-latest | cargo |
| `aarch64-pc-windows-msvc` | Windows ARM64 | windows-latest | cargo |
| `aarch64-apple-darwin` | macOS ARM (Apple Silicon) | macos-latest | cargo |
| `x86_64-apple-darwin` | macOS x86_64 | macos-latest | cargo |
| `x86_64-unknown-linux-gnu` | Linux x86_64 (glibc) | ubuntu-latest | cargo-zigbuild |
| `aarch64-unknown-linux-gnu` | Linux ARM64 (glibc) | ubuntu-latest | cargo-zigbuild |
| `x86_64-unknown-linux-musl` | Linux x86_64 (static) | ubuntu-latest | cargo-zigbuild |
| `aarch64-unknown-linux-musl` | Linux ARM64 (static) | ubuntu-latest | cargo-zigbuild |
| `x86_64-unknown-freebsd` | FreeBSD x86_64 | ubuntu-latest | cross |
| `x86_64-unknown-linux-gnu-glibc2.17` | Linux x86_64 (old glibc, baseline ISA) | ubuntu-latest | cargo-zigbuild |
| `aarch64-unknown-linux-gnu-glibc2.17` | Linux ARM64 (old glibc) | ubuntu-latest | cargo-zigbuild |

## Workflow Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `binary-name` | string | **required** | Name of the binary to build |
| `package-name` | string | `binary-name` | Cargo package name if different |
| `targets` | string | **required** | JSON array of target keys |
| `rust-toolchain` | string | `stable` | Rust toolchain version |
| `profile` | string | `release` | Cargo build profile |
| `features` | string | `""` | Comma-separated features |
| `all-features` | boolean | `false` | Enable `--all-features` |
| `no-default-features` | boolean | `false` | Enable `--no-default-features` |
| `extra-build-args` | string | `""` | Additional cargo arguments |
| `manifest-path` | string | `Cargo.toml` | Path to Cargo.toml |
| `include-files` | string | `LICENSE* README*` | Files to include in archives |
| `archive-name-template` | string | `{name}-{target}-{version}` | Archive naming template |
| `tag` | string | `github.ref_name` | Release tag |
| `draft` | boolean | `false` | Create draft release |
| `generate-install-sh` | boolean | `true` | Generate POSIX install script |
| `generate-install-ps1` | boolean | `true` | Generate PowerShell install script |
| `pre-build-script` | string | `""` | Script to run before build |
| `post-build-script` | string | `""` | Script to run after build |

## Workflow Outputs

| Output | Description |
|--------|-------------|
| `version` | Released version (without `v` prefix) |
| `tag` | Release tag |
| `is-prerelease` | Whether this is a pre-release |
| `release-url` | URL of the GitHub Release |

## Install Scripts

The workflow automatically generates install scripts and uploads them to each release.

### Unix (Linux / macOS)

```bash
# Install latest
curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/main/install.sh | sh

# Install specific version
curl -fsSL .../install.sh | sh -s -- --version v1.0.0

# Install to custom directory
curl -fsSL .../install.sh | sh -s -- --install-dir /usr/local/bin

# Force specific target
curl -fsSL .../install.sh | sh -s -- --target x86_64-unknown-linux-musl
```

### Windows (PowerShell)

```powershell
# Install latest
irm https://raw.githubusercontent.com/OWNER/REPO/main/install.ps1 | iex

# Install specific version
.\install.ps1 -Version v1.0.0
```

## cargo binstall

Archives follow the binstall naming convention automatically. Users can install with:

```bash
cargo binstall my-tool
```

No additional `Cargo.toml` metadata is required.

## Package Manager Publishing

Each package manager has its own reusable workflow. Wire them after the build:

```yaml
jobs:
  build:
    uses: OWNER/rust-binary-build/.github/workflows/build.yml@v1
    with:
      binary-name: my-tool
      targets: '["x86_64-unknown-linux-gnu", "aarch64-apple-darwin", "x86_64-pc-windows-msvc"]'
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}

  publish-brew:
    needs: build
    uses: OWNER/rust-binary-build/.github/workflows/publish-brew.yml@v1
    with:
      binary-name: my-tool
      tag: ${{ needs.build.outputs.tag }}
      tap-repo: OWNER/homebrew-tap
    secrets:
      tap-token: ${{ secrets.BREW_TAP_TOKEN }}

  publish-scoop:
    needs: build
    uses: OWNER/rust-binary-build/.github/workflows/publish-scoop.yml@v1
    with:
      binary-name: my-tool
      tag: ${{ needs.build.outputs.tag }}
      bucket-repo: OWNER/scoop-bucket
    secrets:
      bucket-token: ${{ secrets.SCOOP_BUCKET_TOKEN }}
```

### Available Publish Workflows

| Workflow | Package Manager | Key Secrets |
|----------|----------------|-------------|
| `publish-brew.yml` | Homebrew | `tap-token` |
| `publish-scoop.yml` | Scoop | `bucket-token` |
| `publish-winget.yml` | WinGet | `winget-token` |
| `publish-choco.yml` | Chocolatey | `choco-api-key` |
| `publish-aur.yml` | AUR | `aur-ssh-key` |
| `publish-apt.yml` | apt (.deb) | `github-token` |
| `publish-rpm.yml` | dnf/zypper (RPM) | `github-token` |
| `publish-apk.yml` | apk (Alpine) | `github-token` |
| `publish-pacman.yml` | pacman (Arch) | `github-token` |
| `publish-emerge.yml` | emerge (Gentoo) | `overlay-token` |
| `publish-mise-asdf.yml` | mise / asdf | `plugin-token` |

## Pre-release Detection

Tags containing a `-` are treated as pre-releases:

- `v1.0.0` → stable release
- `v1.0.0-beta.1` → pre-release
- `v1.0.0-rc1` → pre-release

## Older glibc Targets

Targets `x86_64-unknown-linux-gnu-glibc2.17` and `aarch64-unknown-linux-gnu-glibc2.17` link against glibc 2.17 (RHEL 7 / CentOS 7 era), making binaries compatible with older systems and Docker containers running on macOS.

The x86_64 glibc2.17 target also sets `RUSTFLAGS="-C target-cpu=x86-64"` to use only baseline SSE2 instructions, avoiding SIGILL under Rosetta/QEMU emulation.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Caller Workflow                       │
│  on: push: tags: ['v*']                                 │
└─────────┬───────────────────────────┬───────────────────┘
          │                           │
          ▼                           ▼
┌─────────────────────┐   ┌──────────────────────────┐
│   build.yml         │   │  publish-brew.yml         │
│  ┌───────────────┐  │   │  publish-scoop.yml        │
│  │ prepare       │  │   │  publish-aur.yml          │
│  │ (matrix gen)  │  │   │  publish-apt.yml          │
│  └───────┬───────┘  │   │  publish-rpm.yml          │
│          │          │   │  publish-apk.yml          │
│  ┌───────▼───────┐  │   │  publish-pacman.yml       │
│  │ build (matrix)│  │   │  publish-emerge.yml       │
│  │ 11 targets    │  │   │  publish-choco.yml        │
│  └───────┬───────┘  │   │  publish-winget.yml       │
│          │          │   │  publish-mise-asdf.yml     │
│  ┌───────▼───────┐  │   └──────────────────────────┘
│  │ release       │  │
│  │ (GH Release)  │  │
│  └───────────────┘  │
└─────────────────────┘
```

## License

MIT
