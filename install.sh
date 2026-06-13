#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Wallpaper Span - Install Script (v2: pure QML, no build, no sudo)
# ─────────────────────────────────────────────────────────────
#
# v2 is pure QML — there is no C++ plugin to compile and nothing to
# write to a system path. Install is just copying the wallpaper package
# into your user data dir, which Plasma searches via XDG_DATA_DIRS.
#
# If you previously installed v1.x, it left a compiled C++ module under
# the system QML dir (installed with sudo). This script offers to remove
# that leftover — it is no longer used.
# ─────────────────────────────────────────────────────────────

set -euo pipefail

PLUGIN_ID="com.github.arrdee81.wallpaperspan"
INSTALL_DIR="$HOME/.local/share/plasma/wallpapers/$PLUGIN_ID"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/$PLUGIN_ID"

echo "=============================================="
echo "       Wallpaper Span - Installer (v2)        "
echo "=============================================="
echo ""

if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: Plugin source not found at: $SOURCE_DIR"
    echo "       Run this from the project root."
    exit 1
fi

# Install the wallpaper package (pure QML + metadata) — no sudo needed.
if [ -d "$INSTALL_DIR" ]; then
    echo "→ Removing previous install at $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
fi
echo "→ Installing wallpaper package to: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -r "$SOURCE_DIR"/* "$INSTALL_DIR"/

# Offer to remove the leftover v1.x C++ module (needs sudo to delete).
QML_DIR="$(qmake6 -query QT_INSTALL_QML 2>/dev/null || true)"
LEGACY_CPP="$QML_DIR/org/kde/plasma/wallpaper/span"
if [ -n "$QML_DIR" ] && [ -d "$LEGACY_CPP" ]; then
    echo ""
    echo "→ Found a leftover v1.x C++ module at:"
    echo "    $LEGACY_CPP"
    echo "  v2 does not use it. Removing it needs sudo."
    read -p "  Remove it now? (y/n): " rmcpp
    if [ "$rmcpp" = "y" ] || [ "$rmcpp" = "Y" ]; then
        sudo rm -rf "$LEGACY_CPP"
        echo "  → Removed."
    else
        echo "  → Left in place (harmless; just unused)."
    fi
fi

# Also clean the old user-local C++ path some early installers used.
rm -rf "$HOME/.local/lib/qt6/qml/org/kde/plasma/wallpaper/span" 2>/dev/null || true

echo ""
echo "=============================================="
echo "  Next steps:                                "
echo "                                             "
echo "  1. Restart Plasma:                         "
echo "     systemctl --user restart                "
echo "        plasma-plasmashell.service           "
echo "                                             "
echo "  2. Right-click each desktop                "
echo "     -> Configure Desktop & Wallpaper        "
echo "     -> Wallpaper Type: Wallpaper Span       "
echo "     Point one monitor at your folder;       "
echo "     set the others to Wallpaper Span too.   "
echo "=============================================="
echo ""

read -p "Restart Plasma shell now? (y/n): " answer
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    echo "→ Restarting Plasma..."
    systemctl --user restart plasma-plasmashell.service
    echo "→ Done."
else
    echo "→ Restart when ready:"
    echo "  systemctl --user restart plasma-plasmashell.service"
fi
