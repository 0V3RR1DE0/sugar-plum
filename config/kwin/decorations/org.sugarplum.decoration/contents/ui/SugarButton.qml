import QtQuick
import org.kde.kwin.decoration

DecorationButton {
    id: button
    property int buttonSize: 18
    width: buttonSize
    height: buttonSize

    readonly property bool isClose: buttonType === DecorationOptions.DecorationButtonClose
    readonly property bool isMin: buttonType === DecorationOptions.DecorationButtonMinimize
    readonly property bool isMax: buttonType === DecorationOptions.DecorationButtonMaximizeRestore

    Rectangle {
        anchors.fill: parent
        radius: 3
        color: button.hovered || button.pressed ? "#313244" : "transparent"
    }

    Canvas {
        id: glyph
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = (button.isClose && button.hovered) ? "#f38ba8" : (decoration.client.active ? "#cdd6f4" : "#a6adc8")
            ctx.lineWidth = 1.4
            ctx.lineCap = "round"
            var cx = width / 2
            var cy = height / 2
            if (button.isMin) {
                ctx.beginPath()
                ctx.moveTo(cx - 4, cy)
                ctx.lineTo(cx + 4, cy)
                ctx.stroke()
            } else if (button.isMax) {
                if (decoration.client.maximized) {
                    ctx.strokeRect(cx - 5, cy - 3, 7, 7)
                    ctx.strokeRect(cx - 1, cy - 5, 7, 7)
                } else {
                    ctx.strokeRect(cx - 4, cy - 4, 8, 8)
                }
            } else if (button.isClose) {
                ctx.beginPath()
                ctx.moveTo(cx - 4, cy - 4)
                ctx.lineTo(cx + 4, cy + 4)
                ctx.moveTo(cx + 4, cy - 4)
                ctx.lineTo(cx - 4, cy + 4)
                ctx.stroke()
            }
        }
    }

    onHoveredChanged: glyph.requestPaint()
    onPressedChanged: glyph.requestPaint()

    Connections {
        target: decoration.client
        function onActiveChanged() { glyph.requestPaint() }
        function onMaximizedChanged() { glyph.requestPaint() }
    }
}
