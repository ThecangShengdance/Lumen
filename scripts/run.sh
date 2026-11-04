#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-Debug}"
./scripts/build.sh "$CONFIG"
open "$PWD/build/Build/Products/$CONFIG/Lumen.app"
