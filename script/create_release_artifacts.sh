#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-all}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="PasteDeck"
VERSION="${VERSION:-$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")}"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_FILE="$DIST_DIR/$APP_NAME-$VERSION.dmg"
ZIP_FILE="$DIST_DIR/$APP_NAME-$VERSION.zip"
STAGING_DIR=""

cleanup() {
    if [[ -n "$STAGING_DIR" && -d "$STAGING_DIR" ]]; then
        rm -rf "$STAGING_DIR"
    fi
}
trap cleanup EXIT

[[ -d "$APP_BUNDLE" ]] || { echo "App bundle not found: $APP_BUNDLE" >&2; exit 1; }

create_zip() {
    rm -f "$ZIP_FILE"
    ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_FILE"
    (cd "$DIST_DIR" && shasum -a 256 "$(basename "$ZIP_FILE")") > "$ZIP_FILE.sha256"
}

create_dmg() {
    STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pastedeck-dmg.XXXXXX")"
    cp -R "$APP_BUNDLE" "$STAGING_DIR/"
    ln -s /Applications "$STAGING_DIR/Applications"
    rm -f "$DMG_FILE"
    hdiutil create -quiet -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_FILE"
    hdiutil verify "$DMG_FILE"
    (cd "$DIST_DIR" && shasum -a 256 "$(basename "$DMG_FILE")") > "$DMG_FILE.sha256"
    cleanup
    STAGING_DIR=""
}

case "$MODE" in
    zip) create_zip ;;
    dmg) create_dmg ;;
    all) create_zip; create_dmg ;;
    *) echo "Usage: $0 [zip|dmg|all]" >&2; exit 2 ;;
esac

echo "Created release artifacts in $DIST_DIR"
