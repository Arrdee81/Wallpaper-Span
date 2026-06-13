/*
 *  Wallpaper Span - Configuration UI
 *  Copyright (C) 2026 Arrdee81
 *
 *  SPDX-License-Identifier: GPL-3.0-or-later
 *
 *  Settings panel shown under right-click desktop → Configure Desktop &
 *  Wallpaper → Wallpaper Type: Wallpaper Span.
 */

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: configRoot

    // Properties Plasma 6 injects into a wallpaper config UI. Declaring them
    // silences "ColumnLayout does not have a property called …" warnings and
    // matches the stock image-wallpaper config structure.
    property var configDialog
    property var wallpaperConfiguration: wallpaper ? wallpaper.configuration : null

    // Mapped automatically to the entries in config/main.xml.
    property alias  cfg_FolderPath: folderPathField.text
    property bool   cfg_ShuffleEnabled: true
    property string cfg_Mode: "shuffle"
    property int    cfg_IntervalSeconds: 900
    property int    cfg_CrossfadeMs: 800
    property string cfg_CurrentImage: ""

    // Live "current image" updates from the running wallpaper.
    Connections {
        target: wallpaper
        function onImageChanged(newImage) { cfg_CurrentImage = newImage; }
    }

    // "Change every" slider: a smooth 0…1 position mapped log-scale to
    // 10 s … 6 h, snapped to a tidy value so the readout stays round.
    function intervalToPos(sec) {
        var s = Math.max(10, Math.min(21600, sec));
        return Math.log(s / 10) / Math.log(2160);   // 2160 = 21600/10
    }
    function posToInterval(pos) {
        var raw = 10 * Math.pow(2160, pos);
        if (raw < 60)   return Math.round(raw / 5) * 5;     // 5 s steps
        if (raw < 600)  return Math.round(raw / 15) * 15;   // 15 s steps
        if (raw < 3600) return Math.round(raw / 60) * 60;   // 1 min steps
        return Math.round(raw / 900) * 900;                 // 15 min steps
    }
    function fmtDuration(sec) {
        if (sec < 60) return sec + " sec";
        if (sec < 3600) return Math.round(sec / 60) + " min";
        var h = Math.floor(sec / 3600), rm = Math.round((sec % 3600) / 60);
        return rm === 0 ? h + " hr" : h + " hr " + rm + " min";
    }

    spacing: Kirigami.Units.largeSpacing

    Kirigami.Heading {
        text: "Wallpaper Span"
        level: 2
        Layout.bottomMargin: Kirigami.Units.smallSpacing
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true

        // ── Folder ──────────────────────────────────────────────────────
        RowLayout {
            Kirigami.FormData.label: "Image folder:"
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: folderPathField
                Layout.fillWidth: true
                placeholderText: "/home/user/Wallpapers"
                readOnly: true
            }
            QQC2.Button {
                icon.name: "document-open-folder"
                text: "Browse…"
                onClicked: folderDialog.open()
            }
        }

        // ── Auto-change toggle ──────────────────────────────────────────
        QQC2.CheckBox {
            id: shuffleEnabledCheck
            Kirigami.FormData.label: "Auto-change:"
            text: "Change wallpaper on a timer"
            checked: cfg_ShuffleEnabled
            onCheckedChanged: cfg_ShuffleEnabled = checked
        }

        // ── Order: shuffle vs sequential ────────────────────────────────
        RowLayout {
            Kirigami.FormData.label: "Order:"
            enabled: shuffleEnabledCheck.checked
            spacing: Kirigami.Units.smallSpacing

            QQC2.RadioButton {
                text: "Shuffle"
                checked: cfg_Mode === "shuffle"
                onToggled: if (checked) cfg_Mode = "shuffle"
            }
            QQC2.RadioButton {
                text: "Sequential"
                checked: cfg_Mode === "sequential"
                onToggled: if (checked) cfg_Mode = "sequential"
            }
        }

        // ── Interval (10 s … 6 h) ───────────────────────────────────────
        RowLayout {
            Kirigami.FormData.label: "Change every:"
            enabled: shuffleEnabledCheck.checked
            spacing: Kirigami.Units.largeSpacing
            Layout.fillWidth: true

            QQC2.Slider {
                id: intervalSlider
                Layout.fillWidth: true
                from: 0
                to: 1
                value: configRoot.intervalToPos(cfg_IntervalSeconds)
                onMoved: cfg_IntervalSeconds = configRoot.posToInterval(value)
            }
            QQC2.Label {
                text: configRoot.fmtDuration(cfg_IntervalSeconds)
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                Layout.maximumWidth: Kirigami.Units.gridUnit * 6
            }
        }

        // ── Crossfade duration ──────────────────────────────────────────
        RowLayout {
            Kirigami.FormData.label: "Crossfade:"
            spacing: Kirigami.Units.largeSpacing
            Layout.fillWidth: true

            QQC2.Slider {
                id: crossfadeSlider
                Layout.fillWidth: true
                from: 0
                to: 3000
                value: cfg_CrossfadeMs
                onMoved: cfg_CrossfadeMs = Math.round(value / 50) * 50
            }
            QQC2.Label {
                text: cfg_CrossfadeMs === 0 ? "instant" : (cfg_CrossfadeMs / 1000).toFixed(1) + " s"
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                Layout.maximumWidth: Kirigami.Units.gridUnit * 6
            }
        }

        // ── Manual next ─────────────────────────────────────────────────
        QQC2.Button {
            Kirigami.FormData.label: "Manual:"
            icon.name: "media-skip-forward"
            text: "Next Wallpaper"
            enabled: cfg_FolderPath !== ""
            onClicked: if (wallpaper) wallpaper.nextWallpaper()
        }

        // ── Current image filename ──────────────────────────────────────
        QQC2.Label {
            Kirigami.FormData.label: "Current:"
            text: {
                if (!cfg_CurrentImage) return "None selected";
                var parts = cfg_CurrentImage.split("/");
                return parts[parts.length - 1];
            }
            elide: Text.ElideMiddle
            Layout.fillWidth: true
            opacity: 0.7
        }
    }

    // ── Preview (full span, with center split marker) ───────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: width * (2160 / 7680)
        Layout.topMargin: Kirigami.Units.largeSpacing
        color: Kirigami.Theme.backgroundColor
        radius: Kirigami.Units.cornerRadius
        clip: true

        Image {
            id: previewImage
            anchors.fill: parent
            anchors.margins: 1
            source: cfg_CurrentImage ? "file://" + cfg_CurrentImage : ""
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
            cache: false
            // Cap preview decode — no need to decode a full 7680px image here.
            sourceSize: Qt.size(1920, 540)

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 2
                color: Kirigami.Theme.highlightColor
                opacity: 0.6
                visible: parent.status === Image.Ready
            }
        }

        QQC2.Label {
            anchors.centerIn: parent
            text: cfg_FolderPath ? "No image loaded" : "Select a folder to get started"
            visible: !cfg_CurrentImage
            opacity: 0.5
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        text: "Place images sized to your full combined desktop (e.g. 7680×2160 for two 4K monitors) in the folder. Each image is split across all monitors by their real positions."
        wrapMode: Text.WordWrap
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        opacity: 0.6
    }

    Item { Layout.fillHeight: true }

    FolderDialog {
        id: folderDialog
        title: "Choose Wallpaper Folder"
        currentFolder: cfg_FolderPath ? "file://" + cfg_FolderPath
                                      : StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        onAccepted: {
            var path = selectedFolder.toString();
            if (path.startsWith("file://")) path = path.substring(7);
            cfg_FolderPath = path;
        }
    }
}
