import QtQuick
import org.kde.kwin.decoration

Decoration {
    id: root
    property int titleHeight: 36
    property int buttonSize: 18
    property color bg: decoration.client.active ? "#1e1e2e" : "#181825"
    property color line: "#313244"
    property color fg: decoration.client.active ? "#cdd6f4" : "#a6adc8"

    alpha: true

    DecorationOptions {
        id: options
        deco: decoration
    }

    Component.onCompleted: {
        borders.setBorders(1)
        borders.setTitle(titleHeight)
        maximizedBorders.setBorders(0)
        maximizedBorders.setTitle(titleHeight)
        extendedBorders.setAllBorders(4)
    }

    Rectangle {
        anchors.fill: parent
        radius: decoration.client.maximized ? 0 : 8
        color: root.bg
        border.width: decoration.client.maximized ? 0 : 1
        border.color: root.line

        Item {
            id: titleBar
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: root.titleHeight
            Component.onCompleted: decoration.installTitleItem(titleBar)

            Row {
                id: dots
                anchors {
                    left: parent.left
                    leftMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                spacing: 5
                Repeater {
                    model: ["#ffb3d9", "#f7e1b5", "#b8e6c8"]
                    Rectangle {
                        width: 7
                        height: 7
                        radius: 3.5
                        color: modelData
                    }
                }
            }

            Text {
                anchors {
                    left: dots.right
                    right: buttons.left
                    leftMargin: 10
                    rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                text: decoration.client.caption
                color: root.fg
                font: options.titleFont
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
                renderType: Text.NativeRendering
            }

            Row {
                id: buttons
                anchors {
                    right: parent.right
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                spacing: 2
                SugarButton {
                    buttonType: DecorationOptions.DecorationButtonMinimize
                    buttonSize: root.buttonSize
                }
                SugarButton {
                    buttonType: DecorationOptions.DecorationButtonMaximizeRestore
                    buttonSize: root.buttonSize
                }
                SugarButton {
                    buttonType: DecorationOptions.DecorationButtonClose
                    buttonSize: root.buttonSize
                }
            }
        }
    }
}
