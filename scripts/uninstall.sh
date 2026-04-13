#!/bin/bash

PREFIX="${PREFIX:-$HOME/.local}"
BIN="$PREFIX/bin"
LABEL="com.paulwolf.winduz"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null && echo "Stopped Winduz" || true
rm -f "$BIN/Winduz" && echo "Removed $BIN/Winduz" || true
rm -f "$BIN/wz" && echo "Removed $BIN/wz" || true
rm -f "$PLIST" && echo "Removed $PLIST" || true
echo "Uninstalled."
