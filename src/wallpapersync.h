/*
 *  Wallpaper Span - In-process sync singleton
 *  Copyright (C) 2026 Arrdee81
 *  SPDX-License-Identifier: GPL-3.0-or-later
 *
 *  Both monitors' WallpaperItem instances live in the same plasmashell
 *  process and share the same QQmlEngine. This class is registered as a
 *  QML singleton so both instances bind to the same object — the leader
 *  (left monitor) writes currentImage, the follower (right monitor) gets
 *  a Qt signal. No file I/O, no QFileSystemWatcher, no race conditions.
 */

#ifndef WALLPAPERSYNC_H
#define WALLPAPERSYNC_H

#include <QObject>
#include <QString>

class WallpaperSync : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentImage READ currentImage WRITE setCurrentImage NOTIFY currentImageChanged)

public:
    explicit WallpaperSync(QObject *parent = nullptr);

    QString currentImage() const;
    void setCurrentImage(const QString &image);

Q_SIGNALS:
    void currentImageChanged();

private:
    QString m_currentImage;
};

#endif // WALLPAPERSYNC_H
