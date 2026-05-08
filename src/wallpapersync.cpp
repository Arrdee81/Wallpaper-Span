#include "wallpapersync.h"

#include <QQmlEngine>
#include <QQmlExtensionPlugin>
#include <QJSEngine>

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
    if (m_currentImage != image) {
        m_currentImage = image;
        Q_EMIT currentImageChanged();
    }
}

// QML plugin registration. Singleton type — one instance per QQmlEngine.
// Plasma's SharedQmlEngine reuses one QQmlEngine for the whole process via
// a static weak_ptr, so this is effectively one instance for the entire
// plasmashell, shared across both monitors' WallpaperItems.
class WallpaperSpanPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface")

public:
    void registerTypes(const char *uri) override
    {
        Q_ASSERT(QLatin1String(uri) == QLatin1String("org.kde.plasma.wallpaper.span"));
        qmlRegisterSingletonType<WallpaperSync>(uri, 1, 0, "WallpaperSync",
            [](QQmlEngine *engine, QJSEngine *) -> QObject * {
                Q_UNUSED(engine);
                return new WallpaperSync();
            });
    }
};

#include "wallpapersync.moc"
