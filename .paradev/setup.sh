#!/bin/bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [[ "$(uname -s)" != Darwin ]]; then
  echo "inkyImager requires macOS 14 or newer (Apple Silicon or Intel)." >&2
  exit 1
fi

if ! xcrun --find swift >/dev/null 2>&1 || ! xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1; then
  echo "Install Xcode with Swift 6 or newer and select it with xcode-select." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Install Python 3.9 or newer for the packaging and maintenance scripts." >&2
  exit 1
fi
python3 -c 'import sys; sys.exit("Python 3.9 or newer is required.") if sys.version_info < (3, 9) else None'

# CXZ links against macOS liblzma, but needs these Homebrew headers to compile.
if [[ -n "${INKY_XZ_INCLUDE:-}" ]]; then
  if [[ ! -f "$INKY_XZ_INCLUDE/lzma.h" ]]; then
    echo "INKY_XZ_INCLUDE must contain lzma.h." >&2
    exit 1
  fi
elif [[ ! -f /opt/homebrew/opt/xz/include/lzma.h && ! -f /usr/local/opt/xz/include/lzma.h ]]; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "Install Homebrew, then run: brew install xz" >&2
    exit 1
  fi
  HOMEBREW_NO_AUTO_UPDATE=1 brew install xz
  if [[ ! -f /opt/homebrew/opt/xz/include/lzma.h && ! -f /usr/local/opt/xz/include/lzma.h ]]; then
    echo "Set INKY_XZ_INCLUDE to the xz include directory for a custom Homebrew prefix." >&2
    exit 1
  fi
fi

# SwiftPM validates the Swift tools version and resolves any package dependencies.
swift package resolve
echo "Workspace ready. Build with 'swift build' and test with 'swift test'."
