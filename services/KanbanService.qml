pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // =========================================================
    // FILE
    // =========================================================

    readonly property string kanbanPath:
        Quickshell.shellDir + "/data/kanban.md"

    // =========================================================
    // MODELS
    // =========================================================

    property ListModel backlog:
        ListModel {}

    property ListModel progress:
        ListModel {}

    property ListModel done:
        ListModel {}

    // =========================================================
    // STATE
    // =========================================================

    property bool ready: false
    property bool saving: false

    // =========================================================
    // MARKDOWN FILE
    // =========================================================

    property FileView markdownFile:
        FileView {
            path:
                root.kanbanPath

            watchChanges:
                true

            printErrors:
                true

            onLoaded: {
                console.log(
                    "KANBAN FILE LOADED:",
                    root.kanbanPath
                )

                root.parseMarkdown(
                    markdownFile.text()
                )

                root.ready = true

                root.debugCounts()
            }

            onFileChanged: {
                console.log(
                    "KANBAN FILE CHANGED"
                )

                markdownFile.reload()
            }

            onSaved: {
                root.saving = false

                console.log(
                    "KANBAN FILE SAVED"
                )
            }

            onLoadFailed: function(error) {
                console.error(
                    "KANBAN FILE LOAD FAILED:",
                    root.kanbanPath,
                    error
                )
            }

            onSaveFailed: function(error) {
                root.saving = false

                console.error(
                    "KANBAN FILE SAVE FAILED:",
                    error
                )
            }
        }

    // =========================================================
    // STARTUP
    // =========================================================

    Component.onCompleted: {
        console.log(
            "KANBAN PATH:",
            root.kanbanPath
        )

        markdownFile.reload()
    }

    // =========================================================
    // DEBUG
    // =========================================================

    function debugCounts() {
        console.log(
            "KANBAN:",
            backlog.count,
            "Backlog |",
            progress.count,
            "In Progress |",
            done.count,
            "Done"
        )
    }

    // =========================================================
    // MODEL LOOKUP
    // =========================================================

    function modelForKey(key) {
        if (key === "backlog")
            return backlog

        if (key === "progress")
            return progress

        if (key === "done")
            return done

        return null
    }

    function keyForCategory(title) {
        const normalized =
            String(title)
                .trim()
                .toLowerCase()

        if (
            normalized === "backlog"
        ) {
            return "backlog"
        }

        if (
            normalized === "in progress"
            ||
            normalized === "in-progress"
            ||
            normalized === "in_progress"
        ) {
            return "progress"
        }

        if (
            normalized === "done"
        ) {
            return "done"
        }

        return ""
    }

    // =========================================================
    // MARKDOWN PARSER
    //
    // # Category
    //
    // ## Card
    //
    // Card body
    // =========================================================

    function parseMarkdown(source) {
        backlog.clear()
        progress.clear()
        done.clear()

        let currentModel = null
        let currentIndex = -1

        const lines =
            String(source || "")
                .replace(
                    /\r\n?/g,
                    "\n"
                )
                .split("\n")

        for (
            let i = 0;
            i < lines.length;
            ++i
        ) {
            const line =
                lines[i]

            // ---------------------------------------------
            // CATEGORY
            // ---------------------------------------------

            if (
                /^#\s+[^#]/.test(line)
            ) {
                const category =
                    line
                        .replace(
                            /^#\s+/,
                            ""
                        )
                        .trim()

                currentModel =
                    modelForKey(
                        keyForCategory(
                            category
                        )
                    )

                currentIndex = -1

                continue
            }

            // ---------------------------------------------
            // CARD
            // ---------------------------------------------

            if (
                /^##\s+[^#]/.test(line)
            ) {
                if (!currentModel)
                    continue

                const title =
                    line
                        .replace(
                            /^##\s+/,
                            ""
                        )
                        .trim()

                if (!title)
                    continue

                currentModel.append({
                    title: title,
                    body: ""
                })

                currentIndex =
                    currentModel.count - 1

                continue
            }

            // ---------------------------------------------
            // BODY
            // ---------------------------------------------

            if (
                currentModel
                &&
                currentIndex >= 0
            ) {
                const existing =
                    String(
                        currentModel.get(
                            currentIndex
                        ).body || ""
                    )

                const body =
                    existing === ""
                    ? line
                    : existing
                        + "\n"
                        + line

                currentModel.setProperty(
                    currentIndex,
                    "body",
                    body
                )
            }
        }
    }

    // =========================================================
    // SERIALIZATION
    // =========================================================

    function serializeModel(
        output,
        heading,
        model
    ) {
        output.push(
            "# " + heading
        )

        output.push("")

        for (
            let i = 0;
            i < model.count;
            ++i
        ) {
            const task =
                model.get(i)

            output.push(
                "## " + task.title
            )

            const body =
                String(
                    task.body || ""
                ).replace(
                    /\s+$/,
                    ""
                )

            if (body !== "") {
                output.push("")
                output.push(body)
            }

            output.push("")
        }
    }

    function serializeMarkdown() {
        const output = []

        serializeModel(
            output,
            "Backlog",
            backlog
        )

        serializeModel(
            output,
            "In Progress",
            progress
        )

        serializeModel(
            output,
            "Done",
            done
        )

        return output.join("\n")
    }

    // =========================================================
    // SAVE
    // =========================================================

    function save() {
        if (!ready) {
            console.warn(
                "KANBAN: refusing to save before initial load"
            )

            return false
        }

        saving = true

        markdownFile.setText(
            serializeMarkdown()
        )

        return true
    }

    // =========================================================
    // ADD
    // =========================================================

    function addTask(
        key,
        title,
        body
    ) {
        const model =
            modelForKey(key)

        if (!model)
            return false

        const cleanTitle =
            String(title || "")
                .trim()

        if (!cleanTitle)
            return false

        model.append({
            title: cleanTitle,
            body: String(body || "")
        })

        return save()
    }

    // =========================================================
    // DELETE
    // =========================================================

    function removeTask(
        key,
        index
    ) {
        const model =
            modelForKey(key)

        if (!model)
            return false

        if (
            index < 0
            ||
            index >= model.count
        ) {
            return false
        }

        model.remove(index)

        return save()
    }

    // =========================================================
    // MOVE / REORDER
    // =========================================================

    function moveTask(
        sourceKey,
        sourceIndex,
        targetKey,
        targetIndex
    ) {
        const source =
            modelForKey(sourceKey)

        const target =
            modelForKey(targetKey)

        if (!source || !target)
            return false

        if (
            sourceIndex < 0
            ||
            sourceIndex >= source.count
        ) {
            return false
        }

        const task =
            source.get(sourceIndex)

        const copy = {
            title: task.title,
            body: task.body
        }

        source.remove(
            sourceIndex
        )

        let index =
            Number(targetIndex)

        if (!Number.isFinite(index))
            index = target.count

        if (
            source === target
            &&
            sourceIndex < index
        ) {
            index--
        }

        index =
            Math.max(
                0,
                Math.min(
                    target.count,
                    index
                )
            )

        target.insert(
            index,
            copy
        )

        return save()
    }

    // =========================================================
    // UPDATE
    // =========================================================

    function updateTask(
        key,
        index,
        title,
        body
    ) {
        const model =
            modelForKey(key)

        if (!model)
            return false

        if (
            index < 0
            ||
            index >= model.count
        ) {
            return false
        }

        const cleanTitle =
            String(title || "")
                .trim()

        if (!cleanTitle)
            return false

        model.setProperty(
            index,
            "title",
            cleanTitle
        )

        model.setProperty(
            index,
            "body",
            String(body || "")
        )

        return save()
    }

    // =========================================================
    // EDITOR DETECTION
    // =========================================================

    readonly property var editorCandidates: [
        {
            command: "nvim",
            name: "Neovim",
            terminal: true,
            icon: "terminal"
        },
        {
            command: "vim",
            name: "Vim",
            terminal: true,
            icon: "terminal"
        },
        {
            command: "nano",
            name: "Nano",
            terminal: true,
            icon: "terminal"
        },
        {
            command: "emacs",
            name: "Emacs",
            terminal: true,
            icon: "terminal"
        },
        {
            command: "code",
            name: "Visual Studio Code",
            terminal: false,
            icon: "code"
        },
        {
            command: "codium",
            name: "VSCodium",
            terminal: false,
            icon: "code"
        },
        {
            command: "zed",
            name: "Zed",
            terminal: false,
            icon: "code"
        }
    ]

    property var availableEditors: []

    property int editorCheckIndex: -1
    property string editorCheckCommand: ""

    signal editorUnavailable()

    // ---------------------------------------------------------
    // Editor executable checker
    // ---------------------------------------------------------

    property Process editorChecker:
        Process {
            command: [
                "sh",
                "-c",
                "command -v \"$1\" >/dev/null 2>&1",
                "kanban-editor-check",
                root.editorCheckCommand
            ]

            onExited: function(exitCode) {
                const index =
                    root.editorCheckIndex

                if (
                    index < 0
                    ||
                    index >=
                        root.editorCandidates.length
                ) {
                    return
                }

                const candidate =
                    root.editorCandidates[index]

                if (exitCode === 0) {
                    root.availableEditors =
                        root.availableEditors.concat([
                            candidate
                        ])
                }

                root.checkNextEditor()
            }
        }

    // =========================================================
    // OPEN EDITOR
    // =========================================================

    function openEditor() {
        availableEditors = []

        editorCheckIndex = -1
        editorCheckCommand = ""

        checkNextEditor()
    }

    function checkNextEditor() {
        editorCheckIndex++

        if (
            editorCheckIndex >=
            editorCandidates.length
        ) {
            finishEditorDetection()
            return
        }

        const candidate =
            editorCandidates[
                editorCheckIndex
            ]

        editorCheckCommand =
            candidate.command

        editorChecker.command = [
            "sh",
            "-c",
            "command -v \"$1\" >/dev/null 2>&1",
            "kanban-editor-check",
            candidate.command
        ]

        editorChecker.running =
            true
    }

    function finishEditorDetection() {
        editorCheckIndex = -1
        editorCheckCommand = ""

        console.log(
            "KANBAN EDITORS FOUND:",
            availableEditors.length
        )

        for (
            let i = 0;
            i < availableEditors.length;
            ++i
        ) {
            console.log(
                "EDITOR:",
                availableEditors[i].command
            )
        }

        // Exactly one editor:
        // open it immediately.
        if (
            availableEditors.length === 1
        ) {
            launchEditor(
                availableEditors[0].command
            )

            return
        }

        // Zero or multiple editors:
        // Kanban.qml will show Open With.
        editorUnavailable()
    }

    // =========================================================
    // LAUNCH SELECTED EDITOR
    // =========================================================

    function launchEditor(
        command
    ) {
        let candidate = null

        for (
            let i = 0;
            i < editorCandidates.length;
            ++i
        ) {
            if (
                editorCandidates[i].command
                === command
            ) {
                candidate =
                    editorCandidates[i]

                break
            }
        }

        if (!candidate) {
            return
        }

        if (!candidate.terminal) {
            Quickshell.execDetached([
                command,
                kanbanPath
            ])

            return
        }

        launchTerminalEditor(
            command
        )
    }

    // =========================================================
    // TERMINAL EDITOR
    // =========================================================

    readonly property var terminalCandidates: [
        "kitty",
        "foot",
        "alacritty",
        "wezterm",
        "konsole",
        "gnome-terminal"
    ]

    property int terminalIndex: -1
    property string terminalEditor: ""
    property string terminalCommand: ""

    property Process terminalChecker:
        Process {
            command: [
                "sh",
                "-c",
                "command -v \"$1\" >/dev/null 2>&1",
                "kanban-terminal-check",
                root.terminalCommand
            ]

            onExited: function(exitCode) {
                if (
                    !root.terminalCommand
                ) {
                    return
                }

                const terminal =
                    root.terminalCommand

                root.terminalCommand =
                    ""

                if (exitCode === 0) {
                    root.launchTerminal(
                        terminal,
                        root.terminalEditor
                    )

                    root.terminalEditor =
                        ""

                    root.terminalIndex =
                        -1

                    return
                }

                root.checkNextTerminal()
            }
        }

    function launchTerminalEditor(
        editor
    ) {
        const envTerminal =
            Quickshell.env("TERMINAL")

        if (
            envTerminal
            &&
            envTerminal.trim() !== ""
        ) {
            launchTerminal(
                envTerminal.trim(),
                editor
            )

            return
        }

        terminalIndex = -1
        terminalEditor = editor

        checkNextTerminal()
    }

    function checkNextTerminal() {
        terminalIndex++

        if (
            terminalIndex >=
            terminalCandidates.length
        ) {
            terminalIndex = -1
            terminalEditor = ""

            editorUnavailable()

            return
        }

        const terminal =
            terminalCandidates[
                terminalIndex
            ]

        terminalCommand =
            terminal

        terminalChecker.command = [
            "sh",
            "-c",
            "command -v \"$1\" >/dev/null 2>&1",
            "kanban-terminal-check",
            terminal
        ]

        terminalChecker.running =
            true
    }

    function launchTerminal(
        terminal,
        editor
    ) {
        if (
            terminal === "wezterm"
        ) {
            Quickshell.execDetached([
                terminal,
                "start",
                "--",
                editor,
                kanbanPath
            ])

            return
        }

        if (
            terminal ===
            "gnome-terminal"
        ) {
            Quickshell.execDetached([
                terminal,
                "--",
                editor,
                kanbanPath
            ])

            return
        }

        Quickshell.execDetached([
            terminal,
            "-e",
            editor,
            kanbanPath
        ])
    }
}