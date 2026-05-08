# Wallpaper Span

A KDE Plasma 6 wallpaper plugin that splits one ultrawide image (7680×2160) across two side-by-side 4K monitors. Folder-based shuffle with crossfade transitions; both monitors stay locked in step.

> 100% coded by Claude. I don't want any confusion about that — I don't have the ability to make something like this, but (1) I couldn't find anyone else working on it and (2) I was sick of waiting. So here it is if you want to mess with it.

## What it does

Point it at a folder of 7680×2160 images. Each image is split: left half goes on the left monitor, right half on the right monitor. Shuffles on a timer, with "show every image once before repeating" semantics. Clicking Next Wallpaper from either monitor's config — or directly from the right-click desktop menu — updates both monitors at the same instant with a crossfade.

```
┌─────────────────┬─────────────────┐
│  Left Monitor   │  Right Monitor  │
│   (Left Half)   │  (Right Half)   │   ← imagine bezels
│                 │                 │
│   ◄────── Single 7680×2160 ──────►
└─────────────────┴─────────────────┘
```

## Screenshots

*(drop your screenshots in here)*

## Requirements

Plasma 6, Qt 6. Designed for dual 3840×2160 monitors arranged side-by-side. For other configurations you'll need to adjust the screen-detection logic in `main.qml`.

Build dependencies:

**Arch / CachyOS**
```
sudo pacman -S base-devel cmake extra-cmake-modules plasma-framework qt6-base qt6-declarative
```

**Ubuntu / Debian**
```
sudo apt install build-essential cmake extra-cmake-modules libplasma-dev qt6-base-dev qt6-declarative-dev
```

**Fedora**
```
sudo dnf install gcc-c++ cmake extra-cmake-modules plasma-workspace-devel qt6-qtbase-devel qt6-qtdeclarative-devel
```

## Install

```
git clone https://github.com/Arrdee81/wallpaper-span.git
cd wallpaper-span
./install.sh
```

`install.sh` asks for sudo because it puts the C++ QML extension in `/usr/lib/qt6/qml`. That's the only location Qt 6 reliably searches for QML modules on Arch/CachyOS — installs to `~/.local/lib/qt6/qml` look like they succeed but Plasma silently ignores them. The wallpaper package (QML + metadata) still goes to `~/.local/share/plasma/wallpapers/` via XDG.

After install, restart Plasma:

```
systemctl --user restart plasma-plasmashell.service
```

Then configure each monitor separately. Right-click each desktop → Configure Desktop and Wallpaper → Wallpaper Type → Wallpaper Span. Point the first one at your wallpaper folder; the second monitor inherits the choice.

## Usage

Drop 7680×2160 images in a folder:

```
~/Pictures/Wallpapers/
├── ultrawide-001.png
├── ultrawide-002.jpg
└── ...
```

Supported formats: jpg, jpeg, png, bmp, webp.

Settings:

- **Image Folder** — where your wallpapers live.
- **Shuffle** — on/off.
- **Change Interval** — 1 minute to 8 hours. Quick buttons for 5m, 15m, 30m, 1h, 2h.
- **Next Wallpaper** — skip to a new pick immediately. Works from either monitor's config dialog, or from the desktop's right-click menu.

## How it works

The C++ side (`src/wallpapersync.cpp`) is a small QML singleton with one string property and one change signal. It's registered via `qmlRegisterSingletonType` in a `QQmlExtensionPlugin`. Plasma reuses one `QQmlEngine` for the entire `plasmashell` process via a static `weak_ptr` in `SharedQmlEngine`, so this singleton is *one* shared instance visible to both monitors' `WallpaperItem`s.

The QML side (`main.qml`) on each monitor has `Connections { target: WallpaperSync }`. When the leader picks a new image (timer or Next button), it writes to `WallpaperSync.currentImage`. The setter compares old vs new, emits `currentImageChanged`, and both monitors' QML handlers fire synchronously inside that emit. No IPC latency, no file watcher, no cache file — both displays update in the same call stack.

The wallpaper image itself uses two stacked `Image` elements that alternate active/inactive. New picks decode into the inactive slot in the background; when it reports `Image.Ready`, the opacity bindings flip and the two slots crossfade. There's no fade-through-black moment.

## What gets installed

```
/usr/lib/qt6/qml/org/kde/plasma/wallpaper/span/                       # C++ plugin (sudo)
~/.local/share/plasma/wallpapers/com.github.arrdee81.wallpaperspan/   # QML package
```

## Troubleshooting

**Both monitors black.** Check the wallpaper folder is set and actually contains images. Restart plasmashell. Confirm the C++ plugin loaded:

```
lsof -p (pgrep -x plasmashell) | grep wallpaperspan_sync
```

You should see the `.so` from `/usr/lib/qt6/qml/...`. If it shows a path under `~/.local/lib/qt6/qml/...`, that's a stale install from an older version — `sudo rm -rf` it and re-run `install.sh`.

**Right monitor showing default Plasma blue.** Each monitor's wallpaper plugin is configured separately. Right-click the right monitor's desktop, change its Wallpaper Type to Wallpaper Span. Verify with:

```
grep wallpaperplugin ~/.config/plasma-org.kde.plasma.desktop-appletsrc
```

You should see two `wallpaperplugin=com.github.arrdee81.wallpaperspan` lines (one per monitor). Other lines are containments for disconnected/historical screens — ignore them.

**Plugin doesn't appear in the wallpaper-type dropdown.** Verify the QML package is at `~/.local/share/plasma/wallpapers/com.github.arrdee81.wallpaperspan/` and that you restarted plasmashell after installing.

## Building from source

```
rm -rf build
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
sudo make install
```

The wallpaper package (QML, metadata, config schema) gets copied separately by `install.sh` to `~/.local/share/plasma/wallpapers/`. To do that step manually:

```
mkdir -p ~/.local/share/plasma/wallpapers
cp -r com.github.arrdee81.wallpaperspan ~/.local/share/plasma/wallpapers/
```

## Uninstall

```
./uninstall.sh
systemctl --user restart plasma-plasmashell.service
```

Switch each monitor's wallpaper type back to "Image" before restarting if you want to keep their per-monitor saved wallpaper from before. If `uninstall.sh` is missing/stale:

```
sudo rm -rf /usr/lib/qt6/qml/org/kde/plasma/wallpaper/span
rm -rf ~/.local/share/plasma/wallpapers/com.github.arrdee81.wallpaperspan
```

## File layout

```
wallpaper-span/
├── CMakeLists.txt
├── install.sh
├── uninstall.sh
├── src/
│   ├── wallpapersync.h
│   ├── wallpapersync.cpp
│   └── qmldir
└── com.github.arrdee81.wallpaperspan/
    ├── metadata.json
    └── contents/
        ├── config/
        │   └── main.xml
        └── ui/
            ├── main.qml
            └── config.qml
```

## Contributing

Issues and PRs welcome. Forks too — if you fork it, yell at me. I'm just getting into this and would like to see where it goes.

Roadmap-ish things I'd still want, in no particular order:

- Support for more than two monitors
- Vertical monitor arrangements
- Configurable crossfade duration in the settings panel
- Better detection of monitor layout that doesn't rely on the `virtualX < 1000` heuristic

## Credits

Author: Arrdee81 (paid the electric while Claude burned tokens).

License: [GPL-3.0-or-later](LICENSE).

Built on KDE Frameworks 6 and Qt 6.
