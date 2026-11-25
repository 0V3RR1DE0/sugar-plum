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

    readonly property int taskCount: Math.max(1, taskModel.count)
    readonly property int slotSize: Math.max(22, Math.min(36, Math.floor((width - 16) / taskCount) - 2))
    readonly property int iconPx: Math.max(16, Math.min(26, Math.round(slotSize * 0.68)))

    TaskManager.TasksModel {
        id: taskModel
        filterByScreen: true
        filterByCurrentVirtualDesktop: true
        filterByActivity: true
        sortMode: TaskManager.TasksModel.SortManual
        groupMode: TaskManager.TasksModel.GroupApplications
        separateLaunchers: false
        launcherList: root.pinned
    }

    property bool normalizing: false

    Connections {
        target: taskModel
        function onCountChanged() {
            Qt.callLater(root.normalizeOrder)
        }
    }

    Component.onCompleted: Qt.callLater(root.normalizeOrder)

    function normalizeOrder() {
        if (root.normalizing) {
            return
        }
        root.normalizing = true

        var keys = []
        for (var i = 0; i < root.pinned.length; ++i) {
            keys.push(root.launcherKey(root.pinned[i]))
        }

        for (var pos = 0; pos < keys.length && pos < taskModel.count; ++pos) {
            var found = -1
            for (var row = pos; row < taskModel.count; ++row) {
                var idx = taskModel.index(row, 0)
                var appId = String(taskModel.data(idx, TaskManager.TasksModel.AppId) || "")
                var launcherUrl = String(taskModel.data(idx, TaskManager.TasksModel.LauncherUrlWithoutIcon) || "")
                if (appId === keys[pos] || root.launcherKey(launcherUrl) === keys[pos]) {
                    found = row
                    break
                }
            }
            if (found > pos) {
                taskModel.move(found, pos)
            }
        }

        root.normalizing = false
    }

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
        Qt.callLater(root.normalizeOrder)
    }

    function togglePin(item) {
        if (!item || !item.launcherUrl) {
            return
        }
        var list = pinned.slice()
        if (item.isPinned) {
            list = list.filter(function (url) { return !sameLauncher(url, item.launcherUrl) })
            taskModel.requestRemoveLauncher(item.launcherUrl)
        } else {
            list.push(item.launcherUrl)
            taskModel.requestAddLauncher(item.launcherUrl)
        }
        savePinned(list)
    }

    function finishDrag(from, target) {
        if (from < 0 || target < 0 || from === target) {
            return
        }
        var fromIdx = taskModel.index(from, 0)
        var toIdx = taskModel.index(target, 0)
        var fromUrl = String(taskModel.data(fromIdx, TaskManager.TasksModel.LauncherUrlWithoutIcon) || "")
        var toUrl = String(taskModel.data(toIdx, TaskManager.TasksModel.LauncherUrlWithoutIcon) || "")
        var fromLauncher = taskModel.data(fromIdx, TaskManager.TasksModel.IsLauncher)
            || taskModel.data(fromIdx, TaskManager.TasksModel.HasLauncher)
        var toLauncher = taskModel.data(toIdx, TaskManager.TasksModel.IsLauncher)
            || taskModel.data(toIdx, TaskManager.TasksModel.HasLauncher)

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
        taskModel.move(from, target)
    }

    fullRepresentation: Item {
        id: fullRoot
        Layout.fillWidth: true
        Layout.minimumWidth: apps.implicitWidth
        Layout.preferredWidth: apps.implicitWidth
        implicitWidth: apps.implicitWidth
        implicitHeight: 36

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Row {
                id: apps
                spacing: 2

                Repeater {
                    model: taskModel

                    delegate: PlasmaCore.ToolTipArea {
                        id: taskItem
                        width: root.slotSize
                        height: root.slotSize
                        active: taskItem.open
                        interactive: true
                        location: Plasmoid.location
                        timeout: -1
                        hideOnClick: false

                        property int taskIndex: index
                        property bool taskActive: model.IsActive === true
                        property bool tooltipOpen: false
                        onToolTipVisibleChanged: (visible) => { taskItem.tooltipOpen = visible }
                        property bool minimized: model.IsMinimized === true
                        property bool maximized: model.IsMaximized === true
                        property bool fullScreen: model.IsFullScreen === true
                        property bool launcher: model.IsLauncher === true
                        property bool open: model.IsWindow === true ? true : (model.IsGroupParent === true ? true : ((model.ChildCount || 0) > 0))
                        property string label: model.display || ""
                        property var appIcon: model.decoration
                        property var winIdList: model.WinIdList
                        property int childCount: model.ChildCount || 0
                        property string appId: String(model.AppId || "")
                        property string rawLauncherUrl: String(model.LauncherUrlWithoutIcon || model.LauncherUrl || "")
                        property bool pinnedByList: {
                            for (var i = 0; i < root.pinned.length; ++i) {
                                if (root.launcherKey(root.pinned[i]) === taskItem.appId) {
                                    return true
                                }
                            }
                            return false
                        }
                        property bool isPinned: model.IsLauncher === true || model.HasLauncher === true || taskItem.pinnedByList
                        property string launcherUrl: taskItem.rawLauncherUrl.length > 0
                            ? taskItem.rawLauncherUrl
                            : (taskItem.appId.length > 0 ? "applications:" + taskItem.appId + ".desktop" : "")
                        property var iconSource: taskItem.appId === "com.mitchellh.ghostty"
                            ? Qt.resolvedUrl("ghostty.svg")
                            : (taskItem.pinnedByList && taskItem.appId.length > 0
                                ? taskItem.appId
                                : model.decoration)

                        function childIndex(row) {
                            return taskModel.makeModelIndex(taskItem.taskIndex, row)
                        }

                        function windowIndex(row) {
                            return taskItem.childCount > 0
                                ? taskModel.makeModelIndex(taskItem.taskIndex, row)
                                : taskModel.makeModelIndex(taskItem.taskIndex)
                        }

                        function activeChild() {
                            for (var i = 0; i < taskItem.childCount; ++i) {
                                if (taskModel.data(taskItem.childIndex(i), TaskManager.TasksModel.IsActive)) {
                                    return i
                                }
                            }
                            return -1
                        }

                        function mostRecentChild() {
                            var best = -1
                            var bestStack = -1
                            for (var i = 0; i < taskItem.childCount; ++i) {
                                var stack = taskModel.data(taskItem.childIndex(i), TaskManager.TasksModel.StackingOrder)
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
                                        property bool rowActive: taskModel.data(childIdx, TaskManager.TasksModel.IsActive) === true
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
                                                source: taskItem.iconSource
                                                visible: screencast.nodeId === 0
                                            }
                                        }

                                        Text {
                                            anchors.left: thumb.right
                                            anchors.leftMargin: 8
                                            anchors.right: parent.right
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: taskModel.data(windowRow.childIdx, Qt.DisplayRole) || ""
                                            color: Kirigami.Theme.textColor
                                            elide: Text.ElideRight
                                            font: Kirigami.Theme.smallFont
                                        }

                                        MouseArea {
                                            id: rowMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                taskModel.requestActivate(windowRow.childIdx)
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

                        Image {
                            anchors.centerIn: parent
                            width: root.iconPx
                            height: root.iconPx
                            source: Qt.resolvedUrl("ghostty.svg")
                            visible: taskItem.appId === "com.mitchellh.ghostty"
                            smooth: true
                            opacity: taskItem.minimized ? 0.5 : 1.0
                        }

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: root.iconPx
                            height: root.iconPx
                            source: model.decoration
                            visible: taskItem.appId !== "com.mitchellh.ghostty"
                            smooth: true
                            opacity: taskItem.minimized ? 0.5 : 1.0
                        }

                        Rectangle {
                            visible: taskItem.open
                            anchors.top: parent.top
                            anchors.right: parent.right
                            width: Math.max(12, Math.round(root.slotSize * 0.5))
                            height: Math.max(6, Math.round(root.slotSize * 0.22))
                            radius: height / 2
                            color: Qt.rgba(0.10, 0.09, 0.14, 0.88)

                            Row {
                                anchors.centerIn: parent
                                spacing: 1
                                Repeater {
                                    model: 3
                                    Rectangle {
                                        width: Math.max(3, Math.round(root.slotSize * 0.12))
                                        height: width
                                        radius: width / 2
                                        color: ["#ffb3d9", "#f7e1b5", "#b8e6c8"][index]
                                    }
                                }
                            }
                        }

                        PlasmaComponents.Menu {
                            id: taskMenu

                            PlasmaComponents.MenuItem {
                                text: taskItem.launcher && !taskItem.open ? "Open" : "New Window"
                                icon.name: "window-new"
                                onClicked: taskModel.requestNewInstance(taskModel.index(taskItem.taskIndex, 0))
                            }

                            PlasmaComponents.MenuItem {
                                text: taskItem.isPinned ? "Unpin from Taskbar" : "Pin to Taskbar"
                                icon.name: taskItem.isPinned ? "pin-remove" : "pin"
                                enabled: taskItem.launcherUrl.length > 0
                                onClicked: root.togglePin(taskItem)
                            }

                            PlasmaComponents.MenuSeparator {}

                            PlasmaComponents.MenuItem {
                                text: "Minimize"
                                icon.name: "window-minimize"
                                visible: taskItem.open
                                enabled: !taskItem.minimized
                                onClicked: taskModel.requestToggleMinimized(taskModel.index(taskItem.taskIndex, 0))
                            }

                            PlasmaComponents.MenuItem {
                                text: taskItem.maximized ? "Restore" : "Maximize"
                                icon.name: taskItem.maximized ? "window-restore" : "window-maximize"
                                visible: taskItem.open
                                onClicked: taskModel.requestToggleMaximized(taskModel.index(taskItem.taskIndex, 0))
                            }

                            PlasmaComponents.MenuItem {
                                text: "Move"
                                icon.name: "transform-move"
                                visible: taskItem.open
                                onClicked: taskModel.requestMove(taskModel.index(taskItem.taskIndex, 0))
                            }

                            PlasmaComponents.MenuItem {
                                text: "Resize"
                                icon.name: "transform-scale"
                                visible: taskItem.open
                                onClicked: taskModel.requestResize(taskModel.index(taskItem.taskIndex, 0))
                            }

                            PlasmaComponents.MenuItem {
                                text: "Full Screen"
                                icon.name: "view-fullscreen"
                                visible: taskItem.open
                                checkable: true
                                checked: taskItem.fullScreen
                                onClicked: taskModel.requestToggleFullScreen(taskModel.index(taskItem.taskIndex, 0))
                            }

                            PlasmaComponents.MenuSeparator {}

                            PlasmaComponents.MenuItem {
                                text: "Close"
                                icon.name: "window-close"
                                visible: taskItem.open
                                onClicked: taskModel.requestClose(taskModel.index(taskItem.taskIndex, 0))
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: false
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                            property bool dragging: false
                            property real pressX: 0
                            property real pressY: 0

                            function doClick(button) {
                                taskItem.hideImmediately()
                                if (button === Qt.RightButton) {
                                    taskMenu.open()
                                    return
                                }
                                var idx = taskModel.index(taskItem.taskIndex, 0)
                                if (button === Qt.MiddleButton) {
                                    taskModel.requestClose(idx)
                                } else if (taskItem.launcher && !taskItem.open) {
                                    taskModel.requestNewInstance(idx)
                                } else if (taskItem.childCount > 1) {
                                    var current = taskItem.activeChild()
                                    var next = current === -1 ? taskItem.mostRecentChild() : (current + 1) % taskItem.childCount
                                    if (next < 0) next = 0
                                    var nextIdx = taskItem.childIndex(next)
                                    if (taskModel.data(nextIdx, TaskManager.TasksModel.IsMinimized)) {
                                        taskModel.requestToggleMinimized(nextIdx)
                                    }
                                    taskModel.requestActivate(nextIdx)
                                } else if (taskItem.minimized) {
                                    taskModel.requestToggleMinimized(idx)
                                    taskModel.requestActivate(idx)
                                } else if (taskItem.taskActive) {
                                    taskModel.requestToggleMinimized(idx)
                                } else {
                                    taskModel.requestActivate(idx)
                                }
                            }

                            onPressed: (mouse) => {
                                var p = mouseArea.mapToItem(fullRoot, mouse.x, mouse.y)
                                pressX = p.x
                                pressY = p.y
                                dragging = false
                            }

                            onPositionChanged: (mouse) => {
                                if (!mouseArea.pressed) {
                                    return
                                }
                                var p = mouseArea.mapToItem(fullRoot, mouse.x, mouse.y)
                                if (!dragging && Math.abs(p.x - pressX) > 5) {
                                    dragging = true
                                    root.dragIndex = taskItem.taskIndex
                                    root.dragIcon = taskItem.iconSource
                                    root.dragActive = true
                                    root.dragX = p.x
                                    root.dragY = p.y
                                }
                                if (dragging) {
                                    root.dragX = p.x
                                    root.dragY = p.y
                                }
                            }

                            onReleased: (mouse) => {
                                if (dragging) {
                                    var p = mouseArea.mapToItem(apps, mouse.x, mouse.y)
                                    var target = Math.floor(p.x / (root.slotSize + 2))
                                    target = Math.max(0, Math.min(taskModel.count - 1, target))
                                    var from = root.dragIndex
                                    root.dragActive = false
                                    root.dragIndex = -1
                                    dragging = false
                                    root.finishDrag(from, target)
                                    return
                                }
                                doClick(mouse.button)
                            }

                            onCanceled: {
                                dragging = false
                                root.dragActive = false
                                root.dragIndex = -1
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
            width: root.iconPx
            height: root.iconPx
            source: root.dragIcon
            x: root.dragX - width / 2
            y: root.dragY - height / 2
            z: 100
            opacity: 0.85
        }
    }
}
