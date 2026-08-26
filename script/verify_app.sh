#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE="${1:-dist/PasteDeck.app}"
EXPECTED_VERSION="${EXPECTED_VERSION:-}"
EXPECTED_ARCHS="${EXPECTED_ARCHS:-}"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/PasteDeck"

[[ -d "$APP_BUNDLE" ]] || { echo "App bundle not found: $APP_BUNDLE" >&2; exit 1; }
[[ -x "$APP_BINARY" ]] || { echo "App executable not found: $APP_BINARY" >&2; exit 1; }
[[ -f "$APP_BUNDLE/Contents/Resources/AppIcon.icns" ]] || { echo "App icon is missing" >&2; exit 1; }
[[ -f "$APP_BUNDLE/Contents/Resources/MenuBarIcon.tiff" ]] || { echo "Multi-resolution menu bar icon is missing" >&2; exit 1; }
[[ -d "$APP_BUNDLE/Contents/Resources/en.lproj" ]] || { echo "PasteDeck localizations are missing" >&2; exit 1; }
[[ -d "$APP_BUNDLE/Contents/Resources/KeyboardShortcuts_KeyboardShortcuts.bundle" ]] || { echo "KeyboardShortcuts resource bundle is missing" >&2; exit 1; }
[[ ! -e "$APP_BUNDLE/Contents/embedded.provisionprofile" ]] || { echo "Unexpected provisioning profile found" >&2; exit 1; }

plutil -lint "$INFO_PLIST"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
[[ "$bundle_id" == "com.pastedeck.app" ]] || { echo "Unexpected bundle identifier: $bundle_id" >&2; exit 1; }

if [[ -n "$EXPECTED_VERSION" && "$version" != "$EXPECTED_VERSION" ]]; then
    echo "Expected version $EXPECTED_VERSION, found $version" >&2
    exit 1
fi

actual_archs="$(lipo -archs "$APP_BINARY")"
if [[ -n "$EXPECTED_ARCHS" ]]; then
    for arch in $EXPECTED_ARCHS; do
        [[ " $actual_archs " == *" $arch "* ]] || { echo "Missing architecture $arch (found: $actual_archs)" >&2; exit 1; }
    done
fi

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
signature_info="$(codesign -dvv "$APP_BUNDLE" 2>&1)"
grep -q '^Signature=adhoc$' <<< "$signature_info" || { echo "App is not ad-hoc signed" >&2; exit 1; }
grep -q '^TeamIdentifier=not set$' <<< "$signature_info" || { echo "Unexpected signing team found" >&2; exit 1; }
echo "Verified $APP_BUNDLE (version $version; architectures: $actual_archs; ad-hoc signed)"
