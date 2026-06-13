# Wallpaper Span

Splits one wide image across two or more side-by-side monitors and keeps them changing together. Point it at a folder of images sized to your whole desktop (7680x2160 for two 4K screens), and it puts the left part on the left monitor, the right part on the right, shuffles on a timer, and cross-fades both screens to the next picture at the same instant.

It's a KDE Plasma 6 wallpaper plugin, written in pure QML. Nothing to compile, no root needed. Installing is copying a folder.

I'm not a programmer. Claude wrote the code; I pointed it where to go and tested it on my own machines. If something's broken, file an issue, because I probably won't catch it on my own.

## Requirements

Plasma 6 and Qt 6. Built and tested on Plasma 6.6.5.

Monitors side by side. It reads your real screen layout instead of assuming a fixed size, so three or more screens, and screens at different resolutions, work too. There are no build dependencies — there's nothing to build.

## Install

```
git clone https://github.com/Arrdee81/wallpaper-span.git
cd wallpaper-span
./install.sh
```

`install.sh` copies the package into `~/.local/share/plasma/wallpapers/`. No sudo. (If you had v1.x installed, it offers to delete the old compiled plugin from the system path. That part needs sudo — let it.)

Restart Plasma:

```
systemctl --user restart plasma-plasmashell.service
```

Then right-click each desktop → Configure Desktop and Wallpaper → Wallpaper Type → Wallpaper Span. Do it for every monitor. Point one at your image folder; the others fall in line.

## Using it

Put images sized to your combined desktop in a folder. jpg, jpeg, png, bmp, and webp work.

Settings:

- **Image folder.**
- **Shuffle or sequential.**
- **Change every** — anywhere from 10 seconds to 6 hours.
- **Crossfade length.**
- **Next Wallpaper** — skip ahead now, from either monitor's settings or the desktop right-click menu.

## How the sync works

This is the part worth explaining. Plasma runs a single QML engine for the whole shell, and a QML singleton is one instance per engine — so one shared object is visible to every monitor's wallpaper at once. One screen picks the next image and writes it to that object; every monitor's handler runs inside that same write. Nothing flips until all of them have the new image decoded, and then they all switch in one shot, so the crossfades land on the same frame. The next image is decoded in the background ahead of time, so the change itself is instant. No IPC, no temp files, no C++.

## Uninstall

```
./uninstall.sh
systemctl --user restart plasma-plasmashell.service
```

Set each monitor back to a normal wallpaper type first if you want to keep its old picture.

## If it doesn't work

- **Both monitors black:** check the folder is set and actually has images, then restart plasmashell.
- **One monitor still showing the default blue:** wallpaper is set per monitor — set that one to Wallpaper Span too.
- **Not in the wallpaper-type list:** make sure the package is at `~/.local/share/plasma/wallpapers/com.github.arrdee81.wallpaperspan/` and that you restarted plasmashell.

## Not done yet

- Subfolders and multiple folders.
- Pausing changes while something's fullscreen.

## License

GPL-3.0-or-later. Built on KDE Frameworks 6 and Qt 6.
