#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Wallpaper Span - Install Script
# ─────────────────────────────────────────────────────────────
#
# Installs the C++ QML extension to /usr/lib/qt6/qml (system path —
# requires sudo). Plasma's Qt 6 only searches /usr/lib/qt6/qml for
# QML imports by default; ~/.local/lib/qt6/qml is NOT in the import
# path on Arch/CachyOS without extra environment configuration. The
# wallpaper package (QML + metadata) goes to ~/.local/share/plasma/
# wallpapers/, which Plasma does search via XDG_DATA_DIRS.
#
# ─────────────────────────────────────────────────────────────

set -euo pipefail

PLUGIN_ID="com.github.arrdee81.wallpaperspan"
INSTALL_DIR="$HOME/.local/share/plasma/wallpapers/$PLUGIN_ID"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/$PLUGIN_ID"

# Orphaned from v1.0/v1.1 file-watcher IPC. v1.2 uses an in-process QML
# singleton; this file is no longer read or written.
LEGACY_SYNC_FILE="$HOME/.cache/wallpaper-span.sync"

echo "=============================================="
echo "       Wallpaper Span - Installer            "
echo "=============================================="
echo ""
echo "This installer needs sudo to write the C++ QML"
echo "plugin to /usr/lib/qt6/qml — Plasma only loads"
echo "QML modules from system paths by default."
echo ""

# Build C++ sync plugin
echo "→ Building C++ sync plugin..."
rm -rf build
mkdir -p build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
echo "→ Installing C++ plugin to /usr/lib/qt6/qml (requires sudo)..."
sudo make install
cd ..

# Check the source files exist
if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: Plugin source not found at: $SOURCE_DIR"
    echo "       Make sure you're running this from the project root."
    exit 1
fi

# Remove old wallpaper package installation
if [ -d "$INSTALL_DIR" ]; then
    echo "→ Removing previous wallpaper package installation..."
    rm -rf "$INSTALL_DIR"
fi

# Install the wallpaper package (QML + metadata) to user data dir
echo "→ Installing wallpaper package to: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -r "$SOURCE_DIR"/* "$INSTALL_DIR"/

# Clean up any old user-local C++ install — leftover from earlier
# installer versions that wrote to ~/.local/lib/qt6/qml. Plasma never
# loaded from there but having two copies is confusing.
USER_LOCAL_QML="$HOME/.local/lib/qt6/qml/org/kde/plasma/wallpaper/span"
if [ -d "$USER_LOCAL_QML" ]; then
    echo "→ Removing stale user-local C++ install at $USER_LOCAL_QML"
    rm -rf "$USER_LOCAL_QML"
fi

# Clean up the v1.0/v1.1 file-watcher IPC artifact.
if [ -f "$LEGACY_SYNC_FILE" ]; then
    echo "→ Removing legacy sync file (no longer used in v1.2): $LEGACY_SYNC_FILE"
    rm -f "$LEGACY_SYNC_FILE"
fi

echo "→ Installation complete!"
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
echo "                                             "
echo "  Both monitors must be set to Wallpaper     "
echo "  Span individually.                         "
echo "=============================================="
echo ""

read -p "Restart Plasma shell now? (y/n): " answer
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    echo "→ Restarting Plasma..."
    systemctl --user restart plasma-plasmashell.service
    echo "→ Done! Your desktop will reload in a moment."
else
    echo "→ Remember to restart Plasma when you're ready:"
    echo "  systemctl --user restart plasma-plasmashell.service"
fi
