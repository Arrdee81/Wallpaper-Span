#ifndef WALLPAPERSYNC_H
#define WALLPAPERSYNC_H

#include <QObject>
#include <QFileSystemWatcher>
#include <QString>
#include <qqmlregistration.h>

class WallpaperSync : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString currentImage READ currentImage WRITE setCurrentImage NOTIFY currentImageChanged)
    
public:
    explicit WallpaperSync(QObject *parent = nullptr);
    
    QString currentImage() const;
    void setCurrentImage(const QString &image);
    
Q_SIGNALS:
    void currentImageChanged();
    
private Q_SLOTS:
    void onFileChanged(const QString &path);
    
private:
    void readFromFile();
    void writeToFile();
    
    QString m_currentImage;
    QString m_syncFilePath;
    QFileSystemWatcher *m_watcher;
};

#endif // WALLPAPERSYNC_H
