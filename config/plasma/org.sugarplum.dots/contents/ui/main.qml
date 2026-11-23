import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
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
                    property bool running: model.IsWindow ? true : (model.IsGroupParent ? true : ((model.ChildCount || 0) > 0))
                    property bool launcher: model.IsLauncher ? true : false
                    property string label: model.display || ""

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
                        opacity: taskItem.minimized ? 0.45 : 1.0
                    }

                    // The app icon stays; when a window is open, this badge
                    // replaces the usual running indicator with the three dots.
                    Rectangle {
                        visible: taskItem.running
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 0
                        anchors.rightMargin: 0
                        width: 14
                        height: 7
                        radius: 4
                        color: Qt.rgba(0.10, 0.09, 0.14, 0.88)

                        Row {
                            anchors.centerIn: parent
                            spacing: 1
                            Repeater {
                                model: 3
                                Rectangle {
                                    width: 3.5
                                    height: 3.5
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
                            var idx = tasksModel.index(taskItem.taskIndex, 0);
                            if (event.button === Qt.MiddleButton) {
                                tasksModel.requestClose(idx);
                            } else if (taskItem.active) {
                                tasksModel.requestToggleMinimized(idx);
                            } else if (taskItem.launcher && !taskItem.running) {
                                tasksModel.requestNewInstance(idx);
                            } else {
                                tasksModel.requestActivate(idx);
                            }
                        }
                    }

                    PlasmaComponents.ToolTip {
                        text: taskItem.label
                        visible: mouse.containsMouse
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }
    }
}
