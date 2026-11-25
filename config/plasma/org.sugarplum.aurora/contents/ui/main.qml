import QtQuick
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.wallpapers.image as PlasmaWallpaper
import org.kde.kwindowsystem
import org.sugarplum.cursor 1.0

WallpaperItem {
    id: wallpaper

    property real phase: 0
    property real mx: cursor.position.x - 0.5
    property real my: cursor.position.y - 0.5
    readonly property bool paused: activeWindowMonitor.count > 0 && !KWindowSystem.showingDesktop
    readonly property rect desktopRect: Window.window ? Qt.rect(Window.window.x, Window.window.y, Window.window.width, Window.window.height) : Qt.rect(0, 0, 0, 0)

    readonly property var blobs: [
        { file: "blobs/pink.png",       x: 0.16, y: 0.28, size: 1.05, speed: 0.55, off: 0.0, depth: 70 },
        { file: "blobs/lilac.png",      x: 0.78, y: 0.22, size: 0.95, speed: 0.42, off: 1.7, depth: 55 },
        { file: "blobs/periwinkle.png", x: 0.58, y: 0.78, size: 1.10, speed: 0.36, off: 3.1, depth: 75 },
        { file: "blobs/mint.png",       x: 0.12, y: 0.82, size: 0.85, speed: 0.61, off: 4.4, depth: 45 },
        { file: "blobs/cream.png",      x: 0.88, y: 0.68, size: 0.70, speed: 0.48, off: 2.3, depth: 65 },
        { file: "blobs/orchid.png",     x: 0.43, y: 0.10, size: 0.80, speed: 0.33, off: 5.2, depth: 50 }
    ]

    CursorTracker {
        id: cursor
        tracking: !wallpaper.paused
    }

    PlasmaWallpaper.MaximizedWindowMonitor {
        id: activeWindowMonitor
        regionGeometry: wallpaper.desktopRect
    }

    Timer {
        interval: 33
        repeat: true
        running: !wallpaper.paused && wallpaper.visible
        onTriggered: wallpaper.phase += 0.025
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1e1e2e" }
            GradientStop { position: 0.55; color: "#181825" }
            GradientStop { position: 1.0; color: "#11111b" }
        }
    }

    Item {
        id: animatedLayer
        anchors.fill: parent
        visible: !wallpaper.paused
        clip: true

        Repeater {
            model: wallpaper.blobs
            delegate: Image {
                id: blob
                source: modelData.file
                width: parent.width * modelData.size
                height: width
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
                opacity: 0.52 + 0.14 * Math.sin(wallpaper.phase * modelData.speed + modelData.off)
                x: modelData.x * parent.width - width / 2
                   + Math.sin(wallpaper.phase * modelData.speed + modelData.off) * 70
                   + wallpaper.mx * modelData.depth
                y: modelData.y * parent.height - height / 2
                   + Math.cos(wallpaper.phase * modelData.speed * 0.8 + modelData.off) * 55
                   + wallpaper.my * modelData.depth * 0.7
                scale: 1.0 + 0.06 * Math.sin(wallpaper.phase * modelData.speed * 1.25 + modelData.off)
                transformOrigin: Item.Center
            }
        }

        Repeater {
            model: 32
            delegate: Rectangle {
                width: 2
                height: 2
                radius: 1
                color: "#f7e1b5"
                x: ((index * 73) % 100) / 100 * parent.width + Math.sin(wallpaper.phase * 0.15 + index) * 6
                y: ((index * 37) % 100) / 100 * parent.height + Math.cos(wallpaper.phase * 0.12 + index) * 5
                opacity: 0.08 + 0.18 * (0.5 + 0.5 * Math.sin(wallpaper.phase * 0.7 + index * 1.7))
            }
        }
    }
}
