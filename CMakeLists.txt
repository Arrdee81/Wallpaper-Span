cmake_minimum_required(VERSION 3.16)
project(wallpaperspan)

set(QT_MIN_VERSION "6.6.0")
set(KF6_MIN_VERSION "6.0.0")

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

find_package(Qt6 ${QT_MIN_VERSION} CONFIG REQUIRED COMPONENTS
    Core
    Qml
)

# Force user-local installation paths (no sudo required)
# Override KDEInstallDirs defaults to install to ~/.local
set(KDE_INSTALL_QMLDIR "${CMAKE_INSTALL_PREFIX}/lib/qt6/qml" CACHE PATH "QML install dir" FORCE)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(wallpaperspan_sync SHARED
    src/wallpapersync.cpp
)

target_link_libraries(wallpaperspan_sync
    Qt6::Core
    Qt6::Qml
)

install(TARGETS wallpaperspan_sync DESTINATION ${KDE_INSTALL_QMLDIR}/org/kde/plasma/wallpaper/span)
install(FILES src/qmldir DESTINATION ${KDE_INSTALL_QMLDIR}/org/kde/plasma/wallpaper/span)
