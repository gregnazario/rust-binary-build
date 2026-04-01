#!/bin/sh
# generate-install-ps1.sh — Generate a PowerShell install script.
#
# Required env vars:
#   BINARY_NAME - Name of the binary
#   REPO        - GitHub repository (owner/repo)
#   TARGETS     - JSON array of built targets
set -eu

: "${BINARY_NAME:?BINARY_NAME is required}"
: "${REPO:?REPO is required}"
: "${TARGETS:?TARGETS is required}"

# Detect which Windows targets are available
has_win_x86="false"
has_win_arm="false"
for target in $(echo "$TARGETS" | sed 's/\[//;s/\]//;s/"//g;s/,/ /g'); do
  case "$target" in
    x86_64-pc-windows-msvc) has_win_x86="true" ;;
    aarch64-pc-windows-msvc) has_win_arm="true" ;;
  esac
done

if [ "$has_win_x86" = "false" ] && [ "$has_win_arm" = "false" ]; then
  echo "# No Windows targets were built — this script is a no-op placeholder."
  exit 0
fi

cat << EOF
<#
.SYNOPSIS
    Install ${BINARY_NAME}

.DESCRIPTION
    Downloads and installs ${BINARY_NAME} from GitHub releases.

.PARAMETER Version
    Specific version to install (e.g. v1.0.0). Defaults to latest.

.PARAMETER Target
    Override auto-detected target triple.

.PARAMETER InstallDir
    Installation directory. Defaults to \$HOME\\.local\\bin

.EXAMPLE
    irm https://raw.githubusercontent.com/${REPO}/main/install.ps1 | iex
    .\\install.ps1 -Version v1.0.0
#>
[CmdletBinding()]
param(
    [string]\$Version = "",
    [string]\$Target = "",
    [string]\$InstallDir = "\$HOME\\.local\\bin"
)

\$ErrorActionPreference = "Stop"

\$BinaryName = "${BINARY_NAME}"
\$Repo = "${REPO}"

# Detect architecture
function Get-TargetTriple {
    \$arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    switch (\$arch) {
EOF

if [ "$has_win_x86" = "true" ]; then
  cat << 'EOF'
        "X64"   { return "x86_64-pc-windows-msvc" }
EOF
fi

if [ "$has_win_arm" = "true" ]; then
  cat << 'EOF'
        "Arm64" { return "aarch64-pc-windows-msvc" }
EOF
fi

cat << 'EOF'
        default { throw "Unsupported architecture: $arch" }
    }
}

# Resolve latest version from GitHub API
function Get-LatestVersion {
    $headers = @{ "User-Agent" = "install-script" }
    $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers $headers
    return $response.tag_name
}

# Main
try {
    if (-not $Version) {
        Write-Host "Fetching latest release..."
        $Version = Get-LatestVersion
        Write-Host "Latest version: $Version"
    }

    if (-not $Target) {
        $Target = Get-TargetTriple
        Write-Host "Detected target: $Target"
    }

    $archiveName = "$BinaryName-$Target-$Version.zip"
    $downloadUrl = "https://github.com/$Repo/releases/download/$Version/$archiveName"
    $checksumsUrl = "https://github.com/$Repo/releases/download/$Version/checksums-sha256.txt"

    # Create temp directory
    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

    try {
        # Download archive
        Write-Host "Downloading $archiveName..."
        $archivePath = Join-Path $tmpDir $archiveName
        Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath -UseBasicParsing

        # Download and verify checksum
        Write-Host "Verifying checksum..."
        $checksumsPath = Join-Path $tmpDir "checksums-sha256.txt"
        Invoke-WebRequest -Uri $checksumsUrl -OutFile $checksumsPath -UseBasicParsing

        $expectedLine = Get-Content $checksumsPath | Where-Object { $_ -match $archiveName }
        if ($expectedLine) {
            $expectedHash = ($expectedLine -split '\s+')[0]
            $actualHash = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash.ToLower()
            if ($actualHash -ne $expectedHash) {
                throw "Checksum mismatch!`n  Expected: $expectedHash`n  Actual:   $actualHash"
            }
            Write-Host "Checksum verified."
        } else {
            Write-Warning "No checksum found for $archiveName — skipping verification"
        }

        # Extract
        Write-Host "Extracting..."
        $extractDir = Join-Path $tmpDir "extracted"
        Expand-Archive -Path $archivePath -DestinationPath $extractDir

        # Install
        if (-not (Test-Path $InstallDir)) {
            New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        }

        $binaryFile = "$BinaryName.exe"
        $extractedBinary = Get-ChildItem -Path $extractDir -Recurse -Filter $binaryFile | Select-Object -First 1
        if (-not $extractedBinary) {
            throw "Binary $binaryFile not found in archive"
        }

        Copy-Item -Path $extractedBinary.FullName -Destination (Join-Path $InstallDir $binaryFile) -Force

        $installedPath = Join-Path $InstallDir $binaryFile
        Write-Host "Installed $BinaryName to $installedPath"

        # Print binary checksum
        $binHash = (Get-FileHash -Path $installedPath -Algorithm SHA256).Hash.ToLower()
        Write-Host "Binary SHA-256: $binHash"

        # Check PATH
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -notlike "*$InstallDir*") {
            Write-Host ""
            Write-Host "NOTE: $InstallDir is not in your PATH."
            Write-Host "  Run: [Environment]::SetEnvironmentVariable('Path', '$InstallDir;' + [Environment]::GetEnvironmentVariable('Path', 'User'), 'User')"
            Write-Host "  Then restart your terminal."
        } else {
            Write-Host "Done! Run '$BinaryName --help' to get started."
        }
    }
    finally {
        # Cleanup
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
EOF
