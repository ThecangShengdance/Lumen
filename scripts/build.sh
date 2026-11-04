#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-Debug}"
mkdir -p .build/tmp

# The DSH workspace sandbox blocks nested sandbox-exec, which breaks Swift
# macro expansion. Only disable the compiler sandbox in that environment.
EXTRA_FLAGS=()
if [[ "${DSH_SHELL:-0}" == "1" ]]; then
  EXTRA_FLAGS+=(OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox')
fi

TMPDIR="$PWD/.build/tmp" xcodebuild \
  -project Lumen.xcodeproj \
  -scheme Lumen \
  -configuration "$CONFIG" \
  -derivedDataPath build \
  "${EXTRA_FLAGS[@]}" \
  build

echo
echo "Built: $PWD/build/Build/Products/$CONFIG/Lumen.app"
