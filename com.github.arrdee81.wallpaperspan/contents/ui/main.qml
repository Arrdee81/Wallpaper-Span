/*
 *  Wallpaper Span - KDE Plasma 6 Wallpaper Plugin
 *  Copyright (C) 2026 Arrdee81
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtCore
import Qt.labs.folderlistmodel
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.wallpaper.span 1.0

WallpaperItem {
    id: root

    // ── Configuration bindings ──────────────────────────────────────────
    property string folderPath: wallpaper.configuration.FolderPath ?? ""
    property int shuffleInterval: wallpaper.configuration.ShuffleInterval ?? 15
    property bool shuffleEnabled: wallpaper.configuration.ShuffleEnabled ?? true

    // ── Internal state ──────────────────────────────────────────────────
    property var imageList: []           // array of file:// URLs (strings)
    property var shuffleHistory: []      // bag tracker
    property string screenSide: "unknown"
    property bool shouldRunTimer: false
    property bool firstImageLoaded: false

    // ── In-process sync (singleton, no file I/O) ────────────────────────
    Connections {
        target: WallpaperSync
        function onCurrentImageChanged() {
            // Right monitor receives updates instantly via Qt signal
            if (!root.shouldRunTimer && WallpaperSync.currentImage) {
                stack.swapTo(WallpaperSync.currentImage)
                wallpaper.configuration.CurrentImage = WallpaperSync.currentImage
            }
        }
    }

    function publish(imgUrl) {
        WallpaperSync.currentImage = imgUrl
        wallpaper.configuration.CurrentImage = imgUrl
    }

    // ── Detect which monitor we're on, against the actual screen layout ─
    function detectScreenSide() {
        const screens = Qt.application.screens
        if (!screens || screens.length === 0) return

        const myX = root.Screen.virtualX
        let leftmostX = Number.POSITIVE_INFINITY
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].virtualX < leftmostX) leftmostX = screens[i].virtualX
        }
        screenSide = (myX === leftmostX) ? "left" : "right"
        shouldRunTimer = (screenSide === "left")
    }

    // Re-detect on layout changes (sleep/wake, hotplug, monitor reorder)
    Connections {
        target: root.Screen
        function onVirtualXChanged() { detectScreenSide() }
    }

    // ── Image scanning ──────────────────────────────────────────────────
    FolderListModel {
        id: folderModel
        folder: root.folderPath ? "file://" + root.folderPath : ""
        // Single set of filters; case-insensitive matching covers .JPG/.PNG etc.
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.webp"]
        caseSensitive: false
        showDirs: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name

        onStatusChanged: {
            if (status === FolderListModel.Ready) rebuildImageList()
        }
    }

    function rebuildImageList() {
        const list = []
        for (let i = 0; i < folderModel.count; i++) {
            const u = folderModel.get(i, "fileURL")
            if (u) list.push(u.toString())
        }
        imageList = list

        // Only the leader picks; the follower receives via the singleton.
        if (imageList.length > 0 && shouldRunTimer) {
            pickNextImage()
        }
    }

    // ── Shuffle (avoid-repeat bag) ──────────────────────────────────────
    function pickNextImage() {
        if (!shouldRunTimer) return
        if (imageList.length === 0) return

        if (imageList.length === 1) {
            publish(imageList[0])
            stack.swapTo(imageList[0])
            return
        }

        // Reset the bag once everything has been shown
        if (shuffleHistory.length >= imageList.length) {
            shuffleHistory = []
        }

        let available = imageList.filter(img => shuffleHistory.indexOf(img) === -1)

        // Avoid showing the current image twice in a row
        if (available.length > 1) {
            available = available.filter(img => img !== stack.currentSrc)
        }
        if (available.length === 0) {
            shuffleHistory = []
            available = imageList.slice()
        }

        const picked = available[Math.floor(Math.random() * available.length)]
        shuffleHistory.push(picked)
        publish(picked)
        stack.swapTo(picked)
    }

    function nextWallpaper() {
        if (shouldRunTimer) {
            pickNextImage()
            if (shuffleTimer.running) shuffleTimer.restart()
        }
    }

    Timer {
        id: shuffleTimer
        interval: root.shuffleInterval * 60 * 1000
        running: root.shuffleEnabled && root.imageList.length > 1 && root.shouldRunTimer
        repeat: true
        onTriggered: pickNextImage()
    }

    // ── React to config changes ─────────────────────────────────────────
    onFolderPathChanged: {
        shuffleHistory = []
        Qt.callLater(rebuildImageList)
    }
    onShuffleIntervalChanged: {
        if (shuffleTimer.running) shuffleTimer.restart()
    }

    // ── Right-click context action (Plasma 6 idiom) ─────────────────────
    PlasmaCore.Action {
        id: nextAction
        text: i18n("Next Wallpaper")
        icon.name: "media-skip-forward"
        onTriggered: root.nextWallpaper()
    }
    contextualActions: shouldRunTimer ? [nextAction] : []

    // ── Persist on shutdown (Plasma 6.3+ pattern, BUG: 480509) ──────────
    Connections {
        target: Qt.application
        function onAboutToQuit() {
            wallpaper.configuration.writeConfig()
        }
    }

    // ── Startup ─────────────────────────────────────────────────────────
    Component.onCompleted: {
        // Delays ksplash dismissal until the wallpaper is on-screen
        root.loading = true

        detectScreenSide()

        // Try to restore the last image immediately
        const saved = wallpaper.configuration.CurrentImage
        if (saved) {
            stack.swapTo(saved)
            // If we're the leader and have a saved image, also publish it so
            // the follower sees the same thing on cold start.
            if (shouldRunTimer) {
                WallpaperSync.currentImage = saved
            }
        }

        Qt.callLater(function() {
            if (folderModel.count > 0) rebuildImageList()
        })
    }

    // ── The crossfading display ─────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "black"

        Item {
            id: stack
            anchors.fill: parent
            clip: true

            // The most recently requested source. Displayed image is whichever
            // of imgA/imgB is currently at full opacity.
            property string currentSrc: ""
            // Which image is currently in front (true=A, false=B). Crossfade
            // is achieved by flipping this; the Behavior animates the opacities.
            property bool useA: true

            function swapTo(src) {
                if (!src || src === currentSrc) return
                currentSrc = src
                // Load into the BACK image so the front keeps showing the
                // current pixmap during the load — no black flash.
                if (useA) {
                    imgB.source = src
                } else {
                    imgA.source = src
                }
            }

            Image {
                id: imgA
                anchors.fill: parent
                x: root.screenSide === "left" ? 0 : -width / 2
                width: parent.width * 2
                height: parent.height

                // CRITICAL: bound the decoded pixmap size. Without this Qt
                // decodes the full image (e.g. 7680×2160 ≈ 63 MiB RGBA) even
                // though only half is shown. With sourceSize, libjpeg uses
                // its scaling decoder and memory is bounded.
                sourceSize: Qt.size(width * Screen.devicePixelRatio,
                                    height * Screen.devicePixelRatio)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false

                opacity: stack.useA ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
                }

                onStatusChanged: {
                    if (status === Image.Ready && !stack.useA) {
                        stack.useA = true
                        if (root.loading) root.loading = false
                        if (!root.firstImageLoaded) root.firstImageLoaded = true
                    }
                }
            }

            Image {
                id: imgB
                anchors.fill: parent
                x: root.screenSide === "left" ? 0 : -width / 2
                width: parent.width * 2
                height: parent.height

                sourceSize: Qt.size(width * Screen.devicePixelRatio,
                                    height * Screen.devicePixelRatio)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false

                opacity: stack.useA ? 0 : 1
                Behavior on opacity {
                    NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
                }

                onStatusChanged: {
                    if (status === Image.Ready && stack.useA) {
                        stack.useA = false
                        if (root.loading) root.loading = false
                        if (!root.firstImageLoaded) root.firstImageLoaded = true
                    }
                }
            }
        }
    }
}
