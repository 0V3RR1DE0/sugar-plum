import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.pipewire 1.0 as PipeWire
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation

    readonly property var pinned: Plasmoid.configuration.Launchers || []

    property bool dragActive: false
    property bool dragSnapping: false
    property int dragIndex: -1
    property int dragTargetIndex: -1
    property var dragIcon
    property real dragX: 0
    property real dragY: 0

    Timer {
        id: dropTimer
        interval: 130
        onTriggered: root.finishDrop()
    }

    readonly property int taskCount: Math.max(1, taskModel.count)
    // Fixed budget, not the applet width: width depends on apps.implicitWidth,
    // which depends on slotSize, which caused an unstable shrink loop.
    readonly property int slotSize: Math.max(22, Math.min(36, Math.floor(1500 / taskCount) - 2))
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
            taskModel.requestRemoveLauncher(item.launcherUrl)
        } else {
            list.push(item.launcherUrl)
            taskModel.requestAddLauncher(item.launcherUrl)
        }
        savePinned(list)
    }

    function finishDrop() {
        if (!dragActive) {
            return
        }
        var from = dragIndex
        var target = dragTargetIndex
        dragActive = false
        dragSnapping = false
        dragIndex = -1
        dragTargetIndex = -1
        finishDrag(from, target)
    }

    function finishDrag(from, target) {
        if (from < 0 || target < 0 || from === target) {
            return
        }
        var fromIdx = taskModel.index(from, 0)
        var toIdx = taskModel.index(target, 0)
        var fromUrl = String(taskModel.data(fromIdx, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon) || "")
        var toUrl = String(taskModel.data(toIdx, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon) || "")
        var fromLauncher = taskModel.data(fromIdx, TaskManager.AbstractTasksModel.IsLauncher)
            || taskModel.data(fromIdx, TaskManager.AbstractTasksModel.HasLauncher)
        var toLauncher = taskModel.data(toIdx, TaskManager.AbstractTasksModel.IsLauncher)
            || taskModel.data(toIdx, TaskManager.AbstractTasksModel.HasLauncher)

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
                        active: taskItem.open && !root.dragActive && taskMenu.status !== PlasmaExtras.Menu.Open
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
                        property bool isPinned: model.IsLauncher === true || taskItem.pinnedByList
                        // Never synthesise a launcher URL: appId is not always a
                        // .desktop basename (Steam games, plasmashell, Electron).
                        property string launcherUrl: taskItem.rawLauncherUrl
                        property var iconSource: taskItem.pinnedByList && taskItem.appId.length > 0
                            ? taskItem.appId
                            : model.decoration
                        property bool dragSource: root.dragActive && root.dragIndex === taskItem.taskIndex

                        Accessible.role: Accessible.Button
                        Accessible.name: String(model.display || "")

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
                                if (taskModel.data(taskItem.childIndex(i), TaskManager.AbstractTasksModel.IsActive)) {
                                    return i
                                }
                            }
                            return -1
                        }

                        function mostRecentChild() {
                            var best = -1
                            var bestStack = -1
                            for (var i = 0; i < taskItem.childCount; ++i) {
                                var stack = taskModel.data(taskItem.childIndex(i), TaskManager.AbstractTasksModel.StackingOrder)
                                if (stack > bestStack) {
                                    bestStack = stack
                                    best = i
                                }
                            }
                            return best
                        }

                        // Act on the actual window, never on a group parent:
                        // group-parent IsActive/IsMinimized do not reliably
                        // reflect the child, which made single-window groups
                        // ignore clicks.
                        function targetIndex() {
                            if (taskItem.childCount > 0) {
                                var row = taskItem.activeChild()
                                if (row < 0) row = taskItem.mostRecentChild()
                                if (row < 0) row = 0
                                return taskItem.childIndex(row)
                            }
                            return taskModel.index(taskItem.taskIndex, 0)
                        }
                        function targetMinimized() {
                            return taskModel.data(taskItem.targetIndex(), TaskManager.AbstractTasksModel.IsMinimized) === true
                        }
                        function targetMaximized() {
                            return taskModel.data(taskItem.targetIndex(), TaskManager.AbstractTasksModel.IsMaximized) === true
                        }
                        function targetFullScreen() {
                            return taskModel.data(taskItem.targetIndex(), TaskManager.AbstractTasksModel.IsFullScreen) === true
                        }

                        Component.onDestruction: {
                            if (root.dragActive && root.dragIndex === taskItem.taskIndex) {
                                root.dragActive = false
                                root.dragSnapping = false
                                root.dragIndex = -1
                                root.dragTargetIndex = -1
                            }
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
                                        property bool rowActive: taskModel.data(childIdx, TaskManager.AbstractTasksModel.IsActive) === true
                                        property bool rowMinimized: taskModel.data(childIdx, TaskManager.AbstractTasksModel.IsMinimized) === true
                                        property bool rowHidden: taskModel.data(childIdx, TaskManager.TasksModel.IsHidden) === true
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
                                                uuid: windowRow.previewActive
                                                    && !windowRow.rowMinimized
                                                    && !windowRow.rowHidden
                                                    ? windowRow.winUuid : ""
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
                            opacity: taskItem.dragSource ? 0.25 : 1.0
                            color: taskItem.taskActive
                                ? Qt.rgba(1.0, 0.70, 0.85, 0.14)
                                : (taskItem.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                        }

                        Kirigami.Icon {
                            id: themedIcon
                            anchors.centerIn: parent
                            width: root.iconPx
                            height: root.iconPx
                            source: taskItem.pinnedByList && taskItem.appId.length > 0 ? taskItem.appId : ""
                            visible: valid
                            smooth: true
                            opacity: taskItem.dragSource ? 0.18 : (taskItem.minimized ? 0.5 : 1.0)
                        }

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: root.iconPx
                            height: root.iconPx
                            source: model.decoration
                            visible: !themedIcon.valid
                            smooth: true
                            opacity: taskItem.dragSource ? 0.18 : (taskItem.minimized ? 0.5 : 1.0)
                        }

                        Rectangle {
                            visible: taskItem.open
                            anchors.top: parent.top
                            anchors.right: parent.right
                            width: Math.max(12, Math.round(root.slotSize * 0.5))
                            height: Math.max(6, Math.round(root.slotSize * 0.22))
                            radius: height / 2
                            opacity: taskItem.dragSource ? 0.18 : 1.0
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

                        PlasmaExtras.Menu {
                            id: taskMenu
                            visualParent: taskItem
                            minimumWidth: 230
                            placement: {
                                if (Plasmoid.location === PlasmaCore.Types.LeftEdge) {
                                    return PlasmaExtras.Menu.RightPosedTopAlignedPopup
                                } else if (Plasmoid.location === PlasmaCore.Types.TopEdge) {
                                    return PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
                                } else if (Plasmoid.location === PlasmaCore.Types.RightEdge) {
                                    return PlasmaExtras.Menu.LeftPosedTopAlignedPopup
                                }
                                return PlasmaExtras.Menu.TopPosedLeftAlignedPopup
                            }

                            PlasmaExtras.MenuItem {
                                text: taskItem.launcher && !taskItem.open ? "Open" : "New Window"
                                icon: "window-new"
                                onClicked: taskModel.requestNewInstance(taskModel.index(taskItem.taskIndex, 0))
                            }

                            PlasmaExtras.MenuItem {
                                text: taskItem.isPinned ? "Unpin from Taskbar" : "Pin to Taskbar"
                                icon: taskItem.isPinned ? "window-unpin" : "window-pin"
                                enabled: taskItem.launcherUrl.length > 0
                                onClicked: root.togglePin(taskItem)
                            }

                            PlasmaExtras.MenuItem { separator: true }

                            PlasmaExtras.MenuItem {
                                text: "Minimize"
                                icon: "window-minimize"
                                visible: taskItem.open
                                enabled: !taskItem.targetMinimized()
                                onClicked: taskModel.requestToggleMinimized(taskItem.targetIndex())
                            }

                            PlasmaExtras.MenuItem {
                                text: taskItem.targetMaximized() ? "Restore" : "Maximize"
                                icon: taskItem.targetMaximized() ? "window-restore" : "window-maximize"
                                visible: taskItem.open
                                onClicked: taskModel.requestToggleMaximized(taskItem.targetIndex())
                            }

                            PlasmaExtras.MenuItem {
                                text: "Move"
                                icon: "transform-move"
                                visible: taskItem.open
                                onClicked: taskModel.requestMove(taskItem.targetIndex())
                            }

                            PlasmaExtras.MenuItem {
                                text: "Resize"
                                icon: "transform-scale"
                                visible: taskItem.open
                                onClicked: taskModel.requestResize(taskItem.targetIndex())
                            }

                            PlasmaExtras.MenuItem {
                                text: "Full Screen"
                                icon: "view-fullscreen"
                                visible: taskItem.open
                                checkable: true
                                checked: taskItem.targetFullScreen()
                                onClicked: taskModel.requestToggleFullScreen(taskItem.targetIndex())
                            }

                            PlasmaExtras.MenuItem { separator: true }

                            PlasmaExtras.MenuItem {
                                text: "Close"
                                icon: "window-close"
                                visible: taskItem.open
                                onClicked: taskModel.requestClose(taskItem.targetIndex())
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                            property bool dragging: false
                            property bool dragAllowed: false
                            property bool pressAccepted: false
                            property real pressX: 0
                            property real pressY: 0

                            function clampTarget(index) {
                                var pinnedCount = Math.min(root.pinned.length, taskModel.count)
                                if (taskItem.isPinned) {
                                    return Math.max(0, Math.min(pinnedCount - 1, index))
                                }
                                return Math.max(pinnedCount, Math.min(taskModel.count - 1, index))
                            }

                            function doClick(button) {
                                taskItem.hideImmediately()
                                if (button === Qt.RightButton) {
                                    taskMenu.openRelative()
                                    return
                                }
                                var idx = taskModel.index(taskItem.taskIndex, 0)
                                if (button === Qt.MiddleButton) {
                                    taskModel.requestClose(taskItem.targetIndex())
                                    return
                                }
                                if (taskItem.launcher && !taskItem.open) {
                                    taskModel.requestNewInstance(idx)
                                    return
                                }
                                if (taskItem.childCount > 0) {
                                    var count = taskItem.childCount
                                    var row = 0
                                    if (count > 1) {
                                        var current = taskItem.activeChild()
                                        row = current === -1 ? taskItem.mostRecentChild() : (current + 1) % count
                                    }
                                    if (row < 0) {
                                        row = 0
                                    }
                                    var target = taskItem.childIndex(row)
                                    if (taskModel.data(target, TaskManager.AbstractTasksModel.IsMinimized) === true) {
                                        taskModel.requestToggleMinimized(target)
                                        taskModel.requestActivate(target)
                                    } else if (count === 1
                                               && taskModel.data(target, TaskManager.AbstractTasksModel.IsActive) === true) {
                                        taskModel.requestToggleMinimized(target)
                                    } else {
                                        taskModel.requestActivate(target)
                                    }
                                    return
                                }
                                if (taskItem.minimized) {
                                    taskModel.requestToggleMinimized(idx)
                                    taskModel.requestActivate(idx)
                                } else if (taskItem.taskActive) {
                                    taskModel.requestToggleMinimized(idx)
                                } else {
                                    taskModel.requestActivate(idx)
                                }
                            }

                            function updateDrag() {
                                if (!mouseArea.pressed || !dragAllowed) {
                                    return
                                }
                                var p = mouseArea.mapToItem(fullRoot, mouseArea.mouseX, mouseArea.mouseY)
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
                                    var pApps = mouseArea.mapToItem(apps, mouseArea.mouseX, mouseArea.mouseY)
                                    var slot = Math.floor(pApps.x / (root.slotSize + apps.spacing))
                                    root.dragTargetIndex = clampTarget(slot)
                                }
                            }

                            onPressed: (mouse) => {
                                pressAccepted = false
                                if (root.dragSnapping) {
                                    return
                                }
                                pressAccepted = true
                                var p = mouseArea.mapToItem(fullRoot, mouse.x, mouse.y)
                                dragAllowed = mouse.button === Qt.LeftButton
                                pressX = p.x
                                pressY = p.y
                                root.dragTargetIndex = -1
                                dragging = false
                            }

                            onMouseXChanged: updateDrag()
                            onMouseYChanged: updateDrag()

                            onReleased: (mouse) => {
                                if (!pressAccepted) {
                                    return
                                }
                                pressAccepted = false
                                if (dragging) {
                                    var p = mouseArea.mapToItem(apps, mouseArea.mouseX, mouseArea.mouseY)
                                    var target = clampTarget(Math.floor(p.x / (root.slotSize + apps.spacing)))
                                    root.dragTargetIndex = target
                                    root.dragSnapping = true
                                    var center = apps.mapToItem(fullRoot,
                                        target * (root.slotSize + apps.spacing) + root.slotSize / 2,
                                        root.slotSize / 2)
                                    root.dragX = center.x
                                    root.dragY = center.y
                                    dropTimer.restart()
                                    dragging = false
                                    return
                                }
                                if (!root.dragSnapping) {
                                    doClick(mouse.button)
                                }
                            }

                            onCanceled: {
                                dropTimer.stop()
                                pressAccepted = false
                                dragging = false
                                root.dragActive = false
                                root.dragSnapping = false
                                root.dragIndex = -1
                                root.dragTargetIndex = -1
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        Rectangle {
            id: dropIndicator
            visible: root.dragActive && !root.dragSnapping && root.dragTargetIndex >= 0
            x: apps.x + root.dragTargetIndex * (root.slotSize + apps.spacing)
            y: 0
            width: root.slotSize
            height: root.slotSize
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.035)
            border.width: 1
            border.color: Qt.rgba(1.0, 0.70, 0.85, 0.55)
            z: 1
        }

        Item {
            id: dragGhost
            visible: root.dragActive
            width: root.slotSize + 6
            height: width
            x: root.dragX - width / 2
            y: root.dragY - height / 2
            z: 100

            Behavior on x { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Qt.rgba(0.07, 0.06, 0.11, 0.78)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.14)
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                width: Math.round(root.iconPx * 1.15)
                height: width
                source: root.dragIcon
                smooth: true
            }
        }
    }
}
