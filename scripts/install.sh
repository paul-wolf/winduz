#!/bin/bash
set -e

if [ "$(id -u)" = "0" ]; then
    echo "error: do not run as root / with sudo — launchd user agents must be loaded by the owning user."
    exit 1
fi

PREFIX="${PREFIX:-$HOME/.local}"
BIN="$PREFIX/bin"
LABEL="com.paulwolf.winduz"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/Winduz.log"

echo "Building release..."
swift build -c release

mkdir -p "$BIN"
cp .build/release/Winduz "$BIN/Winduz"
cp .build/release/wz "$BIN/wz"
echo "Installed: $BIN/Winduz"
echo "Installed: $BIN/wz"

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BIN/Winduz</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>$LOG</string>
    <key>StandardErrorPath</key>
    <string>$LOG</string>
</dict>
</plist>
EOF
echo "Installed launchd plist: $PLIST"

# Register plist for launch-at-login (best effort — ignore if already loaded)
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null || true

# Remove quarantine so macOS doesn't block unsigned local binaries
xattr -d com.apple.quarantine "$BIN/Winduz" 2>/dev/null || true
xattr -d com.apple.quarantine "$BIN/wz" 2>/dev/null || true

# Kill any running instance and start the freshly installed binary
pkill -f "$BIN/Winduz" 2>/dev/null || true
sleep 0.5
nohup "$BIN/Winduz" > /dev/null 2>&1 &
disown $!
echo ""
echo "Winduz installed and started."
echo ""

if [[ ":$PATH:" != *":$BIN:"* ]]; then
    echo "Note: $BIN is not on your PATH."
    echo "Add this to your ~/.zshrc:"
    echo "  export PATH=\"$BIN:\$PATH\""
fi
