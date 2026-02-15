#include "wallpapersync.h"
#include <QFile>
#include <QTextStream>
#include <QStandardPaths>
#include <QDir>
#include <QQmlEngine>

WallpaperSync::WallpaperSync(QObject *parent)
    : QObject(parent)
    , m_watcher(new QFileSystemWatcher(this))
{
    // Use cache location for sync file
    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    if (!QDir().mkpath(cacheDir)) {
        qWarning() << "WallpaperSync: Failed to create cache directory:" << cacheDir;
    }
    m_syncFilePath = cacheDir + QStringLiteral("/wallpaper-span.sync");
    
    // Watch for file changes (file doesn't need to exist yet)
    if (!m_watcher->addPath(m_syncFilePath)) {
        // This is normal if file doesn't exist yet - watcher will start working once file is created
        qDebug() << "WallpaperSync: File watcher will activate when sync file is created:" << m_syncFilePath;
    }
    connect(m_watcher, &QFileSystemWatcher::fileChanged, this, &WallpaperSync::onFileChanged);
    
    // Read initial value if file exists
    readFromFile();
}

QString WallpaperSync::currentImage() const
{
    return m_currentImage;
}

void WallpaperSync::setCurrentImage(const QString &image)
{
    if (m_currentImage != image) {
        m_currentImage = image;
        writeToFile();
        Q_EMIT currentImageChanged();
    }
}

void WallpaperSync::onFileChanged(const QString &path)
{
    Q_UNUSED(path);
    readFromFile();
    
    // Re-add path because QFileSystemWatcher stops watching after file changes
    if (!m_watcher->files().contains(m_syncFilePath)) {
        if (!m_watcher->addPath(m_syncFilePath)) {
            qWarning() << "WallpaperSync: Failed to re-add file watcher path:" << m_syncFilePath;
        }
    }
}

void WallpaperSync::readFromFile()
{
    QFile file(m_syncFilePath);
    if (!file.exists()) {
        // File doesn't exist yet - this is normal on first run
        return;
    }
    
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "WallpaperSync: Failed to open sync file for reading:" << m_syncFilePath 
                   << "Error:" << file.errorString();
        return;
    }
    
    QTextStream in(&file);
    QString newImage = in.readLine().trimmed();
    
    if (!newImage.isEmpty() && newImage != m_currentImage) {
        m_currentImage = newImage;
        Q_EMIT currentImageChanged();
    }
    
    file.close();
}

void WallpaperSync::writeToFile()
{
    QFile file(m_syncFilePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "WallpaperSync: Failed to open sync file for writing:" << m_syncFilePath
                   << "Error:" << file.errorString();
        return;
    }
    
    QTextStream out(&file);
    out << m_currentImage;
    
    if (out.status() != QTextStream::Ok) {
        qWarning() << "WallpaperSync: Error writing to sync file";
    }
    
    file.close();
    
    // Ensure file watcher is still watching (in case it was removed)
    if (!m_watcher->files().contains(m_syncFilePath)) {
        m_watcher->addPath(m_syncFilePath);
    }
}

// QML plugin registration
#include <QQmlExtensionPlugin>

class WallpaperSpanPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface")
    
public:
    void registerTypes(const char *uri) override
    {
        Q_ASSERT(QLatin1String(uri) == QLatin1String("org.kde.plasma.wallpaper.span"));
        qmlRegisterType<WallpaperSync>(uri, 1, 0, "WallpaperSync");
    }
};

#include "wallpapersync.moc"
