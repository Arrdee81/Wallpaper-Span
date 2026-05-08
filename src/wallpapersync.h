#ifndef WALLPAPERSYNC_H
#define WALLPAPERSYNC_H

#include <QObject>
#include <QString>

/*
 * In-process wallpaper image sync.
 *
 * Registered as a QML singleton (qmlRegisterSingletonType) in the plugin's
 * registerTypes(). Plasma's SharedQmlEngine holds one QQmlEngine per process
 * via a static weak_ptr, so all WallpaperItems in plasmashell share one
 * engine — meaning one singleton instance. Both monitors see the same
 * WallpaperSync object and Connections handlers fire synchronously when
 * currentImage changes, with no IPC or filesystem in the loop.
 *
 * No QML_ELEMENT macro: registration is procedural via the plugin so we
 * don't accidentally double-register if the build ever switches to
 * qt_add_qml_module.
 */
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
