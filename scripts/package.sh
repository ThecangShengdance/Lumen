#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

./scripts/build.sh Release

APP="build/Build/Products/Release/Lumen.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"

mkdir -p dist
rm -rf dist/Lumen.app "dist/Lumen-${VERSION}.zip"
ditto --norsrc --noextattr "$APP" dist/Lumen.app

# Finder/provenance metadata invalidates strict codesign verification and
# should not travel in the zip.
xattr -cr dist/Lumen.app 2>/dev/null || true
codesign --verify --deep --strict dist/Lumen.app
ditto -c -k --norsrc --noextattr --keepParent dist/Lumen.app "dist/Lumen-${VERSION}.zip"

echo "Packaged: $PWD/dist/Lumen-${VERSION}.zip"
