# Wallpaper Span - KDE Plasma 6 Plugin

A KDE Plasma 6 wallpaper plugin that spans a single ultrawide wallpaper image across two side-by-side monitors, with automatic shuffle support.

![License](https://img.shields.io/badge/license-GPL--3.0-blue)
![Plasma](https://img.shields.io/badge/Plasma-6-blue)
![Qt](https://img.shields.io/badge/Qt-6.6%2B-green)

## Features

- 🖼️ **Spans ultrawide wallpapers** (7680×2160) across two 3840×2160 monitors
- 🔄 **Smart shuffle** - Shows each image once before repeating
- ⚡ **Event-driven sync** - C++ file watcher for instant updates (zero CPU when idle)
- 🎨 **Smooth transitions** - Elegant fade animations between wallpapers
- ⚙️ **Configurable intervals** - From 1 minute to 8 hours
- 🔒 **No sudo required** - Installs to user directory 
- 🎯 **Manual control** - "Next Wallpaper" button to skip anytime
- 💩 **Dang** this ai was up itself. 
+
## Screenshots

### Wallpaper Spanning Across Dual Monitors
![Dual monitor wallpaper span](screenshots/Screenshot_20260214_193447.png)

### Settings Panel
![Configuration interface](screenshots/Screenshot_20260214_194427.png)
```
┌─────────────────┬─────────────────┐
│  Left Monitor   │  Right Monitor  │
│    (Left Half)  │   (Right Half)  │
│                 │                 │
│   ◄────────── Single 7680×2160 Image ──────────►  │      <------------ sick work, claude. 
└─────────────────┴─────────────────┘
```

## Requirements

### CachyOS / Arch Linux
```bash
sudo pacman -S base-devel cmake extra-cmake-modules plasma-framework qt6-base qt6-declarative
```

### Ubuntu / Debian
```bash
sudo apt install build-essential cmake extra-cmake-modules libplasma-dev qt6-base-dev qt6-declarative-dev
```

### Fedora
```bash
sudo dnf install gcc-c++ cmake extra-cmake-modules plasma-workspace-devel qt6-qtbase-devel qt6-qtdeclarative-devel
```

## Installation

### From Source (Recommended)

1. **Clone the repository:**
```bash
git clone https://github.com/Arrdee81/Wallpaper-Span.git
cd Wallpaper-Span
```

2. **Run the install script:**
```bash
./install.sh
```

3. **When prompted, restart Plasma** (or do it manually):
```bash
systemctl --user restart plasma-plasmashell.service
```

4. **Configure on BOTH monitors:**
   - Right-click desktop → Configure Desktop & Wallpaper
   - Wallpaper Type: **Wallpaper Span**
   - Choose your wallpaper folder
   - Configure shuffle settings

### What Gets Installed

- **C++ Plugin:** `~/.local/lib/qt6/qml/org/kde/plasma/wallpaper/span/`
- **QML Files:** `~/.local/share/plasma/wallpapers/com.github.arrdee81.wallpaperspan/`
- **Sync File:** `~/.cache/wallpaper-span.sync` (created automatically)

**No system files are modified!** Everything installs to your home directory.

## Usage

### Folder Structure

Place your 7680×2160 wallpaper images in a folder, for example:
```
~/Pictures/Wallpapers/
├── ultrawide-001.png
├── ultrawide-002.jpg
├── nature-scene.jpg
└── abstract-art.png
```

Supported formats: `.jpg`, `.jpeg`, `.png`, `.bmp`, `.webp`

### Configuration Options

| Setting | Description | Default |
|---------|-------------|---------|
| **Image Folder** | Location of your wallpaper images | (none) |
| **Shuffle** | Automatically change wallpaper | Enabled |
| **Change Interval** | How often to change (1-480 minutes) | 15 minutes |
| **Next Wallpaper** | Manual skip button | - |

**Quick Intervals:** 5m, 15m, 30m, 1h, 2h buttons for fast selection

## How It Works

### Architecture

- **Left Monitor** (Controller):
  - Scans wallpaper folder
  - Picks random images using smart shuffle algorithm
  - Writes current image path to sync file via C++ plugin
  - Displays left half of image

- **Right Monitor** (Follower):
  - Watches sync file using `QFileSystemWatcher` (C++)
  - Gets notified instantly when left monitor changes wallpaper
  - Displays right half of the same image

### Sync Mechanism

Uses a C++ plugin with Qt's `QFileSystemWatcher` for **event-driven synchronization**:
- ✅ Instant updates (no polling)
- ✅ Zero CPU usage when idle
- ✅ No network or IPC overhead
- ✅ Simple and reliable

## Uninstallation

```bash
./uninstall.sh
```

Then:
1. Change wallpaper type back to "Image" on both monitors
2. Restart Plasma: `systemctl --user restart plasma-plasmashell.service`

## Troubleshooting

### Both monitors show black
- Verify wallpaper folder contains images
- Check folder path is correct in settings
- Restart Plasma shell

### Right monitor doesn't update
- Ensure both monitors are set to "Wallpaper Span" type
- Check journalctl logs: `journalctl --user -f | grep WallpaperSync`
- Verify C++ plugin installed: `ls ~/.local/lib/qt6/qml/org/kde/plasma/wallpaper/span/`

### Permission errors during install
- Make sure you're running `./install.sh` (not with sudo!)
- Check that `~/.local` is writable

### Plugin doesn't appear in settings
- Restart Plasma shell completely
- Check installation succeeded without errors
- Verify files exist in `~/.local/share/plasma/wallpapers/`

## Development

### Building from Source

```bash
# Clean build
rm -rf build
mkdir build && cd build

# Configure
cmake .. -DCMAKE_INSTALL_PREFIX="$HOME/.local" -DCMAKE_BUILD_TYPE=Release

# Build
make -j$(nproc)

# Install
make install
```

### File Structure

```
wallpaper-span/
├── CMakeLists.txt              # C++ build configuration
├── install.sh                  # Installation script
├── uninstall.sh               # Removal script
├── src/
│   ├── wallpapersync.h        # C++ sync plugin header
│   ├── wallpapersync.cpp      # C++ sync plugin implementation
│   └── qmldir                 # QML module definition
└── com.github.arrdee81.wallpaperspan/
    ├── metadata.json          # Plugin metadata
    └── contents/
        ├── config/
        │   └── main.xml       # Configuration schema
        └── ui/
            ├── main.qml       # Main wallpaper display
            └── config.qml     # Settings UI
```

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

### Areas for Improvement

- [ ] Support for more than 2 monitors
- [ ] Vertical monitor arrangements
- [ ] Custom aspect ratios
- [ ] Right-click context menu "Next Wallpaper" option
- [ ] Transition effects (crossfade, slide, etc.)

## Credits

- **Author:** Arrdee81 (he paid the electric while claude used tokens)
- **License:** GPL-3.0-or-later
- Built with KDE Frameworks 6 and Qt 6

## License

This project is licensed under the GNU General Public License v3.0 or later. See [LICENSE](LICENSE) for details.

---

**Note:** This plugin is designed specifically for dual 3840×2160 monitor setups arranged side-by-side. For other configurations, you may need to adjust the screen detection logic in `main.qml`.
If you fork this, yell at me.  Im just getting into this and would love to see how this evolves.  
