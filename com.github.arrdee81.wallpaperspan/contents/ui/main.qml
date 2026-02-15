/*
 *  Wallpaper Span - KDE Plasma 6 Wallpaper Plugin
 *  Copyright (C) 2026 Arrdee81
 *
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Controls as QQC2
import QtCore
import Qt.labs.folderlistmodel
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.wallpaper.span 1.0

WallpaperItem {
    id: root

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
    
    // ── C++ Sync Plugin ─────────────────────────────────────
    WallpaperSync {
        id: sync
        
        Component.onCompleted: {
            console.log("WallpaperSync plugin loaded successfully");
            console.log("Sync file path:", sync.currentImage);
        }
        
        onCurrentImageChanged: {
            console.log("Sync file changed:", sync.currentImage, "shouldRunTimer:", shouldRunTimer);
            // Right monitor receives updates from left via file watcher
            if (!shouldRunTimer && sync.currentImage !== root.displayImage) {
                root.displayImage = sync.currentImage;
                wallpaper.configuration.CurrentImage = sync.currentImage;
                console.log("Right monitor: Updated to", sync.currentImage);
            }
        }
    }
    
    // Left monitor writes to sync (C++ handles file I/O)
    function writeSyncFile(imagePath) {
        sync.currentImage = imagePath;
    }

    // ── Detect which monitor we're on ───────────────────────
    function detectScreenSide() {
        myScreenX = Screen.virtualX;
        if (myScreenX === undefined) {
            myScreenX = root.mapToGlobal(0, 0).x;
        }

        console.log("=== Screen Detection ===");
        console.log("Screen.virtualX:", Screen.virtualX);
        console.log("myScreenX:", myScreenX);
        console.log("Screen.name:", Screen.name);
        console.log("Screen.geometry:", Screen.desktopAvailableWidth, "x", Screen.desktopAvailableHeight);
        
        // Detect if this is the leftmost screen by checking if at virtual desktop origin
        // This works regardless of monitor size, resolution, or scaling
        screenSide = (myScreenX === 0) ? "left" : "right";
        shouldRunTimer = (screenSide === "left");
        
        console.log("Detected side:", screenSide);
        console.log("Should run timer:", shouldRunTimer);
        console.log("========================");
    }

    // ── Image file scanning ─────────────────────────────────
    FolderListModel {
        id: folderModel
        folder: root.folderPath ? "file://" + root.folderPath : ""
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.webp",
                      "*.JPG", "*.JPEG", "*.PNG", "*.BMP", "*.WEBP"]
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

        // Only left monitor picks initial image
        if (imageList.length > 0 && shouldRunTimer) {
            pickNextImage();
        }
        // Right monitor receives updates via C++ file watcher
    }

    // ── Shuffle logic ───────────────────────────────────────
    function pickNextImage() {
        if (!shouldRunTimer) return;
        if (imageList.length === 0) return;

        if (imageList.length === 1) {
            root.displayImage = imageList[0];
            writeSyncFile(imageList[0]);
            wallpaper.configuration.CurrentImage = imageList[0];
            return;
        }

        // Reset bag when all images have been shown
        if (shuffleHistory.length >= imageList.length) {
            shuffleHistory = [];
        }

        // Build available list in single pass (more efficient than multiple filters)
        var available = [];
        for (var i = 0; i < imageList.length; i++) {
            var img = imageList[i];
            // Skip if already shown in current round or is current image
            if (shuffleHistory.indexOf(img) === -1 && img !== root.displayImage) {
                available.push(img);
            }
        }

        // If no images available (shouldn't happen, but handle gracefully)
        if (available.length === 0) {
            shuffleHistory = [];
            available = imageList.slice();
        }

        var randomIndex = Math.floor(Math.random() * available.length);
        var picked = available[randomIndex];

        shuffleHistory.push(picked);
        root.displayImage = picked;
        writeSyncFile(picked);
        wallpaper.configuration.CurrentImage = picked;
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
        
        // Right monitor: load current sync file immediately
        if (!shouldRunTimer && sync.currentImage) {
            console.log("Right monitor: Loading initial sync image:", sync.currentImage);
            root.displayImage = sync.currentImage;
            wallpaper.configuration.CurrentImage = sync.currentImage;
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

        Item {
            anchors.fill: parent
            clip: true

            Image {
                id: wallpaperImage

                x: root.screenSide === "left" ? 0 : -width / 2
                y: 0

                width: parent.width * 2
                height: parent.height

                source: root.displayImage ? "file://" + root.displayImage : ""

                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false

                opacity: status === Image.Ready ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }

    // ── Public function for config UI "Next" button ─────────
    function nextWallpaper() {
        if (shouldRunTimer) {
            pickNextImage();
            if (shuffleTimer.running) {
                shuffleTimer.restart();
            }
        }
    }
}
