import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import NotesApp 1.0

ApplicationWindow {
    id: window
    width: 1000
    height: 700
    visible: true
    title: "Simple Notes"
    color: notesManager.config.backgroundColor

    property bool isGridView: true
    property int currentNoteId: -1
    property var currentNote: ({})
    property int selectedNoteIndex: 0
    property bool showDeleteConfirm: false

    // Auto-save timer
    Timer {
        id: autoSaveTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!isGridView && currentNote.content !== undefined) {
                saveCurrentNote()
            }
        }
    }

    // Focus timer for auto-focus
    Timer {
        id: focusTimer
        interval: 50  // Reduced from 250ms to 50ms for quicker focus
        repeat: false
        onTriggered: {
            if (!isGridView && stackView.currentItem) {
                var textArea = stackView.currentItem.findChild("contentArea")
                if (textArea) {
                    textArea.forceActiveFocus()
                    textArea.cursorPosition = textArea.length  // Position cursor at end
                }
            }
        }
    }

    // Grid view keyboard shortcuts
    Shortcut {
        sequence: "Ctrl+N"
        onActivated: createNewNote()
    }
    
    Shortcut {
        sequence: "Up"
        enabled: isGridView && notesManager.notes.length > 0
        onActivated: {
            var cols = Math.floor((window.width - 40) / 250)
            selectedNoteIndex = Math.max(0, selectedNoteIndex - cols)
        }
    }
    
    Shortcut {
        sequence: "Down"
        enabled: isGridView && notesManager.notes.length > 0
        onActivated: {
            var cols = Math.floor((window.width - 40) / 250)
            selectedNoteIndex = Math.min(notesManager.notes.length - 1, selectedNoteIndex + cols)
        }
    }
    
    Shortcut {
        sequence: "Left"
        enabled: isGridView && notesManager.notes.length > 0
        onActivated: {
            selectedNoteIndex = Math.max(0, selectedNoteIndex - 1)
        }
    }
    
    Shortcut {
        sequence: "Right"
        enabled: isGridView && notesManager.notes.length > 0
        onActivated: {
            selectedNoteIndex = Math.min(notesManager.notes.length - 1, selectedNoteIndex + 1)
        }
    }
    
    Shortcut {
        sequence: "Return"
        enabled: isGridView && notesManager.notes.length > 0
        onActivated: {
            if (selectedNoteIndex >= 0 && selectedNoteIndex < notesManager.notes.length) {
                editNote(notesManager.notes[selectedNoteIndex].id)
            }
        }
    }
    
    Shortcut {
        sequence: "Delete"
        enabled: isGridView && notesManager.notes.length > 0 && !showDeleteConfirm
        onActivated: {
            if (selectedNoteIndex >= 0 && selectedNoteIndex < notesManager.notes.length) {
                showDeleteConfirm = true
            }
        }
    }
    
    // Delete confirmation shortcuts
    Shortcut {
        sequence: "Y"
        enabled: showDeleteConfirm
        onActivated: confirmDelete()
    }
    
    Shortcut {
        sequence: "Return"
        enabled: showDeleteConfirm
        onActivated: confirmDelete()
    }
    
    Shortcut {
        sequence: "N"
        enabled: showDeleteConfirm
        onActivated: showDeleteConfirm = false
    }
    
    Shortcut {
        sequence: "Escape"
        enabled: showDeleteConfirm
        onActivated: showDeleteConfirm = false
    }
    
    // Editor shortcuts
    Shortcut {
        sequence: "Escape"
        enabled: !isGridView && !showDeleteConfirm
        onActivated: {
            saveCurrentNote()
            showGridView()
        }
    }
    
    Shortcut {
        sequence: "Ctrl+D"
        enabled: !isGridView && currentNoteId >= 0 && !showDeleteConfirm
        onActivated: {
            showDeleteConfirm = true
        }
    }

    // Functions
    function createNewNote() {
        currentNoteId = -1
        currentNote = { id: -1, title: "", content: "" }
        showNoteEditor()
        // Start focus timer immediately after showing editor
        focusTimer.start()
    }

    function showGridView() {
        isGridView = true
        showDeleteConfirm = false
        stackView.pop()
        selectedNoteIndex = Math.min(selectedNoteIndex, Math.max(0, notesManager.notes.length - 1))
    }

    function showNoteEditor() {
        isGridView = false
        showDeleteConfirm = false
        stackView.push(noteEditor)
        // Always start focus timer when showing editor
        focusTimer.start()
    }

    function editNote(noteId) {
        currentNoteId = noteId
        currentNote = notesManager.getNote(noteId)
        showNoteEditor()
    }

    function saveCurrentNote() {
        if (currentNote.content !== undefined && currentNote.content.trim() !== "") {
            if (currentNoteId === -1) {
                currentNoteId = notesManager.createNote(currentNote.content)
            } else {
                notesManager.updateNote(currentNoteId, currentNote.content)
            }
        }
    }

    function confirmDelete() {
        if (isGridView && selectedNoteIndex >= 0 && selectedNoteIndex < notesManager.notes.length) {
            notesManager.deleteNote(notesManager.notes[selectedNoteIndex].id)
            selectedNoteIndex = Math.min(selectedNoteIndex, notesManager.notes.length - 1)
        } else if (!isGridView && currentNoteId >= 0) {
            notesManager.deleteNote(currentNoteId)
            showGridView()
        }
        showDeleteConfirm = false
    }

    // Main stack view for navigation
    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: gridView

        onCurrentItemChanged: {
            if (!isGridView && currentItem) {
                focusTimer.start()
            }
        }

        popEnter: Transition {
            PropertyAnimation {
                property: "x"
                from: -window.width
                to: 0
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        popExit: Transition {
            PropertyAnimation {
                property: "x"
                from: 0
                to: window.width
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        pushEnter: Transition {
            PropertyAnimation {
                property: "x"
                from: window.width
                to: 0
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        pushExit: Transition {
            PropertyAnimation {
                property: "x"
                from: 0
                to: -window.width
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    // Delete confirmation modal overlay
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: showDeleteConfirm ? 0.7 : 0
        visible: showDeleteConfirm
        
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: showDeleteConfirm = false
        }
    }

    // Delete confirmation dialog
    Rectangle {
        anchors.centerIn: parent
        width: 400
        height: 150
        color: notesManager.config.cardColor
        radius: 10
        border.color: notesManager.config.accentColor
        border.width: 2
        visible: showDeleteConfirm
        
        Column {
            anchors.centerIn: parent
            spacing: 20
            
            Text {
                text: "Delete this note?"
                font.family: notesManager.config.fontFamily
                font.pixelSize: 18
                color: notesManager.config.textColor
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Text {
                text: "This action cannot be undone."
                font.family: notesManager.config.fontFamily
                font.pixelSize: 12
                color: Qt.lighter(notesManager.config.textColor, 0.7)
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Row {
                spacing: 15
                anchors.horizontalCenter: parent.horizontalCenter
                
                Button {
                    text: "Yes (Y/Enter)"
                    onClicked: confirmDelete()
                    background: Rectangle {
                        color: "#e74c3c"
                        radius: 5
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.family: notesManager.config.fontFamily
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                
                Button {
                    text: "No (N/Esc)"
                    onClicked: showDeleteConfirm = false
                    background: Rectangle {
                        color: "transparent"
                        border.color: notesManager.config.textColor
                        border.width: 1
                        radius: 5
                    }
                    contentItem: Text {
                        text: parent.text
                        color: notesManager.config.textColor
                        font.family: notesManager.config.fontFamily
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    // Grid View Component
    Component {
        id: gridView
        
        Rectangle {
            color: notesManager.config.backgroundColor
            
            Column {
                anchors.fill: parent
                
                // Header section
                Rectangle {
                    width: parent.width
                    height: 80
                    color: notesManager.config.cardColor
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        
                        Column {
                            Layout.fillWidth: true
                            
                            Text {
                                text: "Note Collection"
                                font.family: notesManager.config.fontFamily
                                font.pixelSize: 24
                                color: notesManager.config.textColor
                            }
                            
                            Text {
                                text: "Arrow keys to navigate • Enter to open • Delete to remove • Ctrl+N for new"
                                font.family: notesManager.config.fontFamily
                                font.pixelSize: 11
                                color: Qt.lighter(notesManager.config.textColor, 0.7)
                                opacity: 0.8
                            }
                        }
                        
                        Button {
                            text: "New Note (Ctrl+N)"
                            onClicked: createNewNote()
                            background: Rectangle {
                                color: notesManager.config.accentColor
                                radius: 5
                            }
                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                font.family: notesManager.config.fontFamily
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
                
                // Notes grid section
                ScrollView {
                    width: parent.width
                    height: parent.height - 80
                    
                    GridView {
                        id: notesGrid
                        anchors.fill: parent
                        anchors.margins: 20
                        cellWidth: 250
                        cellHeight: 200
                        model: notesManager.notes
                        
                        delegate: Rectangle {
                            width: 230
                            height: 180
                            color: index === selectedNoteIndex ? 
                                   Qt.lighter(notesManager.config.accentColor, 1.3) : 
                                   notesManager.config.cardColor
                            radius: 8
                            border.color: index === selectedNoteIndex ? 
                                         notesManager.config.accentColor : 
                                         Qt.lighter(notesManager.config.cardColor, 1.2)
                            border.width: index === selectedNoteIndex ? 3 : 1
                            
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    selectedNoteIndex = index
                                    editNote(modelData.id)
                                }
                                onEntered: {
                                    if (index !== selectedNoteIndex) {
                                        parent.color = Qt.lighter(notesManager.config.cardColor, 1.1)
                                    }
                                }
                                onExited: {
                                    if (index !== selectedNoteIndex) {
                                        parent.color = notesManager.config.cardColor
                                    }
                                }
                            }
                            
                            Column {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 10
                                
                                Text {
                                    text: modelData.title
                                    font.family: notesManager.config.fontFamily
                                    font.pixelSize: notesManager.config.cardFontSize + 2
                                    font.bold: true
                                    color: index === selectedNoteIndex ? "white" : notesManager.config.textColor
                                    width: parent.width
                                    elide: Text.ElideRight
                                }
                                
                                Text {
                                    text: modelData.content.length > 100 ? 
                                          modelData.content.substring(0, 100) + "..." : 
                                          modelData.content
                                    font.family: notesManager.config.fontFamily
                                    font.pixelSize: notesManager.config.cardFontSize
                                    color: index === selectedNoteIndex ? 
                                           Qt.lighter("white", 0.9) : 
                                           Qt.lighter(notesManager.config.textColor, 0.8)
                                    width: parent.width
                                    height: parent.height - 30
                                    wrapMode: Text.WordWrap
                                    clip: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Note Editor Component
    Component {
        id: noteEditor
        
        Rectangle {
            color: notesManager.config.backgroundColor
            
            Column {
                anchors.fill: parent
                
                // Editor header
                Rectangle {
                    width: parent.width
                    height: 60
                    color: notesManager.config.cardColor
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        
                        Button {
                            text: "← Back (Esc)"
                            onClicked: {
                                saveCurrentNote()
                                showGridView()
                            }
                            background: Rectangle {
                                color: "transparent"
                                border.color: notesManager.config.textColor
                                border.width: 1
                                radius: 5
                            }
                            contentItem: Text {
                                text: parent.text
                                color: notesManager.config.textColor
                                font.family: notesManager.config.fontFamily
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        
                        Text {
                            text: currentNote.title || "New Note"
                            font.family: notesManager.config.fontFamily
                            font.pixelSize: 16
                            color: notesManager.config.textColor
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.leftMargin: 15
                        }
                        
                        Text {
                            text: "Auto-saved"
                            font.family: notesManager.config.fontFamily
                            font.pixelSize: 12
                            color: Qt.lighter(notesManager.config.textColor, 0.6)
                            Layout.rightMargin: 15
                        }
                        
                        Button {
                            text: "Delete (Ctrl+D)"
                            visible: currentNoteId >= 0
                            onClicked: showDeleteConfirm = true
                            background: Rectangle {
                                color: "#e74c3c"
                                radius: 5
                            }
                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                font.family: notesManager.config.fontFamily
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
                
                // Text editing area
                Rectangle {
                    width: parent.width
                    height: parent.height - 60
                    color: notesManager.config.backgroundColor
                    
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 20
                        
                        TextArea {
                            id: contentArea
                            objectName: "contentArea"
                            placeholderText: "Start writing your note...\n\nThe first line will become your note's title automatically."
                            text: currentNote.content || ""
                            font.family: notesManager.config.fontFamily
                            font.pixelSize: notesManager.config.fontSize
                            color: notesManager.config.textColor
                            wrapMode: TextArea.Wrap
                            selectByMouse: true
                            
                            onTextChanged: {
                                currentNote.content = text
                                
                                // Update title in real-time
                                if (text.trim()) {
                                    var firstLine = text.split('\n')[0].trim()
                                    if (firstLine.length > 50) {
                                        firstLine = firstLine.substring(0, 47) + "..."
                                    }
                                    currentNote.title = firstLine || "Untitled Note"
                                } else {
                                    currentNote.title = "New Note"
                                }
                                
                                // Restart auto-save timer
                                autoSaveTimer.restart()
                            }
                            
                            background: Rectangle {
                                color: notesManager.config.cardColor
                                radius: 5
                                border.color: parent.activeFocus ? notesManager.config.accentColor : "transparent"
                                border.width: 2
                            }
                        }
                    }
                }
            }
        }
    }
}