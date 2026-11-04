#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-Debug}"
mkdir -p .build/tmp

# The DSH workspace sandbox blocks nested sandbox-exec, which breaks Swift
# macro expansion. Only disable the compiler sandbox in that environment.
XCODE_ARGS=(
  -project Lumen.xcodeproj
  -scheme Lumen
  -configuration "$CONFIG"
  -derivedDataPath build
)
if [[ "${DSH_SHELL:-0}" == "1" ]]; then
  XCODE_ARGS+=(OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox')
fi

TMPDIR="$PWD/.build/tmp" xcodebuild "${XCODE_ARGS[@]}" build

echo
echo "Built: $PWD/build/Build/Products/$CONFIG/Lumen.app"
