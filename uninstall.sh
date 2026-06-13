#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Wallpaper Span - Uninstall Script (v2)
# ─────────────────────────────────────────────────────────────

set -euo pipefail

PLUGIN_ID="com.github.arrdee81.wallpaperspan"
INSTALL_DIR="$HOME/.local/share/plasma/wallpapers/$PLUGIN_ID"

echo "=============================================="
echo "      Wallpaper Span - Uninstaller            "
echo "=============================================="
echo ""

# Remove the QML wallpaper package.
if [ -d "$INSTALL_DIR" ]; then
    echo "→ Removing wallpaper package: $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
else
    echo "→ Wallpaper package not installed."
fi

# Remove any leftover v1.x C++ module (system path → needs sudo).
QML_DIR="$(qmake6 -query QT_INSTALL_QML 2>/dev/null || true)"
LEGACY_CPP="$QML_DIR/org/kde/plasma/wallpaper/span"
if [ -n "$QML_DIR" ] && [ -d "$LEGACY_CPP" ]; then
    echo "→ Removing leftover v1.x C++ module (needs sudo): $LEGACY_CPP"
    sudo rm -rf "$LEGACY_CPP"
fi
rm -rf "$HOME/.local/lib/qt6/qml/org/kde/plasma/wallpaper/span" 2>/dev/null || true

echo ""
echo "NOTE: Set each monitor's wallpaper type back to 'Image', then restart:"
echo "      systemctl --user restart plasma-plasmashell.service"
