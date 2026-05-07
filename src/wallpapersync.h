#ifndef WALLPAPERSYNC_H
#define WALLPAPERSYNC_H

#include <QObject>
#include <QString>
#include <qqmlregistration.h>

class WallpaperSync : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(WallpaperSync)
    QML_SINGLETON
    Q_PROPERTY(QString currentImage READ currentImage WRITE setCurrentImage NOTIFY currentImageChanged)

public:
    explicit WallpaperSync(QObject *parent = nullptr) : QObject(parent) {}
    QString currentImage() const { return m_currentImage; }
    void setCurrentImage(const QString &image) {
        if (m_currentImage == image) return;
        m_currentImage = image;
        Q_EMIT currentImageChanged();
    }

Q_SIGNALS:
    void currentImageChanged();

private:
    QString m_currentImage;
};
#endif
