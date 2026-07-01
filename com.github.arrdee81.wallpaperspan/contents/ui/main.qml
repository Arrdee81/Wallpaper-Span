/*
 *  Wallpaper Span - KDE Plasma 6 Wallpaper Plugin
 *  Copyright (C) 2026 Arrdee81
 *
 *  SPDX-License-Identifier: GPL-3.0-or-later
 *
 *  Per-monitor view. Each monitor:
 *    • computes its slice of the combined virtual desktop from the real
 *      screen layout (Qt.application.screens) — no hardcoded resolutions,
 *      no virtualX<1000 heuristic; works for 2, 3+, unequal, mixed-DPI,
 *      vertical or grid arrangements;
 *    • displays the full span image shifted by its own offset and clipped to
 *      its window; every monitor uses the identical URL with no sourceSize,
 *      so Qt's pixmap cache shares ONE decode across all of them;
 *    • is a pure view driven by the shared Sync singleton: it decodes what
 *      Sync asks, reports readiness, and crossfades on Sync.flipNow so both
 *      monitors flip in the same frame.
 */

import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "lib"   // explicit directory import → loads lib/qmldir → Sync singleton

WallpaperItem {
    id: root

    // Emitted to the config UI so its "Current:" label / preview update.
    signal imageChanged(string newImage)

    // ── Right-click desktop menu entry ──────────────────────────────────
    contextualActions: [nextWallpaperAction]
    PlasmaCore.Action {
        id: nextWallpaperAction
        text: i18n("Next Wallpaper")
        icon.name: "media-skip-forward"
        onTriggered: Sync.advance()
    }

    // ── This monitor's geometry within the combined desktop ─────────────
    property int totalLogW: Screen.width     // combined-desktop span width  (logical px)
    property int totalLogH: Screen.height    // combined-desktop span height (logical px)
    property int myOffX: 0                    // this monitor's left edge in the span
    property int myOffY: 0                    // this monitor's top  edge in the span

    function computeGeometry() {
        var screens = Qt.application.screens;
        if (!screens || screens.length === 0) {
            totalLogW = Screen.width; totalLogH = Screen.height;
            myOffX = 0; myOffY = 0;
            return;
        }
        var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i];
            minX = Math.min(minX, s.virtualX);
            minY = Math.min(minY, s.virtualY);
            maxX = Math.max(maxX, s.virtualX + s.width);
            maxY = Math.max(maxY, s.virtualY + s.height);
        }
        totalLogW = maxX - minX;
        totalLogH = maxY - minY;
        myOffX = Screen.virtualX - minX;
        myOffY = Screen.virtualY - minY;
    }

    // Recompute when the screen layout changes — including a position-only
    // rearrangement (same size, new virtualX/Y), which width/height alone
    // would miss and which would leave stale offsets (same slice on both).
    onWidthChanged: computeGeometry()
    onHeightChanged: computeGeometry()
    readonly property int _vx: Screen.virtualX
    readonly property int _vy: Screen.virtualY
    on_VxChanged: computeGeometry()
    on_VyChanged: computeGeometry()

    // ── Mirror this monitor's Plasma config into the shared singleton ────
    // Both monitors push identical values, so last-writer-wins is harmless.
    property string cfgFolder:    root.configuration.FolderPath ?? ""
    property bool   cfgShuffle:   root.configuration.ShuffleEnabled ?? true
    property string cfgMode:      root.configuration.Mode ?? "shuffle"
    property int    cfgInterval:  root.configuration.IntervalSeconds ?? 900
    property int    cfgCrossfade: root.configuration.CrossfadeMs ?? 800

    onCfgFolderChanged:    Sync.folderPath = cfgFolder
    onCfgShuffleChanged:   Sync.shuffleEnabled = cfgShuffle
    onCfgModeChanged:      Sync.mode = cfgMode
    onCfgIntervalChanged:  Sync.intervalSeconds = cfgInterval
    onCfgCrossfadeChanged: Sync.crossfadeMs = cfgCrossfade

    function pushAllConfig() {
        Sync.folderPath = cfgFolder;
        Sync.shuffleEnabled = cfgShuffle;
        Sync.mode = cfgMode;
        Sync.intervalSeconds = cfgInterval;
        Sync.crossfadeMs = cfgCrossfade;
    }

    // Public entry point used by the config dialog's "Next Wallpaper" button.
    // Next-wallpaper entry point — called by the config dialog's button and the
    // desktop context-menu action. (Verified via journal probe that Plasma does
    // NOT auto-invoke a method of this name, so exposing it is safe.)
    function nextWallpaper() { Sync.advance(); }

    // ── Barrier client: decode-on-request, report-when-ready, flip-on-cue ─
    property int _loadingGen: -1
    property int _loadingSlot: -1
    property int _reportedGen: -1

    Connections {
        target: Sync

        // Sync asks every monitor to decode `url` (a file:// URL string) for
        // generation `forGen`. We load it into the inactive crossfade slot.
        function onRequestImage(url, forGen) {
            root._loadingGen = forGen;
            root._loadingSlot = (imageContainer.activeSlot === 0) ? 1 : 0;
            var slot = (root._loadingSlot === 0) ? slot0 : slot1;
            // If this slot already holds the decoded image (e.g. the next pick
            // is what's already loaded here), there will be no statusChanged —
            // report immediately. Otherwise set the source and let the status
            // handler drive the report once it finishes decoding.
            if (slot.source.toString() === url && slot.status === Image.Ready)
                root._reportSlot(forGen);
            else
                slot.source = url;
        }

        // All monitors ready → flip together, in this synchronous emit.
        // CRITICAL PATH: the only work here is the activeSlot switch (which
        // starts the opacity animation). Both monitors' handlers run
        // back-to-back inside this one emit, so anything slow here — above all
        // writeConfig()'s disk I/O — would delay the OTHER monitor's handler
        // and skew the flip. Logging, persistence and notify are deferred.
        function onFlipNow(forGen) {
            // Stale or never-received generation (e.g. the barrier timeout
            // fired before this monitor ever got requestImage): keep showing
            // the current image rather than switching to slot -1 (black).
            if (forGen !== root._loadingGen || root._loadingSlot < 0) return;
            // CRITICAL PATH — the visual switch is the ONLY work here, so both
            // monitors' handlers finish microseconds apart in this one emit.
            imageContainer.activeSlot = root._loadingSlot;
            // Notify the config panel promptly (cheap signal, next tick) but
            // defer the disk write well past the crossfade so its I/O can't
            // stutter the fade.
            Qt.callLater(root._notifyChanged);
            root._persistTimer.restart();
        }
    }

    function _notifyChanged() { root.imageChanged(Sync.currentImage); }

    // Deferred, coalesced disk persistence of the on-screen image (for
    // cold-start restore). Fires after the crossfade; rapid Next presses just
    // restart it, so we write at most once after a burst of changes.
    property Timer _persistTimer: Timer {
        interval: Math.max(900, Sync.crossfadeMs + 150)
        repeat: false
        onTriggered: {
            root.configuration.CurrentImage = Sync.currentImage;
            root.configuration.writeConfig();
        }
    }

    function _reportSlot(forGen) {
        if (_reportedGen === forGen) return;   // once per generation
        _reportedGen = forGen;
        Sync.reportReady(forGen);
    }
    function _slotFinished(slotIndex, status) {
        if (slotIndex !== _loadingSlot) return;
        if (status === Image.Ready || status === Image.Error)
            _reportSlot(_loadingGen);
    }

    // ── Startup ─────────────────────────────────────────────────────────
    Component.onCompleted: {
        Sync.registerMonitor();
        computeGeometry();
        pushAllConfig();

        // Cold-start restore: show the last image immediately (no black gap)
        // while the folder rescans in the background. Seed the shared
        // singleton from saved config if nothing is showing yet.
        // Configs written before v2.0.1 stored a plain path; encode it into
        // the file:// URL form everything now uses.
        var saved = root.configuration.CurrentImage || "";
        if (saved && saved.indexOf("file://") !== 0)
            saved = "file://" + encodeURI(saved).replace(/#/g, "%23").replace(/\?/g, "%3F");
        if (Sync.currentImage === "" && saved) Sync.currentImage = saved;
        if (Sync.currentImage) {
            slot0.source = Sync.currentImage;
            imageContainer.activeSlot = 0;
        }
    }
    Component.onDestruction: Sync.unregisterMonitor()

    // ── The actual wallpaper display ────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "black"

        // Two stacked Image slots take turns being visible. A new pick decodes
        // into the inactive slot; when Sync says flip, activeSlot switches and
        // both opacities animate — a crossfade with no fade-through-black.
        //
        // Each slot is the FULL combined-desktop image, sized to the whole span
        // and shifted by this monitor's offset (-myOffX/-myOffY) so the monitor
        // window sees only its slice; imageContainer's clip hides the rest. All
        // monitors use the identical image/size/fillMode, so the picture stays
        // continuous across the bezels.
        Item {
            id: imageContainer
            anchors.fill: parent
            clip: true
            property int activeSlot: 0

            Image {
                id: slot0
                x: -root.myOffX
                y: -root.myOffY
                width: root.totalLogW
                height: root.totalLogH
                // No sourceSize pin: decode at the file's native resolution.
                // The panels can't display more than that, so forcing the 2x
                // backing-store size just upscaled then downscaled — pure waste.
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                opacity: (imageContainer.activeSlot === 0 && status === Image.Ready) ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: Sync.crossfadeMs; easing.type: Easing.InOutQuad } }
                onStatusChanged: root._slotFinished(0, status)
            }

            Image {
                id: slot1
                x: -root.myOffX
                y: -root.myOffY
                width: root.totalLogW
                height: root.totalLogH
                // No sourceSize pin: decode at the file's native resolution.
                // The panels can't display more than that, so forcing the 2x
                // backing-store size just upscaled then downscaled — pure waste.
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                opacity: (imageContainer.activeSlot === 1 && status === Image.Ready) ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: Sync.crossfadeMs; easing.type: Easing.InOutQuad } }
                onStatusChanged: root._slotFinished(1, status)
            }
        }
    }
}
