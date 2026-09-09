pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    // =========================================================
    // SIZE
    // =========================================================

    implicitWidth: 900
    implicitHeight: 500

    // =========================================================
    // DRAG STATE
    // =========================================================

    property string draggedKey: ""
    property int draggedIndex: -1

    property string draggedTitle: ""

    property real dragX: 0
    property real dragY: 0

    property real grabOffsetX: 0
    property real grabOffsetY: 0

    property real draggedWidth: 0
    property real draggedHeight: 0

    property string dropKey: ""
    property int dropIndex: -1

    // =========================================================
    // ADD TASK
    // =========================================================

    property bool addDialogVisible: false

    property string addTargetKey: ""
    property string addTargetName: ""

    // =========================================================
    // EDITOR
    // =========================================================

    property bool editorDialogVisible: false

    Connections {
        target: KanbanService

        function onEditorUnavailable() {
            root.editorDialogVisible = true
        }
    }

    // =========================================================
    // COLUMNS
    // =========================================================

    readonly property var columns: [
        {
            key: "backlog",
            title: "Backlog",
            icon: "inbox",
            model: KanbanService.backlog
        },
        {
            key: "progress",
            title: "In progress",
            icon: "pending",
            model: KanbanService.progress
        },
        {
            key: "done",
            title: "Done",
            icon: "check_circle",
            model: KanbanService.done
        }
    ]

    // =========================================================
    // COLUMN LOOKUP
    // =========================================================

    function columnForKey(key) {
        for (
            let i = 0;
            i < columns.length;
            ++i
        ) {
            if (
                columns[i].key === key
            ) {
                return columns[i]
            }
        }

        return null
    }

    // =========================================================
    // TARGET COLUMN
    // =========================================================

    function targetColumnAt(
        x,
        y
    ) {
        for (
            let i = 0;
            i < columnRepeater.count;
            ++i
        ) {
            const column =
                columnRepeater.itemAt(i)

            if (!column)
                continue

            const point =
                column.mapFromItem(
                    root,
                    x,
                    y
                )

            if (
                point.x >= 0
                &&
                point.x <= column.width
                &&
                point.y >= 0
                &&
                point.y <= column.height
            ) {
                return column
            }
        }

        return null
    }

    // =========================================================
    // DROP INDEX
    // =========================================================

    function calculateDropIndex(
        column
    ) {
        if (!column)
            return 0

        const list =
            column.cardList

        if (!list)
            return column.columnModel.count

        const point =
            list.contentItem.mapFromItem(
                root,
                dragX,
                dragY
            )

        const y =
            point.y

        for (
            let i = 0;
            i < list.count;
            ++i
        ) {
            const card =
                list.itemAtIndex(i)

            if (!card)
                continue

            if (
                y <
                card.y
                +
                card.height / 2
            ) {
                return i
            }
        }

        return list.count
    }

    function updateDropTarget() {
        const target =
            targetColumnAt(
                dragX,
                dragY
            )

        if (!target) {
            dropKey = ""
            dropIndex = -1
            return
        }

        dropKey =
            target.columnKey

        dropIndex =
            calculateDropIndex(
                target
            )
    }

    // =========================================================
    // START DRAG
    // =========================================================

    function startDrag(
        key,
        index,
        card
    ) {
        const column =
            columnForKey(key)

        if (!column)
            return

        const model =
            column.model

        if (
            index < 0
            ||
            index >= model.count
        ) {
            return
        }

        const task =
            model.get(index)

        draggedKey =
            key

        draggedIndex =
            index

        draggedTitle =
            task.title

        draggedWidth =
            card.width

        draggedHeight =
            card.height

        const mousePos =
            card.mapToItem(
                root,
                card.dragMouseX,
                card.dragMouseY
            )

        const cardPos =
            card.mapToItem(
                root,
                0,
                0
            )

        dragX =
            mousePos.x

        dragY =
            mousePos.y

        grabOffsetX =
            mousePos.x
            -
            cardPos.x

        grabOffsetY =
            mousePos.y
            -
            cardPos.y

        updateDropTarget()
    }

    // =========================================================
    // UPDATE DRAG
    // =========================================================

    function updateDrag(card) {
        const mousePos =
            card.mapToItem(
                root,
                card.dragMouseX,
                card.dragMouseY
            )

        dragX =
            Math.max(
                0,
                Math.min(
                    root.width,
                    mousePos.x
                )
            )

        dragY =
            Math.max(
                0,
                Math.min(
                    root.height,
                    mousePos.y
                )
            )

        updateDropTarget()
    }

    // =========================================================
    // FINISH DRAG
    // =========================================================

    function finishDrag() {
        if (
            draggedKey === ""
            ||
            draggedIndex < 0
        ) {
            clearDrag()
            return
        }

        const target =
            targetColumnAt(
                dragX,
                dragY
            )

        if (!target) {
            clearDrag()
            return
        }

        let targetIndex =
            calculateDropIndex(
                target
            )

        if (
            draggedKey ===
                target.columnKey
            &&
            draggedIndex < targetIndex
        ) {
            targetIndex--
        }

        KanbanService.moveTask(
            draggedKey,
            draggedIndex,
            target.columnKey,
            targetIndex
        )

        clearDrag()
    }

    function clearDrag() {
        draggedKey = ""
        draggedIndex = -1

        draggedTitle = ""

        dragX = 0
        dragY = 0

        grabOffsetX = 0
        grabOffsetY = 0

        draggedWidth = 0
        draggedHeight = 0

        dropKey = ""
        dropIndex = -1
    }

    // =========================================================
    // ADD TASK
    // =========================================================

    function openAddTask(
        key,
        name
    ) {
        addTargetKey =
            key

        addTargetName =
            name

        addTitleField.text =
            ""

        addBodyField.text =
            ""

        addDialogVisible =
            true

        Qt.callLater(function() {
            addTitleField.forceActiveFocus()
        })
    }

    function closeAddTask() {
        addDialogVisible =
            false

        addTargetKey =
            ""

        addTargetName =
            ""

        addTitleField.text =
            ""

        addBodyField.text =
            ""
    }

    function addTask() {
        const title =
            addTitleField.text.trim()

        if (!title)
            return

        KanbanService.addTask(
            addTargetKey,
            title,
            addBodyField.text
        )

        closeAddTask()
    }

    // =========================================================
    // MAIN
    // =========================================================

    ColumnLayout {
        anchors.fill:
            parent

        spacing:
            Tokens.spacing.small

        // =====================================================
        // HEADER
        // =====================================================

        RowLayout {
            Layout.fillWidth:
                true

            spacing:
                Tokens.spacing.small

            MaterialIcon {
                text:
                    "view_kanban"

                color:
                    Colours.palette.m3primary

                fontStyle:
                    Tokens.font.icon.medium
            }

            StyledText {
                Layout.fillWidth:
                    true

                text:
                    "Kanban"

                font:
                    Tokens.font.title.large

                color:
                    Colours.palette.m3onSurface
            }

            // =================================================
            // EDIT BOARD
            // =================================================

            StyledRect {
                id: editBoardButton

                implicitWidth:
                    editButtonContent.implicitWidth
                    +
                    Tokens.padding.medium * 2

                implicitHeight:
                    editButtonContent.implicitHeight
                    +
                    Tokens.padding.small * 2

                radius:
                    Tokens.rounding.large

                color:
                    Colours.palette
                        .m3surfaceContainerHighest

                StateLayer {
                    anchors.fill:
                        parent

                    radius:
                        Tokens.rounding.large

                    onClicked: {
                        KanbanService.openEditor()
                    }
                }

                RowLayout {
                    id: editButtonContent

                    anchors.centerIn:
                        parent

                    spacing:
                        Tokens.spacing.small

                    MaterialIcon {
                        text:
                            "edit"

                        color:
                            Colours.palette.m3primary

                        fontStyle:
                            Tokens.font.icon.small
                    }

                    StyledText {
                        text:
                            "Edit board"

                        font:
                            Tokens.font.label.large

                        color:
                            Colours.palette.m3primary
                    }
                }
            }
        }

        // =====================================================
        // BOARD
        // =====================================================

        RowLayout {
            Layout.fillWidth:
                true

            Layout.fillHeight:
                true

            spacing:
                Tokens.spacing.medium

            Repeater {
                id: columnRepeater

                model:
                    root.columns

                delegate: StyledRect {
                    id: column

                    required property var modelData

                    property string columnKey:
                        modelData.key

                    property string columnTitle:
                        modelData.title

                    property var columnModel:
                        modelData.model

                    property alias cardList:
                        cardListView

                    Layout.fillWidth:
                        true

                    Layout.fillHeight:
                        true

                    Layout.minimumWidth:
                        220

                    Layout.preferredWidth:
                        1

                    radius:
                        Tokens.rounding.extraLarge

                    color:
                        root.dropKey ===
                            column.columnKey
                        ?
                        Colours.palette
                            .m3primaryContainer
                        :
                        Colours.palette
                            .m3surfaceContainer

                    ColumnLayout {
                        anchors.fill:
                            parent

                        anchors.margins:
                            Tokens.padding.large

                        spacing:
                            Tokens.spacing.medium

                        // =============================================
                        // COLUMN HEADER
                        // =============================================

                        RowLayout {
                            Layout.fillWidth:
                                true

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
                                Layout.fillWidth:
                                    true

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
                            Layout.fillWidth:
                                true

                            implicitHeight:
                                1

                            color:
                                Colours.palette.m3outlineVariant
                        }

                        // =============================================
                        // CARD LIST
                        // =============================================

                        ListView {
                            id: cardListView

                            Layout.fillWidth:
                                true

                            Layout.fillHeight:
                                true

                            clip:
                                true

                            model:
                                column.columnModel

                            spacing:
                                Tokens.spacing.small

                            boundsBehavior:
                                Flickable.StopAtBounds

                            flickableDirection:
                                Flickable.VerticalFlick

                            delegate: StyledRect {
                                id: card

                                required property string title
                                required property string body
                                required property int index

                                property real dragMouseX:
                                    0

                                property real dragMouseY:
                                    0

                                property bool beingDragged:
                                    root.draggedKey ===
                                        column.columnKey
                                    &&
                                    root.draggedIndex ===
                                        index

                                width:
                                    cardListView.width

                                implicitHeight:
                                    Math.max(
                                        64,
                                        cardContent.implicitHeight
                                        +
                                        Tokens.padding.medium * 2
                                    )

                                radius:
                                    Tokens.rounding.large

                                color:
                                    Colours.palette.m3surface

                                opacity:
                                    beingDragged
                                    ? 0.18
                                    : 1

                                border.width:
                                    beingDragged
                                    ? 2
                                    : 1

                                border.color:
                                    beingDragged
                                    ? Colours.palette.m3primary
                                    : Colours.palette.m3outlineVariant

                                z:
                                    beingDragged
                                    ? 100
                                    : 0

                                // =========================================
                                // DROP INDICATOR
                                // =========================================

                                Rectangle {
                                    visible:
                                        root.dropKey ===
                                            column.columnKey
                                        &&
                                        root.dropIndex ===
                                            card.index

                                    anchors.left:
                                        parent.left

                                    anchors.right:
                                        parent.right

                                    anchors.bottom:
                                        parent.top

                                    height:
                                        3

                                    radius:
                                        2

                                    color:
                                        Colours.palette.m3primary
                                }

                                // =========================================
                                // DRAG
                                // =========================================

                                MouseArea {
                                    id: dragArea

                                    anchors.fill:
                                        parent

                                    preventStealing:
                                        true

                                    acceptedButtons:
                                        Qt.LeftButton

                                    hoverEnabled:
                                        true

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
                                            column.columnKey,
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

                                        root.updateDrag(
                                            card
                                        )
                                    }

                                    onReleased: {
                                        root.finishDrag()
                                    }

                                    onCanceled: {
                                        root.clearDrag()
                                    }
                                }

                                // =========================================
                                // CARD TITLE
                                // =========================================

                                StyledText {
                                    id: cardContent

                                    anchors.left:
                                        parent.left

                                    anchors.right:
                                        parent.right

                                    anchors.verticalCenter:
                                        parent.verticalCenter

                                    anchors.margins:
                                        Tokens.padding.medium

                                    text:
                                        card.title

                                    font:
                                        Tokens.font.body.medium

                                    color:
                                        Colours.palette.m3onSurface

                                    wrapMode:
                                        Text.Wrap
                                }
                            }
                        }

                        // =============================================
                        // ADD TASK
                        // =============================================

                        StyledRect {
                            Layout.fillWidth:
                                true

                            implicitHeight:
                                addTaskLabel.implicitHeight
                                +
                                Tokens.padding.medium * 2

                            radius:
                                Tokens.rounding.large

                            color:
                                Colours.palette
                                    .m3surfaceContainerHighest

                            StateLayer {
                                anchors.fill:
                                    parent

                                radius:
                                    Tokens.rounding.large

                                onClicked: {
                                    root.openAddTask(
                                        column.columnKey,
                                        column.columnTitle
                                    )
                                }
                            }

                            StyledText {
                                id: addTaskLabel

                                anchors.centerIn:
                                    parent

                                text:
                                    "+ Add task"

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
    }

    // =========================================================
    // FLOATING DRAG PREVIEW
    // =========================================================

    StyledRect {
        id: dragPreview

        visible:
            root.draggedKey !== ""

        z:
            5000

        width:
            root.draggedWidth

        height:
            root.draggedHeight

        x:
            Math.max(
                0,
                Math.min(
                    root.width - width,
                    root.dragX
                    -
                    root.grabOffsetX
                )
            )

        y:
            Math.max(
                0,
                Math.min(
                    root.height - height,
                    root.dragY
                    -
                    root.grabOffsetY
                )
            )

        radius:
            Tokens.rounding.large

        color:
            Colours.palette.m3primaryContainer

        border.width:
            2

        border.color:
            Colours.palette.m3primary

        opacity:
            0.95

        enabled:
            false

        StyledText {
            anchors.left:
                parent.left

            anchors.right:
                parent.right

            anchors.verticalCenter:
                parent.verticalCenter

            anchors.margins:
                Tokens.padding.medium

            text:
                root.draggedTitle

            font:
                Tokens.font.body.medium

            color:
                Colours.palette.m3onPrimaryContainer

            wrapMode:
                Text.Wrap
        }
    }

    // =========================================================
    // ADD TASK DIALOG
    // =========================================================

    Rectangle {
        id: addOverlay

        anchors.fill:
            parent

        visible:
            root.addDialogVisible

        z:
            6000

        color:
            Qt.alpha(
                Colours.palette.m3scrim,
                0.55
            )

        MouseArea {
            anchors.fill:
                parent

            onClicked: {
                root.closeAddTask()
            }
        }

        StyledRect {
            id: addDialog

            anchors.centerIn:
                parent

            width:
                Math.min(
                    parent.width
                    -
                    Tokens.padding.large * 2,
                    520
                )

            implicitHeight:
                addContent.implicitHeight
                +
                Tokens.padding.large * 2

            radius:
                Tokens.rounding.extraLarge

            color:
                Colours.palette.m3surfaceContainerHigh

            border.width:
                1

            border.color:
                Colours.palette.m3outlineVariant

            MouseArea {
                anchors.fill:
                    parent

                onClicked: {}
            }

            ColumnLayout {
                id: addContent

                anchors.fill:
                    parent

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
                        +
                        root.addTargetName

                    font:
                        Tokens.font.body.small

                    color:
                        Colours.palette.m3onSurfaceVariant
                }

                StyledTextField {
                    id: addTitleField

                    Layout.fillWidth:
                        true

                    placeholderText:
                        "Task title"

                    onAccepted: {
                        root.addTask()
                    }
                }

                Rectangle {
                    Layout.fillWidth:
                        true

                    Layout.preferredHeight:
                        140

                    radius:
                        Tokens.rounding.large

                    color:
                        Colours.palette.m3surface

                    border.width:
                        1

                    border.color:
                        Colours.palette.m3outlineVariant

                    TextEdit {
                        id: addBodyField

                        anchors.fill:
                            parent

                        anchors.margins:
                            Tokens.padding.medium

                        textFormat:
                            TextEdit.PlainText

                        wrapMode:
                            TextEdit.Wrap

                        font:
                            Tokens.font.body.medium

                        color:
                            Colours.palette.m3onSurface

                        selectByMouse:
                            true
                    }
                }

                RowLayout {
                    Layout.fillWidth:
                        true

                    Item {
                        Layout.fillWidth:
                            true
                    }

                    TextButton {
                        text:
                            "Cancel"

                        onClicked: {
                            root.closeAddTask()
                        }
                    }

                    TextButton {
                        text:
                            "Add"

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

    // =========================================================
    // OPEN WITH EDITOR
    // =========================================================

    Rectangle {
        id: editorOverlay

        anchors.fill:
            parent

        visible:
            root.editorDialogVisible

        z:
            7000

        color:
            Qt.alpha(
                Colours.palette.m3scrim,
                0.55
            )

        MouseArea {
            anchors.fill:
                parent

            onClicked: {
                root.editorDialogVisible =
                    false
            }
        }

        StyledRect {
            id: editorDialog

            anchors.centerIn:
                parent

            width:
                Math.min(
                    parent.width
                    -
                    Tokens.padding.large * 2,
                    440
                )

            implicitHeight:
                editorContent.implicitHeight
                +
                Tokens.padding.large * 2

            radius:
                Tokens.rounding.extraLarge

            color:
                Colours.palette.m3surfaceContainerHigh

            border.width:
                1

            border.color:
                Colours.palette.m3outlineVariant

            MouseArea {
                anchors.fill:
                    parent

                onClicked: {}
            }

            ColumnLayout {
                id: editorContent

                anchors.fill:
                    parent

                anchors.margins:
                    Tokens.padding.large

                spacing:
                    Tokens.spacing.small

                StyledText {
                    Layout.fillWidth:
                        true

                    text:
                        "Open board with…"

                    font:
                        Tokens.font.headline.small

                    color:
                        Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.fillWidth:
                        true

                    text:
                        KanbanService.kanbanPath

                    font:
                        Tokens.font.body.small

                    color:
                        Colours.palette.m3onSurfaceVariant

                    elide:
                        Text.ElideMiddle
                }

                Item {
                    implicitHeight:
                        Tokens.padding.small
                }

                Repeater {
                    model:
                        KanbanService.availableEditors

                    delegate: StyledRect {
                        required property var modelData

                        Layout.fillWidth:
                            true

                        implicitHeight:
                            editorName.implicitHeight
                            +
                            Tokens.padding.medium * 2

                        radius:
                            Tokens.rounding.large

                        color:
                            Colours.palette.m3surface

                        StateLayer {
                            anchors.fill:
                                parent

                            radius:
                                Tokens.rounding.large

                            onClicked: {
                                root.editorDialogVisible =
                                    false

                                KanbanService.launchEditor(
                                    modelData.command
                                )
                            }
                        }

                        RowLayout {
                            anchors.fill:
                                parent

                            anchors.margins:
                                Tokens.padding.medium

                            spacing:
                                Tokens.spacing.medium

                            MaterialIcon {
                                text:
                                    modelData.icon

                                color:
                                    Colours.palette.m3primary

                                fontStyle:
                                    Tokens.font.icon.medium
                            }

                            StyledText {
                                id: editorName

                                Layout.fillWidth:
                                    true

                                text:
                                    modelData.name

                                font:
                                    Tokens.font.body.medium

                                color:
                                    Colours.palette.m3onSurface
                            }

                            MaterialIcon {
                                text:
                                    "chevron_right"

                                color:
                                    Colours.palette.m3onSurfaceVariant

                                fontStyle:
                                    Tokens.font.icon.small
                            }
                        }
                    }
                }

                StyledText {
                    visible:
                        KanbanService.availableEditors.length === 0

                    Layout.fillWidth:
                        true

                    horizontalAlignment:
                        Text.AlignHCenter

                    text:
                        "No supported editor was found."

                    font:
                        Tokens.font.body.medium

                    color:
                        Colours.palette.m3onSurfaceVariant
                }

                Item {
                    implicitHeight:
                        Tokens.padding.small
                }

                RowLayout {
                    Layout.fillWidth:
                        true

                    Item {
                        Layout.fillWidth:
                            true
                    }

                    TextButton {
                        text:
                            "Cancel"

                        onClicked: {
                            root.editorDialogVisible =
                                false
                        }
                    }
                }
            }
        }
    }
}