pragma Singleton

/*
 *  Wallpaper Span — shared coordination singleton (pure QML, no C++).
 *  Copyright (C) 2026 Arrdee81
 *  SPDX-License-Identifier: GPL-3.0-or-later
 *
 *  ── Why this is one shared object across every monitor ──────────────────
 *  Plasma runs ONE QQmlEngine for the whole plasmashell process, and a QML
 *  `pragma Singleton` is instantiated once per engine. So every monitor's
 *  WallpaperItem (main.qml) that does `import "lib"` sees THIS SAME object.
 *  That is the entire sync mechanism — no IPC, no file watcher, no C++ plugin.
 *  (Implicit same-dir qmldir is NOT auto-loaded — QTBUG-34418 — which is why
 *  main.qml imports this as an explicit directory module: `import "lib"`.)
 *
 *  ── Responsibilities (the "brain") ─────────────────────────────────────
 *  Scan the folder, own shuffle/sequential picking + history, own the change
 *  Timer, and run the flip-barrier + prefetch protocol. Monitors are pure
 *  views: they decode what we ask, report when ready, and flip when told.
 *
 *  ── Flip barrier (the load-bearing guarantee) ──────────────────────────
 *  A change is staged to all monitors as one "generation". Each monitor
 *  decodes it and calls reportReady(gen). Only when EVERY registered monitor
 *  has reported do we emit flipNow(gen) — a single synchronous signal both
 *  monitors handle in the same emit, so their crossfades start on the same
 *  frame. Prefetch means the next image is already decoded before the timer
 *  fires, so the flip has zero decode in its critical path.
 */

import QtQuick
import Qt.labs.folderlistmodel

