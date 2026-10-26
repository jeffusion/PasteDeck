#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="PasteDeck"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
BUNDLE_ID="com.pastedeck.app"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
for _ in {1..50}; do
    if ! pgrep -x "$APP_NAME" >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done
if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    echo "PasteDeck did not exit within 5 seconds" >&2
    exit 1
fi
CONFIGURATION=debug make -C "$ROOT_DIR" app

open_app() {
    /usr/bin/open "$APP_BUNDLE"
}

case "$MODE" in
    run) open_app ;;
    --debug|debug) lldb -- "$APP_BINARY" ;;
    --logs|logs)
        open_app
        /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
        ;;
    --telemetry|telemetry)
        open_app
        /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
        ;;
    --verify|verify)
        open_app
        sleep 2
        pgrep -x "$APP_NAME" >/dev/null
        ;;
    *) echo "Usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac
