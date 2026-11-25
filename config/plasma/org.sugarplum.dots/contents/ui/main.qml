import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation

    // Edit this list to change the pinned apps.
    readonly property var pinned: [
        "applications:systemsettings.desktop",
        "applications:org.kde.dolphin.desktop",
        "applications:codium.desktop",
        "applications:com.mitchellh.ghostty.desktop",
        "applications:app.zen_browser.zen.desktop",
        "applications:spotify-launcher.desktop",
        "applications:obsidian.desktop"
    ]

    fullRepresentation: RowLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: apps.implicitWidth
        Layout.preferredWidth: apps.implicitWidth
        spacing: 0

        Row {
            id: apps
            spacing: 2

            Repeater {
                model: TaskManager.TasksModel {
                    id: tasksModel
                    filterByScreen: true
                    filterByCurrentVirtualDesktop: true
                    filterByActivity: true
                    sortMode: TaskManager.TasksModel.SortManual
                    groupMode: TaskManager.TasksModel.GroupApplications
                    separateLaunchers: false
                    launcherList: root.pinned
                }

                delegate: Item {
                    id: taskItem
                    width: 36
                    height: 36
                    property int taskIndex: index
                    property bool active: model.IsActive ? true : false
                    property bool minimized: model.IsMinimized ? true : false
                    property bool launcher: model.IsLauncher ? true : false
                    property bool open: model.IsWindow ? true : (model.IsGroupParent ? true : ((model.ChildCount || 0) > 0))
                    property string label: model.display || ""
                    property var appIcon: model.decoration
                    property int childCount: model.ChildCount || 0
                    function childIndex(row) {
                        return tasksModel.makeModelIndex(taskItem.taskIndex, row)
                    }

                    function activeChild() {
                        for (var i = 0; i < taskItem.childCount; ++i) {
                            if (tasksModel.data(taskItem.childIndex(i), TaskManager.TasksModel.IsActive)) {
                                return i
                            }
                        }
                        return -1
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 10
                        color: taskItem.active
                            ? Qt.rgba(1.0, 0.70, 0.85, 0.14)
                            : (mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                    }

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        source: model.decoration
                        smooth: true
                        opacity: taskItem.minimized ? 0.5 : 1.0
                    }

                    Rectangle {
                        visible: taskItem.open
                        anchors.top: parent.top
                        anchors.right: parent.right
                        width: 18
                        height: 8
                        radius: 4
                        color: Qt.rgba(0.10, 0.09, 0.14, 0.88)

                        Row {
                            anchors.centerIn: parent
                            spacing: 1
                            Repeater {
                                model: 3
                                Rectangle {
                                    width: 4
                                    height: 4
                                    radius: 2
                                    color: ["#ffb3d9", "#f7e1b5", "#b8e6c8"][index]
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: function (event) {
                            var idx = tasksModel.index(taskItem.taskIndex, 0)
                            if (event.button === Qt.MiddleButton) {
                                tasksModel.requestClose(idx)
                            } else if (taskItem.launcher && !taskItem.open) {
                                tasksModel.requestNewInstance(idx)
                            } else if (taskItem.childCount > 1) {
                                var next = (taskItem.activeChild() + 1) % taskItem.childCount
                                tasksModel.requestActivate(taskItem.childIndex(next))
                                preview.close()
                            } else if (taskItem.active) {
                                tasksModel.requestToggleMinimized(idx)
                            } else {
                                tasksModel.requestActivate(idx)
                            }
                        }
                        onContainsMouseChanged: {
                            if (containsMouse && taskItem.childCount > 1) {
                                previewTimer.restart()
                            } else {
                                previewTimer.stop()
                            }
                        }
                    }

                    Timer {
                        id: previewTimer
                        interval: 350
                        repeat: false
                        onTriggered: {
                            if (mouse.containsMouse && taskItem.childCount > 1) {
                                preview.show()
                            }
                        }
                    }

                    PlasmaCore.Dialog {
                        id: preview
                        visualParent: taskItem
                        location: PlasmaCore.Types.Floating
                        hideOnWindowDeactivate: true
                        width: 280
                        height: previewColumn.implicitHeight + 12
                        x: Math.max(0, Math.min(Screen.width - width, Math.round(taskItem.mapToGlobal(taskItem.width / 2, 0).x - width / 2)))
                        y: Math.max(0, Math.round(taskItem.mapToGlobal(0, 0).y - height - 6))

                        mainItem: Column {
                            id: previewColumn
                            width: 268
                            spacing: 2

                            Repeater {
                                model: taskItem.childCount

                                delegate: Item {
                                    id: windowRow
                                    width: 260
                                    height: 30
                                    property var childIdx: tasksModel.makeModelIndex(taskItem.taskIndex, index)
                                    property bool rowActive: tasksModel.data(childIdx, TaskManager.TasksModel.IsActive)

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 5
                                        color: windowRow.rowActive
                                            ? Qt.rgba(1, 1, 1, 0.10)
                                            : (rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                                    }

                                    Kirigami.Icon {
                                        id: rowIcon
                                        anchors.left: parent.left
                                        anchors.leftMargin: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 18
                                        height: 18
                                        source: taskItem.appIcon
                                        smooth: true
                                    }

                                    Text {
                                        anchors.left: rowIcon.right
                                        anchors.leftMargin: 6
                                        anchors.right: parent.right
                                        anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: tasksModel.data(windowRow.childIdx, Qt.DisplayRole) || ""
                                        color: Kirigami.Theme.textColor
                                        elide: Text.ElideRight
                                        font: Kirigami.Theme.defaultFont
                                    }

                                    MouseArea {
                                        id: rowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            tasksModel.requestActivate(windowRow.childIdx)
                                            preview.close()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    PlasmaComponents.ToolTip {
                        text: taskItem.label
                        visible: mouse.containsMouse && taskItem.childCount <= 1
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }
    }
}
