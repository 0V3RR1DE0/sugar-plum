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
    property real mx: cursor.position.x - 0.5
    property real my: cursor.position.y - 0.5
    property var duskStars: []
    property var silkStars: []

    contextualActions: [
        PlasmaCore.Action {
            text: wallpaper.style === "silk" ? "Switch to Quiet Dusk" : "Switch to Silk Ribbons"
            icon.name: "preferences-desktop-wallpaper"
            onTriggered: {
                wallpaper.configuration.Style = wallpaper.style === "silk" ? "dusk" : "silk"
                canvas.requestPaint()
            }
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
        interval: 33
        repeat: true
        running: !wallpaper.paused && wallpaper.visible
        onTriggered: {
            wallpaper.phase += 0.025 * wallpaper.speed
            canvas.requestPaint()
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.globalAlpha = 1
            ctx.globalCompositeOperation = "source-over"
            if (wallpaper.style === "silk") {
                wallpaper.paintSilk(ctx, width, height)
            } else {
                wallpaper.paintDusk(ctx, width, height)
            }
        }
    }

    Component.onCompleted: {
        duskStars = makeStars(34, 0xD0D)
        silkStars = makeStars(46, 0xC0C)
        canvas.requestPaint()
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

    function makeStars(count, seed) {
        var s = seed >>> 0
        var out = []
        function rnd() {
            s = (s * 1664525 + 1013904223) >>> 0
            return s / 4294967296
        }
        for (var i = 0; i < count; ++i) {
            out.push({
                x: rnd(),
                y: rnd(),
                r: 0.35 + rnd() * 1.25,
                o: 0.12 + rnd() * 0.45,
                s: 0.3 + rnd() * 1.4,
                p: rnd() * Math.PI * 2
            })
        }
        return out
    }

    function rgba(c, a) {
        return "rgba(" + c[0] + "," + c[1] + "," + c[2] + "," + a + ")"
    }

    function glow(ctx, x, y, r, c, a) {
        if (r <= 0 || a <= 0) {
            return
        }
        var g = ctx.createRadialGradient(x, y, 0, x, y, r)
        g.addColorStop(0, rgba(c, a))
        g.addColorStop(0.42, rgba(c, a * 0.55))
        g.addColorStop(0.72, rgba(c, a * 0.18))
        g.addColorStop(1, rgba(c, 0))
        ctx.fillStyle = g
        ctx.beginPath()
        ctx.arc(x, y, r, 0, Math.PI * 2)
        ctx.fill()
    }

    function darkBase(ctx, w, h, top, mid, bottom) {
        var g = ctx.createLinearGradient(0, 0, w * 0.2, h)
        g.addColorStop(0, top)
        g.addColorStop(0.55, mid)
        g.addColorStop(1, bottom)
        ctx.fillStyle = g
        ctx.fillRect(0, 0, w, h)
    }

    function drawStars(ctx, w, h, list, alpha, twinkle) {
        for (var i = 0; i < list.length; ++i) {
            var s = list[i]
            var a = alpha * s.o
            if (twinkle) {
                a *= 0.45 + 0.55 * (0.5 + 0.5 * Math.sin(phase * s.s + s.p))
            }
            ctx.fillStyle = "rgba(247,225,181," + a + ")"
            ctx.beginPath()
            ctx.arc(s.x * w, s.y * h, s.r, 0, Math.PI * 2)
            ctx.fill()
        }
    }

    function vignette(ctx, w, h, strength) {
        var g = ctx.createRadialGradient(w / 2, h / 2, Math.min(w, h) * 0.22,
                                         w / 2, h / 2, Math.max(w, h) * 0.78)
        g.addColorStop(0, "rgba(0,0,0,0)")
        g.addColorStop(1, "rgba(0,0,0," + strength + ")")
        ctx.fillStyle = g
        ctx.fillRect(0, 0, w, h)
    }

    function paintDusk(ctx, w, h) {
        var g = ctx.createRadialGradient(w * 0.38, h * 0.42, 0,
                                         w * 0.5, h * 0.5, Math.max(w, h) * 0.88)
        g.addColorStop(0, "#211a2b")
        g.addColorStop(0.55, "#15111d")
        g.addColorStop(1, "#0a0810")
        ctx.fillStyle = g
        ctx.fillRect(0, 0, w, h)

        ctx.globalCompositeOperation = "lighter"
        var breath = 0.28 + 0.03 * Math.sin(phase * 0.24)
        glow(ctx, w * (0.16 + mx * 0.02), h * (0.78 + my * 0.02),
             Math.min(w, h) * 0.64, [255, 179, 217], breath * intensity)
        glow(ctx, w * (0.84 + mx * 0.02), h * (0.22 + my * 0.02),
             Math.min(w, h) * 0.58, [174, 198, 255],
             (0.25 + 0.03 * Math.sin(phase * 0.19 + 2)) * intensity)
        glow(ctx, w * 0.72, h * 0.84,
             Math.min(w, h) * 0.30, [184, 230, 230], 0.12 * intensity)

        ctx.globalCompositeOperation = "source-over"
        if (showStars) {
            drawStars(ctx, w, h, duskStars, 0.22, false)
        }
        vignette(ctx, w, h, 0.40)
    }

    function paintSilk(ctx, w, h) {
        darkBase(ctx, w, h, "#17111f", "#0f0b16", "#08060c")
        ctx.globalCompositeOperation = "lighter"
        ctx.lineCap = "round"

        var bands = [
            { y: 0.30, amp: 0.075, wdt: 0.16, sp: 0.24, off: 0.0, a: [255,179,217], b: [174,198,255] },
            { y: 0.44, amp: 0.055, wdt: 0.12, sp: 0.18, off: 1.4, a: [200,182,226], b: [184,230,230] },
            { y: 0.56, amp: 0.065, wdt: 0.13, sp: 0.21, off: 2.9, a: [174,198,255], b: [245,194,231] },
            { y: 0.68, amp: 0.045, wdt: 0.09, sp: 0.15, off: 4.1, a: [247,225,181], b: [255,179,217] }
        ]

        for (var bi = 0; bi < bands.length; ++bi) {
            var band = bands[bi]
            var grad = ctx.createLinearGradient(0, 0, w, 0)
            grad.addColorStop(0.00, rgba(band.a, 0))
            grad.addColorStop(0.18, rgba(band.a, 0.12 * intensity))
            grad.addColorStop(0.48, rgba(band.b, 0.18 * intensity))
            grad.addColorStop(0.78, rgba(band.a, 0.12 * intensity))
            grad.addColorStop(1.00, rgba(band.a, 0))
            ctx.strokeStyle = grad

            for (var pass = 0; pass < 3; ++pass) {
                ctx.globalAlpha = Math.min(0.9, (0.62 - pass * 0.19) * intensity)
                ctx.lineWidth = band.wdt * h * (1 + pass * 0.7)
                ctx.beginPath()
                var step = Math.max(12, w / 90)
                for (var x = 0; x <= w + 1; x += step) {
                    var u = x / w
                    var y = (band.y
                        + Math.sin(u * 6.2 + phase * band.sp + band.off) * band.amp
                        + Math.sin(u * 13.0 - phase * band.sp * 0.7 + band.off) * band.amp * 0.24
                        + my * 0.055) * h
                    if (x === 0) {
                        ctx.moveTo(x, y)
                    } else {
                        ctx.lineTo(x, y)
                    }
                }
                ctx.stroke()
            }
        }

        ctx.globalAlpha = 1
        ctx.globalCompositeOperation = "source-over"
        if (showStars) {
            drawStars(ctx, w, h, silkStars, 0.26, true)
        }
        vignette(ctx, w, h, 0.38)
    }
}
