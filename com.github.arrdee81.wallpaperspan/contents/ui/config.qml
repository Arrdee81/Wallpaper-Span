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

    // cfg_CurrentImage is a file:// URL (v2.0.1+) or a plain path (older
    // saved config). Normalize to a URL for Image, decode for display.
    readonly property string currentImageUrl:
        !cfg_CurrentImage ? ""
        : cfg_CurrentImage.indexOf("file://") === 0 ? cfg_CurrentImage
        : "file://" + encodeURI(cfg_CurrentImage).replace(/#/g, "%23").replace(/\?/g, "%3F")
    readonly property string currentImageName: {
        if (!cfg_CurrentImage) return "";
        var p = cfg_CurrentImage;
        if (p.indexOf("file://") === 0) p = decodeURIComponent(p.substring(7));
        return p.split("/").pop();
    }

    // ── Real combined-desktop geometry (same math as main.qml) ──────────
    // Drives the preview's aspect ratio and the per-bezel split markers, so
    // they reflect the actual layout instead of a hardcoded dual-4K guess.
    readonly property rect spanRect: {
        var screens = Qt.application.screens;
        if (!screens || screens.length === 0)
            return Qt.rect(0, 0, 7680, 2160);   // no screen info: dual-4K placeholder
        var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i];
            minX = Math.min(minX, s.virtualX);
            minY = Math.min(minY, s.virtualY);
            maxX = Math.max(maxX, s.virtualX + s.width);
            maxY = Math.max(maxY, s.virtualY + s.height);
        }
        return Qt.rect(minX, minY, maxX - minX, maxY - minY);
    }
    // Interior monitor boundaries as fractions of the span (0…1, exclusive):
    // one vertical marker per left edge, one horizontal per top edge.
    function _boundaryFractions(vertical) {
        var screens = Qt.application.screens;
        var fr = [];
        if (!screens || screens.length < 2) return fr;
        for (var i = 0; i < screens.length; i++) {
            var f = vertical
                ? (screens[i].virtualX - spanRect.x) / spanRect.width
                : (screens[i].virtualY - spanRect.y) / spanRect.height;
            if (f > 0.001 && f < 0.999 && fr.indexOf(f) === -1) fr.push(f);
        }
        return fr;
    }
    readonly property var splitFractionsX: _boundaryFractions(true)
    readonly property var splitFractionsY: _boundaryFractions(false)

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
        if (sec < 60) return i18n("%1 sec", sec);
        if (sec < 3600) return i18n("%1 min", Math.round(sec / 60));
        var h = Math.floor(sec / 3600), rm = Math.round((sec % 3600) / 60);
        return rm === 0 ? i18n("%1 hr", h) : i18n("%1 hr %2 min", h, rm);
    }

    spacing: Kirigami.Units.largeSpacing

    Kirigami.Heading {
        text: i18n("Wallpaper Span")
        level: 2
        Layout.bottomMargin: Kirigami.Units.smallSpacing
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true

        // ── Folder ──────────────────────────────────────────────────────
        RowLayout {
            Kirigami.FormData.label: i18n("Image folder:")
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: folderPathField
                Layout.fillWidth: true
                placeholderText: "/home/user/Wallpapers"
                readOnly: true
            }
            QQC2.Button {
                icon.name: "document-open-folder"
                text: i18n("Browse…")
                onClicked: folderDialog.open()
            }
        }

        // ── Auto-change toggle ──────────────────────────────────────────
        QQC2.CheckBox {
            id: shuffleEnabledCheck
            Kirigami.FormData.label: i18n("Auto-change:")
            text: i18n("Change wallpaper on a timer")
            checked: cfg_ShuffleEnabled
            onCheckedChanged: cfg_ShuffleEnabled = checked
        }

        // ── Order: shuffle vs sequential ────────────────────────────────
        RowLayout {
            Kirigami.FormData.label: i18n("Order:")
            enabled: shuffleEnabledCheck.checked
            spacing: Kirigami.Units.smallSpacing

            QQC2.RadioButton {
                text: i18n("Shuffle")
                checked: cfg_Mode === "shuffle"
                onToggled: if (checked) cfg_Mode = "shuffle"
            }
            QQC2.RadioButton {
                text: i18n("Sequential")
                checked: cfg_Mode === "sequential"
                onToggled: if (checked) cfg_Mode = "sequential"
            }
        }

        // ── Interval (10 s … 6 h) ───────────────────────────────────────
        RowLayout {
            Kirigami.FormData.label: i18n("Change every:")
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
            Kirigami.FormData.label: i18n("Crossfade:")
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
                text: cfg_CrossfadeMs === 0 ? i18n("instant") : i18n("%1 s", (cfg_CrossfadeMs / 1000).toFixed(1))
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                Layout.maximumWidth: Kirigami.Units.gridUnit * 6
            }
        }

        // ── Manual next ─────────────────────────────────────────────────
        QQC2.Button {
            Kirigami.FormData.label: i18n("Manual:")
            icon.name: "media-skip-forward"
            text: i18n("Next Wallpaper")
            enabled: cfg_FolderPath !== ""
            onClicked: if (wallpaper) wallpaper.nextWallpaper()
        }

        // ── Current image filename ──────────────────────────────────────
        QQC2.Label {
            Kirigami.FormData.label: i18n("Current:")
            text: currentImageName || i18n("None selected")
            elide: Text.ElideMiddle
            Layout.fillWidth: true
            opacity: 0.7
        }
    }

    // ── Preview (real span aspect, one marker per monitor boundary) ─────
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: width * (spanRect.height / spanRect.width)
        Layout.topMargin: Kirigami.Units.largeSpacing
        color: Kirigami.Theme.backgroundColor
        radius: Kirigami.Units.cornerRadius
        clip: true

        Image {
            id: previewImage
            anchors.fill: parent
            anchors.margins: 1
            source: currentImageUrl
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
            cache: false
            // Cap preview decode — no need to decode the full span here. The
            // container already has the span's aspect, so a correctly-sized
            // image fills it edge to edge and the markers land on the bezels.
            sourceSize: Qt.size(1920, Math.max(1, Math.round(1920 * spanRect.height / spanRect.width)))

            Repeater {
                model: splitFractionsX
                Rectangle {
                    x: Math.round(parent.width * modelData) - 1
                    width: 2
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    color: Kirigami.Theme.highlightColor
                    opacity: 0.6
                    visible: previewImage.status === Image.Ready
                }
            }
            Repeater {
                model: splitFractionsY
                Rectangle {
                    y: Math.round(parent.height * modelData) - 1
                    height: 2
                    anchors.left: parent.left
                    anchors.right: parent.right
                    color: Kirigami.Theme.highlightColor
                    opacity: 0.6
                    visible: previewImage.status === Image.Ready
                }
            }
        }

        QQC2.Label {
            anchors.centerIn: parent
            text: cfg_FolderPath ? i18n("No image loaded") : i18n("Select a folder to get started")
            visible: !cfg_CurrentImage
            opacity: 0.5
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        text: i18n("Place images sized to your full combined desktop (%1×%2) in the folder. Each image is split across all monitors by their real positions.",
                   spanRect.width, spanRect.height)
        wrapMode: Text.WordWrap
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        opacity: 0.6
    }

    Item { Layout.fillHeight: true }

    FolderDialog {
        id: folderDialog
        title: i18n("Choose Wallpaper Folder")
        currentFolder: cfg_FolderPath ? "file://" + cfg_FolderPath
                                      : StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        onAccepted: {
            var path = selectedFolder.toString();
            if (path.startsWith("file://")) path = path.substring(7);
            // Store/display the human-readable path; QML's tolerant string→url
            // conversion re-encodes it wherever it's used as a URL.
            cfg_FolderPath = decodeURIComponent(path);
        }
    }
}
