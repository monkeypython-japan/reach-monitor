#!/bin/bash
# Build ReachMonitor and install it as a LaunchAgent (auto-start on login).
# Usage: ./bundle/make-app.sh          — build + install
#        ./bundle/make-app.sh start    — (re)start without rebuilding
#        ./bundle/make-app.sh stop     — stop
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="ReachMonitor"
BUNDLE_ID="com.mamoru.reachmonitor"
INSTALL_DIR="$HOME/Applications"
APP="$INSTALL_DIR/$APP_NAME.app"
PLIST="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"
BINARY="$APP/Contents/MacOS/$APP_NAME"
UID_VAL="$(id -u)"

# ---- helper functions -------------------------------------------------------

agent_stop() {
    launchctl bootout "gui/$UID_VAL/$BUNDLE_ID" 2>/dev/null || true
    pkill -x "$APP_NAME" 2>/dev/null || true
}

agent_start() {
    if [[ ! -f "$PLIST" ]]; then
        echo "error: $PLIST not found — run without 'start' argument first" >&2
        exit 1
    fi
    agent_stop
    sleep 1
    launchctl bootstrap "gui/$UID_VAL" "$PLIST"
    sleep 2
    if pgrep -x "$APP_NAME" >/dev/null; then
        echo "==> Started ✓  (PID $(pgrep -x $APP_NAME))"
    else
        echo "error: process did not start — check /tmp/reachmonitor.log" >&2
        exit 1
    fi
}

# ---- sub-commands -----------------------------------------------------------

if [[ "${1:-}" == "start" ]]; then agent_start; exit 0; fi
if [[ "${1:-}" == "stop"  ]]; then agent_stop;  echo "==> Stopped"; exit 0; fi

# ---- full build + install ---------------------------------------------------

CONFIG="release"

echo "==> Building ($CONFIG)…"
swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"
if [[ ! -x "$BIN" ]]; then
    echo "error: built binary not found at $BIN" >&2
    exit 1
fi

echo "==> Assembling $APP …"
agent_stop; sleep 1
mkdir -p "$INSTALL_DIR"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN" "$BINARY"
cp "$ROOT/bundle/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Ad-hoc code signing…"
codesign --force --sign - "$APP"

echo "==> Installing LaunchAgent → $PLIST"
cat > "$PLIST" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$BUNDLE_ID</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BINARY</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/tmp/reachmonitor.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/reachmonitor.log</string>
</dict>
</plist>
PLIST_EOF

agent_start

echo ""
echo "==> Done."
echo "    App:        $APP"
echo "    LaunchAgent: $PLIST  (auto-starts on login)"
echo "    Stop:       ./bundle/make-app.sh stop"
echo "    Restart:    ./bundle/make-app.sh start"
echo "    Logs:       tail -f /tmp/reachmonitor.log"
