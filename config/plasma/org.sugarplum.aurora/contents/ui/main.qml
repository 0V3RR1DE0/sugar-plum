import QtQuick
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.wallpapers.image as PlasmaWallpaper
import org.kde.kwindowsystem
import org.kde.taskmanager as TaskManager
import org.sugarplum.cursor 1.0

WallpaperItem {
    id: wallpaper

    readonly property string style: (configuration.Style || "dusk").toString()
    readonly property real speed: configuration.Speed !== undefined ? configuration.Speed : 1.0
    readonly property real intensity: configuration.Intensity !== undefined ? configuration.Intensity : 1.0
    readonly property bool showStars: configuration.Stars !== undefined ? configuration.Stars : true
    readonly property bool pauseOnCover: configuration.PauseOnCover !== undefined ? configuration.PauseOnCover : true
    readonly property rect desktopRect: Window.window
        ? Qt.rect(Window.window.x, Window.window.y, Window.window.width, Window.window.height)
        : Qt.rect(0, 0, 0, 0)
    readonly property bool paused: pauseOnCover
        && (activeWindowMonitor.count > 0 || coverage > 0.8)
        && !KWindowSystem.showingDesktop

    property real phase: 0
    property real coverage: 0

    contextualActions: [
        PlasmaCore.Action {
            text: wallpaper.style === "silk" ? "Switch to Quiet Dusk" : "Switch to Silk Ribbons"
            icon.name: "preferences-desktop-wallpaper"
            onTriggered: wallpaper.configuration.Style = wallpaper.style === "silk" ? "dusk" : "silk"
        }
    ]

    CursorTracker {
        id: cursor
        tracking: !wallpaper.paused
    }

    PlasmaWallpaper.MaximizedWindowMonitor {
        id: activeWindowMonitor
        regionGeometry: wallpaper.desktopRect
    }

    TaskManager.TasksModel {
        id: windows
        filterByScreen: true
        filterByCurrentVirtualDesktop: true
        filterByActivity: true
    }

    Timer {
        interval: 500
        repeat: true
        running: wallpaper.pauseOnCover
        onTriggered: wallpaper.updateCoverage()
    }

    Timer {
        interval: 16
        repeat: true
        running: !wallpaper.paused && wallpaper.visible
        onTriggered: wallpaper.phase += 0.016 * wallpaper.speed
    }

    ShaderEffect {
        anchors.fill: parent
        fragmentShader: "shader.frag.qsb"
        property real phase: wallpaper.phase
        property vector2d pointer: Qt.vector2d(cursor.position.x, cursor.position.y)
        property vector2d resolution: Qt.vector2d(width, height)
        property int style: wallpaper.style === "silk" ? 1 : 0
        property real intensity: wallpaper.intensity
        property real stars: wallpaper.showStars ? 1.0 : 0.0
    }

    function updateCoverage() {
        var sw = width
        var sh = height
        if (sw <= 0 || sh <= 0) {
            return
        }

        var area = 0
        for (var i = 0; i < windows.count; ++i) {
            var idx = windows.index(i, 0)
            if (windows.data(idx, TaskManager.TasksModel.IsMinimized)
                    || windows.data(idx, TaskManager.TasksModel.IsHidden)) {
                continue
            }
            var g = windows.data(idx, TaskManager.TasksModel.Geometry)
            if (!g || g.width <= 0 || g.height <= 0) {
                continue
            }
            var x1 = Math.max(0, g.x)
            var y1 = Math.max(0, g.y)
            var x2 = Math.min(sw, g.x + g.width)
            var y2 = Math.min(sh, g.y + g.height)
            if (x2 > x1 && y2 > y1) {
                area += (x2 - x1) * (y2 - y1)
            }
        }
        coverage = Math.min(1, area / (sw * sh))
    }
}
