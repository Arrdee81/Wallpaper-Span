#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Wallpaper Span - Uninstall Script
# ─────────────────────────────────────────────────────────────

set -euo pipefail

PLUGIN_ID="com.github.arrdee81.wallpaperspan"
INSTALL_DIR="$HOME/.local/share/plasma/wallpapers/$PLUGIN_ID"
CPP_PLUGIN_DIR="$HOME/.local/lib/qt6/qml/org/kde/plasma/wallpaper/span"

echo "=============================================="
echo "      Wallpaper Span - Uninstaller           "
echo "=============================================="
echo ""

# Remove QML plugin
if [ -d "$INSTALL_DIR" ]; then
    echo "→ Removing QML plugin: $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
    echo "→ QML plugin removed."
else
    echo "→ QML plugin not installed."
fi

# Remove C++ plugin
if [ -d "$CPP_PLUGIN_DIR" ]; then
    echo "→ Removing C++ plugin: $CPP_PLUGIN_DIR"
    rm -rf "$CPP_PLUGIN_DIR"
    echo "→ C++ plugin removed."
else
    echo "→ C++ plugin not installed."
fi

echo ""
echo "NOTE: Change your wallpaper type back to 'Image' on"
echo "      both monitors, then restart Plasma:"
echo "      systemctl --user restart plasma-plasmashell.service"
