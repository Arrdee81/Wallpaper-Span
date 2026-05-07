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

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# KDEInstallDirs already resolves KDE_INSTALL_QMLDIR correctly when
# CMAKE_INSTALL_PREFIX is set (e.g. ~/.local). No manual override needed.

add_library(wallpaperspan_sync SHARED
    src/wallpapersync.cpp
)

target_link_libraries(wallpaperspan_sync
    Qt6::Core
    Qt6::Qml
)

install(TARGETS wallpaperspan_sync
        DESTINATION ${KDE_INSTALL_QMLDIR}/org/kde/plasma/wallpaper/span)
install(FILES src/qmldir
        DESTINATION ${KDE_INSTALL_QMLDIR}/org/kde/plasma/wallpaper/span)
