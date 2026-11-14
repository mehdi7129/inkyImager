#!/bin/bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [[ "$(uname -s)" != Darwin || "$(uname -m)" != arm64 ]]; then
  echo "inkyImager requires an Apple Silicon Mac (Package.swift uses /opt/homebrew)." >&2
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
if [[ ! -f /opt/homebrew/opt/xz/include/lzma.h ]]; then
  if [[ ! -x /opt/homebrew/bin/brew ]]; then
    echo "Install Homebrew in /opt/homebrew, then run: brew install xz" >&2
    exit 1
  fi
  HOMEBREW_NO_AUTO_UPDATE=1 /opt/homebrew/bin/brew install xz
fi
if [[ ! -f /opt/homebrew/opt/xz/include/lzma.h ]]; then
  echo "Missing /opt/homebrew/opt/xz/include/lzma.h; check the Homebrew xz installation." >&2
  exit 1
fi

# SwiftPM validates the Swift tools version and resolves any package dependencies.
swift package resolve
echo "Workspace ready. Build with 'swift build' and test with 'swift test'."