QtObject {
    id: bus

    // ─── Config — mirrored in from each monitor's Plasma config ──────────
    property string folderPath: ""
    property bool   shuffleEnabled: true
    property string mode: "shuffle"          // "shuffle" | "sequential"
    property int    intervalSeconds: 900    // 10 … 21600 (6 h)
    property int    crossfadeMs: 800

    // ─── Image inventory ────────────────────────────────────────────────
    property var imageList: []

    // ─── Picking state ──────────────────────────────────────────────────
    property var  _history: []               // "show each once" for shuffle
    property int  _seqIndex: -1              // cursor for sequential mode
    property bool _seeded: false

    // ─── What's shown / in flight ───────────────────────────────────────
    property string currentImage: ""         // generation `gen` (on screen)
    property string pendingImage: ""         // generation `pendingGen` (decoding)
    property int    gen: 0
    property int    pendingGen: 0

    // ─── Monitor registry + barrier bookkeeping ─────────────────────────
    property int  monitorCount: 0
    property var  _readyCount: ({})           // String(gen) -> # monitors ready
    property bool _flipArmed: false           // timer/Next wants pendingGen shown

    signal requestImage(string path, int forGen)  // monitors: decode this
    signal flipNow(int forGen)                     // monitors: crossfade NOW

    // ── Monitor lifecycle ───────────────────────────────────────────────
    function registerMonitor() {
        monitorCount++;
        // Pull the newcomer into any in-flight generation — armed transition
        // OR background prefetch. Without this, a monitor registering during
        // an unarmed prefetch never receives requestImage, never decodes, and
        // shows black when that generation later flips. The re-emit is safe:
        // monitors already holding the image report immediately (idempotent).
        if (pendingImage && pendingGen > gen)
            requestImage(pendingImage, pendingGen);
    }
    function unregisterMonitor() {
        if (monitorCount > 0) monitorCount--;
        _maybeFlip();   // a departing monitor may complete a pending barrier
    }

    // ── Folder scanning (FolderListModel lives as a property of the root) ─
    // FolderListModel watches the directory, so added/removed files update the
    // list live — no manual rescan needed.
    property FolderListModel _scanner: FolderListModel {
        folder: bus.folderPath ? "file://" + bus.folderPath : ""
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.webp"]
        caseSensitive: false
        showDirs: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        onStatusChanged: if (status === FolderListModel.Ready) bus._rebuild()
    }

    function _rebuild() {
        var list = [];
        for (var i = 0; i < _scanner.count; i++) {
            var u = _scanner.get(i, "fileUrl");
            if (!u) continue;
            var p = u.toString();
            if (p.startsWith("file://")) p = p.substring(7);
            list.push(p);
        }
        imageList = list;
        if (list.length === 0) return;

        // Already showing a still-valid image (cold-start restore or steady
        // state): keep it, just make sure the next pick is pre-decoded.
        if (currentImage && list.indexOf(currentImage) !== -1) {
            _seeded = true;
            if (!pendingImage) Qt.callLater(function() { bus._prefetch(bus._pick()); });
            return;
        }

        // No valid current image (fresh setup, or the current file vanished):
        // pick one and show it now.
        _seeded = true;
        _history = [];
        _seqIndex = -1;
        _show(_pick());
    }

    // ── Picking ─────────────────────────────────────────────────────────
    function _pick() {
        if (imageList.length === 0) return "";
        if (imageList.length === 1) return imageList[0];

        if (mode === "sequential") {
            var start = imageList.indexOf(currentImage);
            _seqIndex = ((start < 0 ? _seqIndex : start) + 1) % imageList.length;
            return imageList[_seqIndex];
        }

        // shuffle, show-each-once-before-repeating
        if (_history.length >= imageList.length) _history = [];
        var avail = imageList.filter(function(x) { return _history.indexOf(x) === -1; });
        if (avail.length > 1)
            avail = avail.filter(function(x) { return x !== currentImage; });
        if (avail.length === 0) { _history = []; avail = imageList.slice(); }
        var picked = avail[Math.floor(Math.random() * avail.length)];
        _history.push(picked);
        return picked;
    }

    // ── Change pipeline ─────────────────────────────────────────────────
    // Stage `path` as the next generation and ask every monitor to decode it.
    // arm=true  → show as soon as all monitors are ready (initial / timer / Next)
    // arm=false → background prefetch only; waits for advance() to arm it.
    function _stage(path, arm) {
        if (!path) return;
        pendingGen = gen + 1;
        pendingImage = path;
        _readyCount[String(pendingGen)] = 0;
        _flipArmed = arm;
        requestImage(path, pendingGen);
        if (arm) _timeout.restart();   // safety net only matters once armed
    }
    function _show(path)     { _stage(path, true); }
    function _prefetch(path) { _stage(path, false); }

    // Monitor → "I have generation g ready (decoded, or errored — either way
    // it must not stall the barrier)."
    function reportReady(forGen) {
        var k = String(forGen);
        _readyCount[k] = (_readyCount[k] || 0) + 1;
        _maybeFlip();
    }

    function _maybeFlip() {
        if (!_flipArmed || pendingGen === 0 || monitorCount === 0) return;
        if ((_readyCount[String(pendingGen)] || 0) >= monitorCount)
            _doFlip();
    }

    function _doFlip() {
        _timeout.stop();
        _flipArmed = false;
        delete _readyCount[String(gen)];
        gen = pendingGen;
        currentImage = pendingImage;
        flipNow(gen);                 // ← both monitors crossfade in this emit
        // Line up the next pick in the background — but only AFTER the crossfade
        // finishes. The slot we'll prefetch into is the OUTGOING one, which is
        // still visible (fading out) during the crossfade; swapping its image
        // mid-fade would show the next picture through the transition.
        _prefetchTimer.restart();
    }

    // Delay before refilling the (now-invisible) outgoing slot with the next
    // pick. Must outlast the crossfade so we never touch a slot still on screen.
    property Timer _prefetchTimer: Timer {
        interval: bus.crossfadeMs + 80
        repeat: false
        onTriggered: bus._prefetch(bus._pick())
    }

    // Timer fired or user hit Next: show the staged generation (instant if its
    // prefetch already decoded everywhere; otherwise the barrier waits for it).
    function advance() {
        if (pendingGen > gen && pendingImage) {
            _flipArmed = true;
            _timeout.restart();
            _maybeFlip();
        } else {
            _show(_pick());
        }
        _timer.restart();
    }

    // ── Change timer (single instance — no per-monitor leader election) ──
    property Timer _timer: Timer {
        interval: Math.max(10, bus.intervalSeconds) * 1000
        running: bus.shuffleEnabled && bus.imageList.length > 1
        repeat: true
        onTriggered: bus.advance()
    }

    // ── Barrier safety net: one stuck/failed decode must not freeze the
    //    other monitor forever. Flip anyway after this grace period. ────────
    property Timer _timeout: Timer {
        interval: 2500
        repeat: false
        onTriggered: if (bus._flipArmed) bus._doFlip()
    }
}
