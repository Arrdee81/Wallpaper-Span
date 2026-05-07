/*
 *  Wallpaper Span - In-process sync singleton
 *  Copyright (C) 2026 Arrdee81
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

#include "wallpapersync.h"
#include <QQmlEngine>
#include <QJSEngine>
#include <QQmlExtensionPlugin>

WallpaperSync::WallpaperSync(QObject *parent)
    : QObject(parent)
{
}

QString WallpaperSync::currentImage() const
{
    return m_currentImage;
}

void WallpaperSync::setCurrentImage(const QString &image)
{
    if (m_currentImage == image) {
        return;
    }
    m_currentImage = image;
    Q_EMIT currentImageChanged();
}

// QML plugin registration ----------------------------------------------------
class WallpaperSpanPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface")

public:
    void registerTypes(const char *uri) override
    {
        Q_ASSERT(QLatin1String(uri) == QLatin1String("org.kde.plasma.wallpaper.span"));
        // One instance per QQmlEngine (= one per plasmashell process).
        // Both wallpaper instances bind to this same singleton.
        qmlRegisterSingletonType<WallpaperSync>(uri, 1, 0, "WallpaperSync",
            [](QQmlEngine *, QJSEngine *) -> QObject* {
                return new WallpaperSync();
            });
    }
};

#include "wallpapersync.moc"
