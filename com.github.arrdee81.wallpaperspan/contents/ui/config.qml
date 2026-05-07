/*
 *  Wallpaper Span - Configuration UI
 *  Copyright (C) 2026 Arrdee81
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: configRoot

    // These properties are provided by Plasma's config system, bound to
    // entries declared in main.xml.
    property alias cfg_FolderPath: folderPathField.text
    property int cfg_ShuffleInterval: 15
    property bool cfg_ShuffleEnabled: true
    property string cfg_CurrentImage: ""

    spacing: Kirigami.Units.largeSpacing

    // ── Title ───────────────────────────────────────────────────────────
    Kirigami.Heading {
        text: "Wallpaper Span"
        level: 2
        Layout.bottomMargin: Kirigami.Units.smallSpacing
    }

    // ── Folder selection ────────────────────────────────────────────────
    Kirigami.FormLayout {
        Layout.fillWidth: true

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

        // Shuffle toggle
        QQC2.CheckBox {
            id: shuffleEnabledCheck
            Kirigami.FormData.label: "Shuffle:"
            text: "Automatically change wallpaper"
            checked: cfg_ShuffleEnabled
            onCheckedChanged: cfg_ShuffleEnabled = checked
        }

        // Interval selector
        RowLayout {
            Kirigami.FormData.label: "Change every:"
            enabled: shuffleEnabledCheck.checked
            spacing: Kirigami.Units.smallSpacing

            QQC2.SpinBox {
                id: intervalSpinBox
                from: 1
                to: 480
                value: cfg_ShuffleInterval
                onValueChanged: cfg_ShuffleInterval = value

                textFromValue: function(value) {
                    if (value < 60) return value + " min"
                    const hours = Math.floor(value / 60)
                    const mins = value % 60
                    return mins === 0 ? hours + " hr"
                                      : hours + " hr " + mins + " min"
                }
            }

            QQC2.Button {
                text: "5m"; flat: true
                onClicked: intervalSpinBox.value = 5
                highlighted: intervalSpinBox.value === 5
            }
            QQC2.Button {
                text: "15m"; flat: true
                onClicked: intervalSpinBox.value = 15
                highlighted: intervalSpinBox.value === 15
            }
            QQC2.Button {
                text: "30m"; flat: true
                onClicked: intervalSpinBox.value = 30
                highlighted: intervalSpinBox.value === 30
            }
            QQC2.Button {
                text: "1h"; flat: true
                onClicked: intervalSpinBox.value = 60
                highlighted: intervalSpinBox.value === 60
            }
            QQC2.Button {
                text: "2h"; flat: true
                onClicked: intervalSpinBox.value = 120
                highlighted: intervalSpinBox.value === 120
            }
        }

        // Next Wallpaper button
        QQC2.Button {
            Kirigami.FormData.label: "Manual:"
            icon.name: "media-skip-forward"
            text: "Next Wallpaper"
            enabled: cfg_FolderPath !== ""
            onClicked: {
                if (wallpaper) wallpaper.nextWallpaper()
            }
        }

        // Current image info — bound directly to the live config value, no
        // custom signal plumbing needed.
        QQC2.Label {
            Kirigami.FormData.label: "Current:"
            text: {
                if (!cfg_CurrentImage) return "None selected"
                // cfg_CurrentImage is a file:// URL string; pull the basename.
                const s = cfg_CurrentImage.toString()
                const idx = s.lastIndexOf("/")
                return idx >= 0 ? decodeURIComponent(s.substring(idx + 1)) : s
            }
            elide: Text.ElideMiddle
            Layout.fillWidth: true
            opacity: 0.7
        }
    }

    // ── Preview of current image ────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        // Compute aspect from actual screen geometry rather than hardcoded
        // 7680×2160. Spans two equal-width screens horizontally.
        Layout.preferredHeight: width * (Screen.height / (Screen.width * 2))
        Layout.topMargin: Kirigami.Units.largeSpacing
        color: Kirigami.Theme.backgroundColor
        radius: Kirigami.Units.cornerRadius
        clip: true

        Image {
            id: previewImage
            anchors.fill: parent
            anchors.margins: 1
            // cfg_CurrentImage is already a file:// URL — feed Image directly.
            source: cfg_CurrentImage
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
            cache: false
            // Cap decode size for the preview.
            sourceSize: Qt.size(width * Screen.devicePixelRatio,
                                height * Screen.devicePixelRatio)

            // Center split indicator
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

    // ── Info label ──────────────────────────────────────────────────────
    QQC2.Label {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        text: "Place wide images (sized to your combined screen width) in the chosen folder. The plugin splits each across both monitors."
        wrapMode: Text.WordWrap
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        opacity: 0.6
    }

    // Spacer to push everything to the top
    Item { Layout.fillHeight: true }

    // ── Folder picker dialog ────────────────────────────────────────────
    FolderDialog {
        id: folderDialog
        title: "Choose Wallpaper Folder"
        currentFolder: cfg_FolderPath
            ? "file://" + cfg_FolderPath
            : StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        onAccepted: {
            // FolderDialog returns a URL like "file:///home/..." — strip and
            // decode for plain-path storage in config.
            let path = selectedFolder.toString()
            if (path.startsWith("file://")) path = path.substring(7)
            cfg_FolderPath = decodeURIComponent(path)
        }
    }
}
