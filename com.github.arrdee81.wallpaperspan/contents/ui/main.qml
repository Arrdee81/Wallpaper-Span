/*
 *  Wallpaper Span - KDE Plasma 6 Wallpaper Plugin
 *  Copyright (C) 2026 Arrdee81
 *
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtCore
import Qt.labs.folderlistmodel
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.wallpaper.span 1.0

WallpaperItem {
    id: root

    // ── Signal for config UI ────────────────────────────────
    signal imageChanged(string newImage)

    // ── Right-click desktop menu entry ──────────────────────
    // contextualActions on a WallpaperItem populates the desktop's
    // right-click menu with custom entries — same mechanism the stock
    // Slideshow wallpaper uses for its "Next Image" action.
    contextualActions: [nextWallpaperAction]

    PlasmaCore.Action {
        id: nextWallpaperAction
        text: "Next Wallpaper"
        icon.name: "media-skip-forward"
        onTriggered: root.nextWallpaper()
    }

    // ── Configuration bindings ──────────────────────────────
    property string folderPath: wallpaper.configuration.FolderPath ?? ""
    property int shuffleInterval: wallpaper.configuration.ShuffleInterval ?? 15
    property bool shuffleEnabled: wallpaper.configuration.ShuffleEnabled ?? true

    // ── Internal state ──────────────────────────────────────
    property var imageList: []
    property var shuffleHistory: []
    property string screenSide: "unknown"
    property int myScreenX: 0
    property bool shouldRunTimer: false
    property string displayImage: ""

    // ── Cross-monitor IPC via C++ QML singleton ─────────────
    // WallpaperSync is registered as a QML singleton in the plugin. Plasma
    // shares one QQmlEngine per process across all wallpaper items, so this
    // singleton has one instance — both monitors' Connections handlers
    // below fire synchronously on the same property write.
    //
    // Both monitors set their displayImage from this handler (not in
    // pickAndPublish) so the publisher and follower hit Image source
    // assignment within the same emit cycle, eliminating the head start
    // the publisher would otherwise get on the image-decode worker queue.
    Connections {
        target: WallpaperSync
        function onCurrentImageChanged() {
            if (WallpaperSync.currentImage &&
                WallpaperSync.currentImage !== root.displayImage) {
                root.displayImage = WallpaperSync.currentImage;
                wallpaper.configuration.CurrentImage = WallpaperSync.currentImage;
                imageChanged(WallpaperSync.currentImage);
            }
        }
    }

    function publish(imagePath) {
        WallpaperSync.currentImage = imagePath;
    }

    // ── Detect which monitor we're on ───────────────────────
    function detectScreenSide() {
        myScreenX = Screen.virtualX;
        if (myScreenX === undefined) {
            myScreenX = root.mapToGlobal(0, 0).x;
        }

        if (myScreenX < 1000) {
            screenSide = "left";
            shouldRunTimer = true;
        } else {
            screenSide = "right";
            shouldRunTimer = false;
        }
    }

    // ── Image file scanning ─────────────────────────────────
    FolderListModel {
        id: folderModel
        folder: root.folderPath ? "file://" + root.folderPath : ""
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.webp"]
        caseSensitive: false
        showDirs: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name

        onStatusChanged: {
            if (status === FolderListModel.Ready) {
                rebuildImageList();
            }
        }
    }

    function rebuildImageList() {
        var list = [];
        for (var i = 0; i < folderModel.count; i++) {
            var fileUrl = folderModel.get(i, "fileUrl");
            if (fileUrl) {
                var path = fileUrl.toString();
                if (path.startsWith("file://")) {
                    path = path.substring(7);
                }
                list.push(path);
            }
        }
        imageList = list;

        // Only the leader picks an initial image; the follower picks it up
        // through the singleton.
        if (imageList.length > 0 && shouldRunTimer) {
            pickNextImage();
        }
    }

    // ── Shuffle logic ───────────────────────────────────────
    function pickNextImage() {
        if (!shouldRunTimer) return;
        pickAndPublish();
    }

    // Picks an image and publishes it via the singleton. Both monitors'
    // Connections handlers fire synchronously inside publish() and set
    // their own displayImage — we deliberately don't set it here, so the
    // publisher doesn't get a head start over the follower on the image
    // decode worker queue.
    function pickAndPublish() {
        if (imageList.length === 0) return;

        if (imageList.length === 1) {
            publish(imageList[0]);
            return;
        }

        if (shuffleHistory.length >= imageList.length) {
            shuffleHistory = [];
        }

        var available = imageList.filter(function(img) {
            return shuffleHistory.indexOf(img) === -1;
        });

        if (available.length > 1) {
            available = available.filter(function(img) {
                return img !== root.displayImage;
            });
        }

        if (available.length === 0) {
            shuffleHistory = [];
            available = imageList.slice();
        }

        var randomIndex = Math.floor(Math.random() * available.length);
        var picked = available[randomIndex];

        shuffleHistory.push(picked);
        publish(picked);
    }

    // ── Shuffle timer ───────────────────────────────────────
    Timer {
        id: shuffleTimer
        interval: root.shuffleInterval * 60 * 1000
        running: root.shuffleEnabled && root.imageList.length > 1 && root.shouldRunTimer
        repeat: true
        onTriggered: root.pickNextImage()
    }

    // ── React to config changes ─────────────────────────────
    onFolderPathChanged: {
        shuffleHistory = [];
        Qt.callLater(rebuildImageList);
    }

    onShuffleIntervalChanged: {
        if (shuffleTimer.running) {
            shuffleTimer.restart();
        }
    }

    // ── Startup ─────────────────────────────────────────────
    Component.onCompleted: {
        detectScreenSide();

        // Symmetric cold-start: read this monitor's saved image and seed
        // the singleton if it's empty. Both monitors do the same thing;
        // the singleton's setter dedupes when values match. The Connections
        // handler above is what actually populates displayImage.
        var saved = wallpaper.configuration.CurrentImage || "";
        if (WallpaperSync.currentImage) {
            // Other monitor already published; sync up if our handler didn't
            // catch the emit (e.g. our QML wasn't fully constructed yet).
            if (WallpaperSync.currentImage !== root.displayImage) {
                root.displayImage = WallpaperSync.currentImage;
                wallpaper.configuration.CurrentImage = WallpaperSync.currentImage;
            }
        } else if (saved) {
            publish(saved);
        }

        Qt.callLater(function() {
            if (folderModel.count > 0) {
                rebuildImageList();
            }
        });
    }

    // ── The actual wallpaper display ────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "black"

        // Crossfade slot machine. Two stacked Image elements take turns
        // being the visible one. When `displayImage` changes, the inactive
        // slot starts decoding the new image in the background while the
        // active slot keeps showing the current one. As soon as the
        // inactive slot reports Ready, we flip `activeSlot` — both
        // opacities animate to their new targets simultaneously, producing
        // a smooth crossfade with no fade-through-black gap.
        Item {
            id: imageContainer
            anchors.fill: parent
            clip: true

            property int activeSlot: 0
            readonly property int crossfadeMs: 800

            function loadIntoInactive(path) {
                var inactive = (activeSlot === 0) ? slot1 : slot0;
                inactive.source = path ? "file://" + path : "";
            }

            // Slot 0
            Image {
                id: slot0

                // Explicit positioning, NO anchors.fill: anchors would
                // override the explicit width and break the spanning trick.
                x: root.screenSide === "left" ? 0 : -width / 2
                y: 0

                width: parent.width * 2
                height: parent.height

                sourceSize: Qt.size(width * Screen.devicePixelRatio,
                                    height * Screen.devicePixelRatio)

                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true

                opacity: (imageContainer.activeSlot === 0 && status === Image.Ready) ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: imageContainer.crossfadeMs
                        easing.type: Easing.InOutQuad
                    }
                }

                onStatusChanged: {
                    // When this slot's load completes and it's currently
                    // the inactive one, promote it — the binding above
                    // recalculates and the crossfade animation kicks off.
                    if (status === Image.Ready && imageContainer.activeSlot !== 0) {
                        imageContainer.activeSlot = 0;
                    }
                }
            }

            // Slot 1
            Image {
                id: slot1

                x: root.screenSide === "left" ? 0 : -width / 2
                y: 0

                width: parent.width * 2
                height: parent.height

                sourceSize: Qt.size(width * Screen.devicePixelRatio,
                                    height * Screen.devicePixelRatio)

                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true

                opacity: (imageContainer.activeSlot === 1 && status === Image.Ready) ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: imageContainer.crossfadeMs
                        easing.type: Easing.InOutQuad
                    }
                }

                onStatusChanged: {
                    if (status === Image.Ready && imageContainer.activeSlot !== 1) {
                        imageContainer.activeSlot = 1;
                    }
                }
            }
        }

    }

    // Whenever the singleton hands us a new image, kick off the load on
    // the inactive crossfade slot. The opacity animations only start
    // after the new image is actually decoded — so there's never a
    // black moment between the old and new wallpaper.
    onDisplayImageChanged: {
        imageContainer.loadIntoInactive(displayImage);
    }

    // ── Public function for config UI "Next" button ─────────
    // Works from either monitor's config dialog. The picked image goes
    // through the singleton so both monitors update inside one synchronous
    // emit cycle.
    function nextWallpaper() {
        pickAndPublish();
        if (shuffleTimer.running) {
            shuffleTimer.restart();
        }
    }
}
