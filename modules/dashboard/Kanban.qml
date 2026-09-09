pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
Item {
    id: root

    implicitWidth: 900
    implicitHeight: 500

    // ─────────────────────────────────────────────
    // DRAG STATE
    // ─────────────────────────────────────────────

    property int draggedIndex: -1
    property var draggedModel: null

    property real dragX: 0
    property real dragY: 0

    property real grabOffsetX: 0
    property real grabOffsetY: 0

    property real draggedWidth: 280
    property real draggedHeight: 80

    property string draggedTitle: ""
    property string draggedMeta: ""

    // ─────────────────────────────────────────────
    // ADD TASK STATE
    // ─────────────────────────────────────────────

    property bool addDialogVisible: false
    property var addTargetModel: null
    property string addTargetName: ""

    // ─────────────────────────────────────────────
    // DATA
    // ─────────────────────────────────────────────

    ListModel {
        id: backlogModel

        ListElement {
            title: "Physics numericals"
            meta: "Today"
        }

        ListElement {
            title: "Chemistry notes"
            meta: "This week"
        }

        ListElement {
            title: "Revise calculus"
            meta: "Later"
        }
    }

    ListModel {
        id: progressModel

        ListElement {
            title: "Physics — Work & Energy"
            meta: "2h"
        }

        ListElement {
            title: "Maths exercise 4"
            meta: "45m"
        }
    }

    ListModel {
        id: doneModel

        ListElement {
            title: "English assignment"
            meta: "Done"
        }

        ListElement {
            title: "Biology revision"
            meta: "Done"
        }
    }

    property var columns: [
        {
            title: "Backlog",
            icon: "inbox",
            model: backlogModel
        },
        {
            title: "In progress",
            icon: "pending",
            model: progressModel
        },
        {
            title: "Done",
            icon: "check_circle",
            model: doneModel
        }
    ]

    // ─────────────────────────────────────────────
    // DRAG HELPERS
    // ─────────────────────────────────────────────

    function startDrag(model, index, card) {
        if (!model)
            return

        if (index < 0 || index >= model.count)
            return

        const task = model.get(index)

        draggedModel = model
        draggedIndex = index

        draggedTitle = task.title
        draggedMeta = task.meta

        draggedWidth = card.width
        draggedHeight = card.height

        const mousePosition = card.mapToItem(
            root,
            card.dragMouseX,
            card.dragMouseY
        )

        const cardPosition = card.mapToItem(
            root,
            0,
            0
        )

        dragX = mousePosition.x
        dragY = mousePosition.y

        grabOffsetX =
            mousePosition.x - cardPosition.x

        grabOffsetY =
            mousePosition.y - cardPosition.y
    }

    function updateDrag(card) {
        const mousePosition = card.mapToItem(
            root,
            card.dragMouseX,
            card.dragMouseY
        )

        dragX = Math.max(
            0,
            Math.min(root.width, mousePosition.x)
        )

        dragY = Math.max(
            0,
            Math.min(root.height, mousePosition.y)
        )
    }

    function finishDrag() {
        if (!draggedModel || draggedIndex < 0) {
            clearDrag()
            return
        }

        const target =
            targetColumnAt(dragX, dragY)

        if (
            target &&
            target.columnModel !== draggedModel
        ) {
            const task =
                draggedModel.get(draggedIndex)

            target.columnModel.append({
                title: task.title,
                meta: task.meta
            })

            draggedModel.remove(draggedIndex)
        }

        clearDrag()
    }

    function clearDrag() {
        draggedIndex = -1
        draggedModel = null

        draggedTitle = ""
        draggedMeta = ""

        dragX = 0
        dragY = 0

        grabOffsetX = 0
        grabOffsetY = 0
    }

    function targetColumnAt(x, y) {
        for (
            let i = 0;
            i < columnRepeater.count;
            ++i
        ) {
            const item =
                columnRepeater.itemAt(i)

            if (!item)
                continue

            const p =
                item.mapFromItem(
                    root,
                    x,
                    y
                )

            if (
                p.x >= 0 &&
                p.x <= item.width &&
                p.y >= 0 &&
                p.y <= item.height
            ) {
                return item
            }
        }

        return null
    }

    // ─────────────────────────────────────────────
    // ADD TASK
    // ─────────────────────────────────────────────

    function openAddTask(model, columnName) {
        addTargetModel = model
        addTargetName = columnName

        addDialogVisible = true

        addTitleField.text = ""
        addMetaField.text = ""

        Qt.callLater(function() {
            addTitleField.forceActiveFocus()
        })
    }

    function addTask() {
        if (!addTargetModel)
            return

        const title =
            addTitleField.text.trim()

        if (!title)
            return

        const meta =
            addMetaField.text.trim()

        addTargetModel.append({
            title: title,
            meta: meta || "No details"
        })

        closeAddTask()
    }

    function closeAddTask() {
        addDialogVisible = false
        addTargetModel = null
        addTargetName = ""

        addTitleField.text = ""
        addMetaField.text = ""
    }

    // ─────────────────────────────────────────────
    // BOARD
    // ─────────────────────────────────────────────

    RowLayout {
        id: board

        anchors.fill: parent
        spacing: Tokens.spacing.medium

        Repeater {
            id: columnRepeater

            model: root.columns

            delegate: StyledRect {
                id: column

                required property var modelData

                property var columnModel:
                    modelData.model

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 220

                radius:
                    Tokens.rounding.extraLarge

                color: {
                    const target =
                        root.draggedModel
                        ? root.targetColumnAt(
                            root.dragX,
                            root.dragY
                        )
                        : null

                    return target === column
                        ? Colours.palette.m3primaryContainer
                        : Colours.palette.m3surfaceContainer
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins:
                        Tokens.padding.large

                    spacing:
                        Tokens.spacing.medium

                    // ─────────────────────────
                    // HEADER
                    // ─────────────────────────

                    RowLayout {
                        Layout.fillWidth: true

                        spacing:
                            Tokens.spacing.small

                        MaterialIcon {
                            text:
                                modelData.icon

                            color:
                                Colours.palette.m3primary

                            fontStyle:
                                Tokens.font.icon.medium
                        }

                        StyledText {
                            Layout.fillWidth: true

                            text:
                                modelData.title

                            font:
                                Tokens.font.title.medium

                            color:
                                Colours.palette.m3onSurface
                        }

                        StyledText {
                            text:
                                column.columnModel.count

                            font:
                                Tokens.font.label.medium

                            color:
                                Colours.palette.m3onSurfaceVariant
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1

                        color:
                            Colours.palette.m3outlineVariant
                    }

                    // ─────────────────────────
                    // CARD AREA
                    // ─────────────────────────

                    Item {
                        id: cardArea

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Repeater {
                            model:
                                column.columnModel

                            delegate: StyledRect {
                                id: card

                                required property string title
                                required property string meta
                                required property int index

                                property var sourceModel:
                                    column.columnModel

                                property bool beingDragged:
                                    root.draggedModel ===
                                    sourceModel
                                    &&
                                    root.draggedIndex ===
                                    index

                                property real dragMouseX: 0
                                property real dragMouseY: 0

                                width:
                                    cardArea.width

                                height:
                                    cardContent.implicitHeight
                                    + Tokens.padding.medium * 2

                                x: 0

                                y:
                                    index *
                                    (
                                        height
                                        + Tokens.spacing.small
                                    )

                                z:
                                    beingDragged
                                    ? 100
                                    : 0

                                // Leave a "ghost" behind.
                                opacity:
                                    beingDragged
                                    ? 0.22
                                    : 1

                                radius:
                                    Tokens.rounding.large

                                color:
                                    Colours.palette.m3surface

                                border.width:
                                    beingDragged
                                    ? 2
                                    : 1

                                border.color:
                                    beingDragged
                                    ? Colours.palette.m3primary
                                    : Colours.palette.m3outlineVariant

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 100
                                    }
                                }

                                // ─────────────────
                                // DRAG
                                // ─────────────────

                                MouseArea {
                                    id: dragArea

                                    anchors.fill:
                                        parent

                                    preventStealing: true

                                    acceptedButtons:
                                        Qt.LeftButton

                                    hoverEnabled: true

                                    cursorShape:
                                        pressed
                                        ? Qt.ClosedHandCursor
                                        : Qt.OpenHandCursor

                                    onPressed:
                                        function(mouse) {
                                            card.dragMouseX =
                                                mouse.x

                                            card.dragMouseY =
                                                mouse.y

                                            root.startDrag(
                                                card.sourceModel,
                                                card.index,
                                                card
                                            )
                                        }

                                    onPositionChanged:
                                        function(mouse) {
                                            if (!pressed)
                                                return

                                            card.dragMouseX =
                                                mouse.x

                                            card.dragMouseY =
                                                mouse.y

                                            root.updateDrag(card)
                                        }

                                    onReleased: {
                                        root.finishDrag()
                                    }

                                    onCanceled: {
                                        root.clearDrag()
                                    }
                                }

                                // ─────────────────
                                // CARD CONTENT
                                // ─────────────────

                                ColumnLayout {
                                    id: cardContent

                                    anchors.left:
                                        parent.left

                                    anchors.right:
                                        parent.right

                                    anchors.verticalCenter:
                                        parent.verticalCenter

                                    anchors.margins:
                                        Tokens.padding.medium

                                    spacing:
                                        Tokens.spacing.small

                                    StyledText {
                                        Layout.fillWidth: true

                                        text:
                                            card.title

                                        font:
                                            Tokens.font.body.medium

                                        color:
                                            Colours.palette.m3onSurface

                                        wrapMode:
                                            Text.Wrap
                                    }

                                    StyledText {
                                        Layout.fillWidth: true

                                        text:
                                            card.meta

                                        font:
                                            Tokens.font.label.small

                                        color:
                                            Colours.palette.m3onSurfaceVariant

                                        elide:
                                            Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    // ─────────────────────────
                    // ADD TASK
                    // ─────────────────────────

                    StyledRect {
                        Layout.fillWidth: true

                        implicitHeight:
                            addTaskLabel.implicitHeight
                            + Tokens.padding.medium * 2

                        radius:
                            Tokens.rounding.large

                        color:
                            Colours.palette
                                .m3surfaceContainerHighest

                        StateLayer {
                            anchors.fill: parent

                            radius:
                                Tokens.rounding.large

                            onClicked: {
                                root.openAddTask(
                                    column.columnModel,
                                    modelData.title
                                )
                            }
                        }

                        StyledText {
                            id: addTaskLabel

                            anchors.centerIn:
                                parent

                            text: "+ Add task"

                            font:
                                Tokens.font.label.large

                            color:
                                Colours.palette.m3primary
                        }
                    }
                }
            }
        }
    }

    // ═════════════════════════════════════════════
    // FLOATING DRAG PREVIEW
    //
    // IMPORTANT:
    // This is OUTSIDE the column Repeater.
    // Therefore there is exactly ONE preview.
    // ═════════════════════════════════════════════

    StyledRect {
        id: dragPreview

        visible:
            root.draggedModel !== null

        z: 5000

        width:
            root.draggedWidth

        height:
            root.draggedHeight

        x:
            Math.max(
                0,
                Math.min(
                    root.width - width,
                    root.dragX - root.grabOffsetX
                )
            )

        y:
            Math.max(
                0,
                Math.min(
                    root.height - height,
                    root.dragY - root.grabOffsetY
                )
            )

        radius:
            Tokens.rounding.large

        color:
            Colours.palette.m3primaryContainer

        border.width: 2

        border.color:
            Colours.palette.m3primary

        opacity: 0.94

        enabled: false

        ColumnLayout {
            id: dragPreviewContent

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter:
                parent.verticalCenter

            anchors.margins:
                Tokens.padding.medium

            spacing:
                Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true

                text:
                    root.draggedTitle

                font:
                    Tokens.font.body.medium

                color:
                    Colours.palette.m3onPrimaryContainer

                wrapMode:
                    Text.Wrap
            }

            StyledText {
                Layout.fillWidth: true

                text:
                    root.draggedMeta

                font:
                    Tokens.font.label.small

                color:
                    Colours.palette.m3onSurfaceVariant

                elide:
                    Text.ElideRight
            }
        }
    }

    // ─────────────────────────────────────────────
    // ADD TASK DIALOG
    // ─────────────────────────────────────────────

    Rectangle {
        id: dialogOverlay

        anchors.fill: parent

        visible:
            root.addDialogVisible

        z: 6000

        color:
            Qt.alpha(
                Colours.palette.m3scrim,
                0.55
            )

        MouseArea {
            anchors.fill: parent

            onClicked: {
                root.closeAddTask()
            }
        }

        StyledRect {
            id: addDialog

            anchors.centerIn: parent

            width:
                Math.min(
                    parent.width
                    - Tokens.padding.large * 2,
                    460
                )

            implicitHeight:
                dialogContent.implicitHeight
                + Tokens.padding.large * 2

            radius:
                Tokens.rounding.extraLarge

            color:
                Colours.palette.m3surfaceContainerHigh

            border.width: 1

            border.color:
                Colours.palette.m3outlineVariant

            MouseArea {
                anchors.fill: parent

                onClicked: {}
            }

            ColumnLayout {
                id: dialogContent

                anchors.fill: parent

                anchors.margins:
                    Tokens.padding.large

                spacing:
                    Tokens.spacing.medium

                StyledText {
                    text:
                        "New task"

                    font:
                        Tokens.font.headline.small

                    color:
                        Colours.palette.m3onSurface
                }

                StyledText {
                    text:
                        "Add to "
                        + root.addTargetName

                    font:
                        Tokens.font.body.small

                    color:
                        Colours.palette.m3onSurfaceVariant
                }

                StyledTextField {
                    id: addTitleField

                    Layout.fillWidth: true

                    placeholderText:
                        "Task title"

                    onAccepted: {
                        root.addTask()
                    }
                }

                StyledTextField {
                    id: addMetaField

                    Layout.fillWidth: true

                    placeholderText:
                        "Details (optional)"

                    onAccepted: {
                        root.addTask()
                    }
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 1
                }

                RowLayout {
                    Layout.fillWidth: true

                    spacing:
                        Tokens.spacing.small

                    Item {
                        Layout.fillWidth: true
                    }

                    TextButton {
                        text: "Cancel"

                        onClicked: {
                            root.closeAddTask()
                        }
                    }

                    TextButton {
                        text: "Add"

                        type:
                            TextButton.Filled

                        onClicked: {
                            root.addTask()
                        }
                    }
                }
            }
        }
    }
}