#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="PasteDeck"
VERSION="${VERSION:-$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
CONFIGURATION="${CONFIGURATION:-release}"
ARCHS="${ARCHS:-$(uname -m)}"
DERIVED_DATA="$ROOT_DIR/.build/xcode"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
    echo "Invalid VERSION: $VERSION" >&2
    exit 2
fi

if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Invalid BUILD_NUMBER: $BUILD_NUMBER" >&2
    exit 2
fi

case "$CONFIGURATION" in
    [Dd][Ee][Bb][Uu][Gg]) XCODE_CONFIGURATION="Debug" ;;
    [Rr][Ee][Ll][Ee][Aa][Ss][Ee]) XCODE_CONFIGURATION="Release" ;;
    *) echo "Invalid CONFIGURATION: $CONFIGURATION" >&2; exit 2 ;;
esac

cd "$ROOT_DIR"
xcodebuild \
    -project PasteDeck.xcodeproj \
    -scheme PasteDeck \
    -configuration "$XCODE_CONFIGURATION" \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    -clonedSourcePackagesDirPath "$ROOT_DIR/.build/xcode-packages" \
    -skipPackageUpdates \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    ARCHS="$ARCHS" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    build

BUILT_APP="$DERIVED_DATA/Build/Products/$XCODE_CONFIGURATION/$APP_NAME.app"
if [[ ! -d "$BUILT_APP" ]]; then
    echo "Built app not found: $BUILT_APP" >&2
    exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$(dirname "$APP_BUNDLE")"
ditto "$BUILT_APP" "$APP_BUNDLE"

# Sign nested code from the inside out, then seal the outer app with an ad-hoc signature.
while IFS= read -r -d '' code; do
    codesign --force --sign - "$code"
done < <(find "$APP_BUNDLE/Contents" -depth -type d \( -name '*.framework' -o -name '*.bundle' -o -name '*.xpc' -o -name '*.app' \) -print0)
codesign --force --sign - "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "Created $APP_BUNDLE"
