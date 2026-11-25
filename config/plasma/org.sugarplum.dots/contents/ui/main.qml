import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.pipewire 1.0 as PipeWire
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation

    readonly property var defaultPinned: [
        "applications:systemsettings.desktop",
        "applications:org.kde.dolphin.desktop",
        "applications:codium.desktop",
        "applications:com.mitchellh.ghostty.desktop",
        "applications:app.zen_browser.zen.desktop",
        "applications:spotify-launcher.desktop",
        "applications:obsidian.desktop"
    ]

    readonly property var pinned: {
        var configured = Plasmoid.configuration.Launchers
        return (configured && configured.length) ? configured : defaultPinned
    }

    property bool dragActive: false
    property int dragIndex: -1
    property var dragIcon
    property real dragX: 0
    property real dragY: 0

    function launcherKey(url) {
        var s = String(url || "")
        if (s.indexOf("applications:") === 0) {
            s = s.substring(13)
        } else if (s.indexOf("file://") === 0) {
            s = s.substring(7)
        }
        s = s.replace(/\.desktop$/, "")
        var slash = s.lastIndexOf("/")
        if (slash >= 0) {
            s = s.substring(slash + 1)
        }
        return s
    }

    function sameLauncher(a, b) {
        return launcherKey(a) === launcherKey(b)
    }

    function savePinned(list) {
        Plasmoid.configuration.Launchers = list
        if (Plasmoid.configuration.writeConfig) {
            Plasmoid.configuration.writeConfig()
        }
    }

    function togglePin(item) {
        if (!item || !item.launcherUrl) {
            return
        }
        var list = pinned.slice()
        if (item.isPinned) {
            list = list.filter(function (url) { return !sameLauncher(url, item.launcherUrl) })
            tasksModel.requestRemoveLauncher(item.launcherUrl)
        } else {
            list.push(item.launcherUrl)
            tasksModel.requestAddLauncher(item.launcherUrl)
        }
        savePinned(list)
    }

    function finishDrag(from, target) {
        if (from < 0 || target < 0 || from === target) {
            return
        }
        var fromIdx = tasksModel.index(from, 0)
        var toIdx = tasksModel.index(target, 0)
        var fromUrl = String(tasksModel.data(fromIdx, TaskManager.TasksModel.LauncherUrlWithoutIcon) || "")
        var toUrl = String(tasksModel.data(toIdx, TaskManager.TasksModel.LauncherUrlWithoutIcon) || "")
        var fromLauncher = tasksModel.data(fromIdx, TaskManager.TasksModel.IsLauncher)
            || tasksModel.data(fromIdx, TaskManager.TasksModel.HasLauncher)
        var toLauncher = tasksModel.data(toIdx, TaskManager.TasksModel.IsLauncher)
            || tasksModel.data(toIdx, TaskManager.TasksModel.HasLauncher)

        if (fromLauncher && toLauncher && fromUrl && toUrl) {
            var list = pinned.slice()
            var a = -1
            var b = -1
            for (var i = 0; i < list.length; ++i) {
                if (sameLauncher(list[i], fromUrl)) a = i
                if (sameLauncher(list[i], toUrl)) b = i
            }
            if (a >= 0 && b >= 0) {
                var moved = list.splice(a, 1)[0]
                list.splice(b, 0, moved)
                savePinned(list)
            }
            return
        }
        tasksModel.move(from, target)
    }

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

                delegate: PlasmaCore.ToolTipArea {
                    id: taskItem
                    width: 36
                    height: 36
                    active: taskItem.open
                    interactive: true
                    location: Plasmoid.location
                    timeout: -1
                    hideOnClick: false

                    property int taskIndex: index
                    property bool taskActive: model.IsActive ? true : false
                    property bool tooltipOpen: false
                    onToolTipVisibleChanged: (visible) => { taskItem.tooltipOpen = visible }
                    property bool minimized: model.IsMinimized ? true : false
                    property bool launcher: model.IsLauncher ? true : false
                    property bool open: model.IsWindow ? true : (model.IsGroupParent ? true : ((model.ChildCount || 0) > 0))
                    property string label: model.display || ""
                    property var appIcon: model.decoration
                    property var winIdList: model.WinIdList
                    property int childCount: model.ChildCount || 0
                    property bool isPinned: (model.IsLauncher === true || model.HasLauncher === true)
                    property string launcherUrl: String(model.LauncherUrlWithoutIcon || model.LauncherUrl || "")

                    function childIndex(row) {
                        return tasksModel.makeModelIndex(taskItem.taskIndex, row)
                    }

                    function windowIndex(row) {
                        return taskItem.childCount > 0
                            ? tasksModel.makeModelIndex(taskItem.taskIndex, row)
                            : tasksModel.makeModelIndex(taskItem.taskIndex)
                    }

                    function activeChild() {
                        for (var i = 0; i < taskItem.childCount; ++i) {
                            if (tasksModel.data(taskItem.childIndex(i), TaskManager.TasksModel.IsActive)) {
                                return i
                            }
                        }
                        return -1
                    }

                    function mostRecentChild() {
                        var best = -1
                        var bestStack = -1
                        for (var i = 0; i < taskItem.childCount; ++i) {
                            var stack = tasksModel.data(taskItem.childIndex(i), TaskManager.TasksModel.StackingOrder)
                            if (stack > bestStack) {
                                bestStack = stack
                                best = i
                            }
                        }
                        return best
                    }

                    mainItem: Flickable {
                        id: previewFlick
                        implicitWidth: 380
                        implicitHeight: Math.min(previewColumn.implicitHeight, 320)
                        width: implicitWidth
                        height: implicitHeight
                        contentWidth: width
                        contentHeight: previewColumn.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: previewColumn
                            width: 380
                            spacing: 2

                            Repeater {
                                model: taskItem.childCount > 0 ? taskItem.childCount : 1

                                delegate: Item {
                                    id: windowRow
                                    width: 380
                                    height: 64
                                    property var childIdx: taskItem.windowIndex(index)
                                    property string winUuid: taskItem.winIdList && taskItem.winIdList.length > index
                                        ? String(taskItem.winIdList[index])
                                        : (taskItem.winIdList && taskItem.winIdList.length ? String(taskItem.winIdList[0]) : "")
                                    property bool rowActive: tasksModel.data(childIdx, TaskManager.TasksModel.IsActive)
                                    property bool previewActive: taskItem.containsMouse || taskItem.tooltipOpen

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 5
                                        color: windowRow.rowActive
                                            ? Qt.rgba(1, 1, 1, 0.10)
                                            : (rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                                    }

                                    Item {
                                        id: thumb
                                        anchors.left: parent.left
                                        anchors.leftMargin: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 112
                                        height: 63

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 4
                                            color: "#11111b"
                                            border.width: 1
                                            border.color: "#313244"
                                        }

                                        TaskManager.ScreencastingRequest {
                                            id: screencast
                                            uuid: windowRow.previewActive ? windowRow.winUuid : ""
                                        }

                                        Loader {
                                            id: thumbLoader
                                            anchors.fill: parent
                                            active: windowRow.previewActive && screencast.nodeId > 0
                                            sourceComponent: Component {
                                                PipeWire.PipeWireSourceItem {
                                                    nodeId: screencast.nodeId
                                                }
                                            }
                                        }

                                        Kirigami.Icon {
                                            anchors.centerIn: parent
                                            width: 36
                                            height: 36
                                            source: taskItem.appIcon
                                            visible: screencast.nodeId === 0
                                        }
                                    }

                                    Text {
                                        anchors.left: thumb.right
                                        anchors.leftMargin: 8
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: tasksModel.data(windowRow.childIdx, Qt.DisplayRole) || ""
                                        color: Kirigami.Theme.textColor
                                        elide: Text.ElideRight
                                        font: Kirigami.Theme.smallFont
                                    }

                                    MouseArea {
                                        id: rowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            tasksModel.requestActivate(windowRow.childIdx)
                                            taskItem.hideImmediately()
                                        }
                                    }
                                }
                            }
                        }

                        QQC2.ScrollBar.vertical: QQC2.ScrollBar { }
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 10
                        color: taskItem.taskActive
                            ? Qt.rgba(1.0, 0.70, 0.85, 0.14)
                            : (taskItem.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
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

                    PlasmaComponents.Menu {
                        id: taskMenu

                        PlasmaComponents.MenuItem {
                            text: taskItem.isPinned ? "Unpin from Taskbar" : "Pin to Taskbar"
                            icon.name: taskItem.isPinned ? "pin-remove" : "pin"
                            enabled: taskItem.launcherUrl.length > 0
                            onClicked: root.togglePin(taskItem)
                        }

                        PlasmaComponents.MenuSeparator {}

                        PlasmaComponents.MenuItem {
                            text: "Close"
                            icon.name: "window-close"
                            enabled: taskItem.open
                            onClicked: tasksModel.requestClose(tasksModel.index(taskItem.taskIndex, 0))
                        }
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onTapped: (eventPoint, button) => {
                            taskItem.hideImmediately()
                            if (button === Qt.RightButton) {
                                taskMenu.open()
                                return
                            }
                            var idx = tasksModel.index(taskItem.taskIndex, 0)
                            if (button === Qt.MiddleButton) {
                                tasksModel.requestClose(idx)
                            } else if (taskItem.launcher && !taskItem.open) {
                                tasksModel.requestNewInstance(idx)
                            } else if (taskItem.childCount > 1) {
                                var current = taskItem.activeChild()
                                var next = current === -1 ? taskItem.mostRecentChild() : (current + 1) % taskItem.childCount
                                if (next < 0) next = 0
                                var nextIdx = taskItem.childIndex(next)
                                if (tasksModel.data(nextIdx, TaskManager.TasksModel.IsMinimized)) {
                                    tasksModel.requestToggleMinimized(nextIdx)
                                }
                                tasksModel.requestActivate(nextIdx)
                            } else if (taskItem.minimized) {
                                tasksModel.requestToggleMinimized(idx)
                                tasksModel.requestActivate(idx)
                            } else if (taskItem.taskActive) {
                                tasksModel.requestToggleMinimized(idx)
                            } else {
                                tasksModel.requestActivate(idx)
                            }
                        }
                    }

                    DragHandler {
                        id: dragHandler
                        target: null

                        onActiveChanged: {
                            if (active) {
                                root.dragIndex = taskItem.taskIndex
                                root.dragIcon = taskItem.appIcon
                                root.dragActive = true
                                var p = root.mapFromItem(null, centroid.scenePosition)
                                root.dragX = p.x
                                root.dragY = p.y
                            } else {
                                var from = root.dragIndex
                                root.dragActive = false
                                root.dragIndex = -1
                                var p = apps.mapFromItem(null, centroid.scenePosition)
                                var target = Math.floor(p.x / 38)
                                target = Math.max(0, Math.min(tasksModel.count - 1, target))
                                root.finishDrag(from, target)
                            }
                        }

                        onCentroidChanged: {
                            if (active) {
                                var p = root.mapFromItem(null, centroid.scenePosition)
                                root.dragX = p.x
                                root.dragY = p.y
                            }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }
    }
    Kirigami.Icon {
        id: dragGhost
        visible: root.dragActive
        width: 26
        height: 26
        source: root.dragIcon
        x: root.dragX - width / 2
        y: root.dragY - height / 2
        z: 100
        opacity: 0.85
    }

}
