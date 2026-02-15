#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Wallpaper Span - Install Script
# ─────────────────────────────────────────────────────────────

set -euo pipefail

PLUGIN_ID="com.github.arrdee81.wallpaperspan"
INSTALL_DIR="$HOME/.local/share/plasma/wallpapers/$PLUGIN_ID"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/$PLUGIN_ID"

echo "=============================================="
echo "       Wallpaper Span - Installer            "
echo "=============================================="
echo ""

# Build C++ sync plugin
echo "→ Building C++ sync plugin..."
rm -rf build
mkdir -p build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX="$HOME/.local" -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
echo "→ Installing C++ plugin to user directory..."
make install
cd ..

# Check the source files exist
if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: Plugin source not found at: $SOURCE_DIR"
    echo "       Make sure you're running this from the project root."
    exit 1
fi

# Remove old installation if present
if [ -d "$INSTALL_DIR" ]; then
    echo "→ Removing previous installation..."
    rm -rf "$INSTALL_DIR"
fi

# Create target directory and copy files
echo "→ Installing QML files to: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -r "$SOURCE_DIR"/* "$INSTALL_DIR"/

echo "→ Installation complete!"
echo ""
echo "=============================================="
echo "  Next steps:                                "
echo "                                             "
echo "  1. Restart Plasma:                         "
echo "     systemctl --user restart                "
echo "        plasma-plasmashell.service           "
echo "                                             "
echo "  2. Right-click desktop                     "
echo "     -> Configure Desktop & Wallpaper        "
echo "     -> Wallpaper Type: Wallpaper Span       "
echo "                                             "
echo "  3. Do this on BOTH monitors                "
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
