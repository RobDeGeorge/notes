import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import NotesApp 1.0

ApplicationWindow {
    id: window
    width: 1200
    height: 800
    visible: true
    title: "Simple Notes - Ultra Keyboard Friendly"
    color: notesManager.config.backgroundColor

    property bool isGridView: true
    property bool isSearchMode: false
    property int currentNoteId: -1
    property var currentNote: ({})
    property int selectedNoteIndex: 0
    property bool showDeleteConfirm: false
    property bool showHelpDialog: false
    property string searchText: ""
    property var filteredNotes: notesManager.notes
    property bool navigating: false  // Add navigation throttle

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

    // Focus timer for auto-focus - reduced interval for faster focus
    Timer {
        id: focusTimer
        interval: 10  // Reduced from 50
        repeat: false
        onTriggered: {
            if (!isGridView && stackView.currentItem && !isSearchMode) {
                var textArea = stackView.currentItem.findChild("contentArea")
                if (textArea) {
                    textArea.forceActiveFocus()
                    textArea.cursorPosition = textArea.length
                }
            } else if (isSearchMode) {
                searchField.forceActiveFocus()
            }
        }
    }

    // Navigation throttle timer
    Timer {
        id: navigationTimer
        interval: 50  // Throttle navigation to prevent lag
        repeat: false
        onTriggered: navigating = false
    }

    // Keyboard shortcuts
    Shortcut {
        sequence: notesManager.config.shortcuts.newNote
        enabled: isGridView  // Only allow new note from grid view
        onActivated: createNewNote()
    }
    
    Shortcut {
        sequence: notesManager.config.shortcuts.search
        onActivated: {
            if (isGridView && !showDeleteConfirm) {
                enterSearchMode()
            }
        }
    }
    
    Shortcut {
        sequence: notesManager.config.shortcuts.help
        onActivated: showHelpDialog = !showHelpDialog
    }
    
    Shortcut {
        sequence: notesManager.config.shortcuts.quit
        onActivated: {
            if (!isGridView) saveCurrentNote()
            Qt.quit()
        }
    }
    
    // Navigation shortcuts with throttling
    Shortcut {
        sequence: "Up"
        enabled: isGridView && !showDeleteConfirm && !isSearchMode && !navigating
        onActivated: navigateGrid("up")
    }
    
    Shortcut {
        sequence: "K"
        enabled: isGridView && !showDeleteConfirm && !isSearchMode && !navigating
        onActivated: navigateGrid("up")
    }
    
    Shortcut {
        sequence: "Down"
        enabled: isGridView && !showDeleteConfirm && !isSearchMode && !navigating
        onActivated: navigateGrid("down")
    }
    
    Shortcut {
        sequence: "J"
        enabled: isGridView && !showDeleteConfirm && !isSearchMode && !navigating
        onActivated: navigateGrid("down")
    }
    
    Shortcut {
        sequence: "Left"
        enabled: isGridView && !showDeleteConfirm && !isSearchMode && !navigating
        onActivated: navigateGrid("left")
    }
    
    Shortcut {
        sequence: "H"
        enabled: isGridView && !showDeleteConfirm && !isSearchMode && !navigating
        onActivated: navigateGrid("left")
    }
    
    Shortcut {
        sequence: "Right"
        enabled: isGridView && !showDeleteConfirm && !isSearchMode && !navigating
        onActivated: navigateGrid("right")
    }
    
    Shortcut {
        sequence: "L"
        enabled: isGridView && !showDeleteConfirm && !isSearchMode && !navigating
        onActivated: navigateGrid("right")
    }
    
    // Open note shortcuts
    Shortcut {
        sequence: "Return"
        enabled: isGridView && filteredNotes.length > 0 && !showDeleteConfirm && !isSearchMode
        onActivated: editNote(filteredNotes[selectedNoteIndex].id)
    }
    
    Shortcut {
        sequence: "Space"
        enabled: isGridView && filteredNotes.length > 0 && !showDeleteConfirm && !isSearchMode
        onActivated: editNote(filteredNotes[selectedNoteIndex].id)
    }
    
    // Delete shortcuts - Fixed to use correct key sequence
    Shortcut {
        sequence: "Delete"  // Use direct key instead of config
        enabled: isGridView && filteredNotes.length > 0 && !showDeleteConfirm && !isSearchMode
        onActivated: showDeleteConfirm = true
    }
    
    Shortcut {
        sequence: "Ctrl+D"  // Use direct key instead of config
        enabled: !isGridView && currentNoteId >= 0 && !showDeleteConfirm && !isSearchMode
        onActivated: showDeleteConfirm = true
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
    
    // Escape shortcuts
    Shortcut {
        sequence: "Escape"  // Use direct key
        onActivated: {
            if (showDeleteConfirm) {
                showDeleteConfirm = false
            } else if (showHelpDialog) {
                showHelpDialog = false
            } else if (isSearchMode) {
                exitSearchMode()
            } else if (!isGridView) {
                saveCurrentNote()
                showGridView()
            }
        }
    }
    
    // Save shortcut
    Shortcut {
        sequence: notesManager.config.shortcuts.save
        enabled: !isGridView
        onActivated: saveCurrentNote()
    }
    
    // Navigation helper shortcuts
    Shortcut {
        sequence: notesManager.config.shortcuts.firstNote
        enabled: isGridView && !showDeleteConfirm && !isSearchMode
        onActivated: selectedNoteIndex = 0
    }
    
    Shortcut {
        sequence: notesManager.config.shortcuts.lastNote
        enabled: isGridView && !showDeleteConfirm && !isSearchMode
        onActivated: selectedNoteIndex = Math.max(0, filteredNotes.length - 1)
    }

    // Navigation functions with throttling
    function navigateGrid(direction) {
        if (filteredNotes.length === 0 || navigating) return
        
        navigating = true
        navigationTimer.restart()
        
        var cols = Math.floor((window.width - 40) / 250)
        
        switch (direction) {
            case "up":
                selectedNoteIndex = Math.max(0, selectedNoteIndex - cols)
                break
            case "down":
                selectedNoteIndex = Math.min(filteredNotes.length - 1, selectedNoteIndex + cols)
                break
            case "left":
                selectedNoteIndex = Math.max(0, selectedNoteIndex - 1)
                break
            case "right":
                selectedNoteIndex = Math.min(filteredNotes.length - 1, selectedNoteIndex + 1)
                break
        }
    }

    // Search functions
    function enterSearchMode() {
        isSearchMode = true
        focusTimer.start()
    }
    
    function exitSearchMode() {
        isSearchMode = false
        searchText = ""
        filteredNotes = notesManager.notes
        selectedNoteIndex = Math.min(selectedNoteIndex, filteredNotes.length - 1)
    }
    
    function performSearch() {
        if (searchText.trim() === "") {
            filteredNotes = notesManager.notes
        } else {
            var terms = searchText.toLowerCase().split(/\s+/)
            filteredNotes = notesManager.searchNotes(terms)
        }
        selectedNoteIndex = 0
    }

    // Core functions - Fixed createNewNote to prevent stacking
    function createNewNote() {
        if (isSearchMode) exitSearchMode()
        
        // If we're already editing a note, save it first and return to grid
        if (!isGridView) {
            saveCurrentNote()
            showGridView()
            // Use a timer to ensure grid view is shown before creating new note
            Qt.callLater(function() {
                currentNoteId = -1
                currentNote = { id: -1, title: "", content: "" }
                showNoteEditor()
            })
        } else {
            currentNoteId = -1
            currentNote = { id: -1, title: "", content: "" }
            showNoteEditor()
        }
    }

    function showGridView() {
        isGridView = true
        showDeleteConfirm = false
        if (isSearchMode) exitSearchMode()
        stackView.pop()
        selectedNoteIndex = Math.min(selectedNoteIndex, Math.max(0, filteredNotes.length - 1))
    }

    function showNoteEditor() {
        isGridView = false
        showDeleteConfirm = false
        if (isSearchMode) exitSearchMode()
        stackView.push(noteEditor)
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
        if (isGridView && selectedNoteIndex >= 0 && selectedNoteIndex < filteredNotes.length) {
            notesManager.deleteNote(filteredNotes[selectedNoteIndex].id)
            // Update filtered notes after deletion
            if (isSearchMode) {
                performSearch()
            } else {
                filteredNotes = notesManager.notes
            }
            selectedNoteIndex = Math.min(selectedNoteIndex, Math.max(0, filteredNotes.length - 1))
        } else if (!isGridView && currentNoteId >= 0) {
            notesManager.deleteNote(currentNoteId)
            showGridView()
        }
        showDeleteConfirm = false
    }

    // Connection to handle notes changes
    Connections {
        target: notesManager
        function onNotesChanged() {
            if (!isSearchMode) {
                filteredNotes = notesManager.notes
            } else {
                performSearch()
            }
        }
    }

    // Main content
    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: gridView

        // Smooth transitions
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

    // Search overlay
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: isSearchMode ? 60 : 0
        color: notesManager.config.accentColor
        visible: isSearchMode
        z: 100
        
        Behavior on height {
            NumberAnimation { duration: 200 }
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            
            Text {
                text: "Search:"
                color: "white"
                font.family: notesManager.config.fontFamily
                font.pixelSize: 14
            }
            
            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: "Type to search notes..."
                text: searchText
                font.family: notesManager.config.fontFamily
                
                onTextChanged: {
                    searchText = text
                    performSearch()
                }
                
                onAccepted: {
                    if (filteredNotes.length > 0) {
                        editNote(filteredNotes[selectedNoteIndex].id)
                    }
                }
                
                background: Rectangle {
                    color: "white"
                    radius: 5
                }
            }
            
            Text {
                text: "Found: " + filteredNotes.length + " | Esc to exit"
                color: "white"
                font.family: notesManager.config.fontFamily
                font.pixelSize: 12
            }
        }
    }

    // Delete confirmation overlay and dialog
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: showDeleteConfirm ? 0.7 : 0
        visible: showDeleteConfirm
        z: 200
        
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: showDeleteConfirm = false
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 400
        height: 150
        color: notesManager.config.cardColor
        radius: 10
        border.color: notesManager.config.accentColor
        border.width: 2
        visible: showDeleteConfirm
        z: 201
        
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

    // Help dialog
    Rectangle {
        anchors.centerIn: parent
        width: 600
        height: 500
        color: notesManager.config.cardColor
        radius: 10
        border.color: notesManager.config.accentColor
        border.width: 2
        visible: showHelpDialog
        z: 202
        
        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15
            
            Text {
                text: "Keyboard Shortcuts"
                font.family: notesManager.config.fontFamily
                font.pixelSize: 20
                font.bold: true
                color: notesManager.config.textColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            ScrollView {
                width: parent.width
                height: parent.height - 80
                
                Column {
                    width: parent.width
                    spacing: 8
                    
                    Text {
                        text: "New Note: " + notesManager.config.shortcuts.newNote
                        font.family: notesManager.config.fontFamily
                        font.pixelSize: 12
                        color: notesManager.config.textColor
                    }
                    
                    Text {
                        text: "Search: " + notesManager.config.shortcuts.search
                        font.family: notesManager.config.fontFamily
                        font.pixelSize: 12
                        color: notesManager.config.textColor
                    }
                    
                    Text {
                        text: "Navigate: Arrow keys or HJKL"
                        font.family: notesManager.config.fontFamily
                        font.pixelSize: 12
                        color: notesManager.config.textColor
                    }
                    
                    Text {
                        text: "Open Note: Enter or Space"
                        font.family: notesManager.config.fontFamily
                        font.pixelSize: 12
                        color: notesManager.config.textColor
                    }
                    
                    Text {
                        text: "Delete: " + notesManager.config.shortcuts.delete
                        font.family: notesManager.config.fontFamily
                        font.pixelSize: 12
                        color: notesManager.config.textColor
                    }
                    
                    Text {
                        text: "Quick Delete: " + notesManager.config.shortcuts.quickDelete
                        font.family: notesManager.config.fontFamily
                        font.pixelSize: 12
                        color: notesManager.config.textColor
                    }
                    
                    Text {
                        text: "Save: " + notesManager.config.shortcuts.save
                        font.family: notesManager.config.fontFamily
                        font.pixelSize: 12
                        color: notesManager.config.textColor
                    }
                    
                    Text {
                        text: "Back/Cancel: " + notesManager.config.shortcuts.back
                        font.family: notesManager.config.fontFamily
                        font.pixelSize: 12
                        color: notesManager.config.textColor
                    }
                    
                    Text {
                        text: "Quit: " + notesManager.config.shortcuts.quit
                        font.family: notesManager.config.fontFamily
                        font.pixelSize: 12
                        color: notesManager.config.textColor
                    }
                    
                    Text {
                        text: "Help: " + notesManager.config.shortcuts.help
                        font.family: notesManager.config.fontFamily
                        font.pixelSize: 12
                        color: notesManager.config.textColor
                    }
                    
                    Text {
                        text: "First Note: " + notesManager.config.shortcuts.firstNote
                        font.family: notesManager.config.fontFamily
                        font.pixelSize: 12
                        color: notesManager.config.textColor
                    }
                    
                    Text {
                        text: "Last Note: " + notesManager.config.shortcuts.lastNote
                        font.family: notesManager.config.fontFamily
                        font.pixelSize: 12
                        color: notesManager.config.textColor
                    }
                }
            }
            
            Button {
                text: "Close"
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: showHelpDialog = false
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

    // Grid View Component
    Component {
        id: gridView
        
        Rectangle {
            color: notesManager.config.backgroundColor
            
            Column {
                anchors.fill: parent
                anchors.topMargin: isSearchMode ? 60 : 0
                
                Behavior on anchors.topMargin {
                    NumberAnimation { duration: 200 }
                }
                
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
                                text: "Note Collection" + (isSearchMode ? " - Search Mode" : "")
                                font.family: notesManager.config.fontFamily
                                font.pixelSize: 24
                                color: notesManager.config.textColor
                            }
                            
                            Text {
                                text: (isSearchMode ? "Type to search • " : "") + 
                                      "Arrow/HJKL to navigate • Enter/Space to open • " + 
                                      notesManager.config.shortcuts.search + " to search • " +
                                      notesManager.config.shortcuts.help + " for help"
                                font.family: notesManager.config.fontFamily
                                font.pixelSize: 11
                                color: Qt.lighter(notesManager.config.textColor, 0.7)
                                opacity: 0.8
                            }
                        }
                        
                        Text {
                            text: "Notes: " + filteredNotes.length
                            font.family: notesManager.config.fontFamily
                            font.pixelSize: 14
                            color: notesManager.config.textColor
                        }
                        
                        Button {
                            text: "New (" + notesManager.config.shortcuts.newNote + ")"
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
                        model: filteredNotes
                        
                        delegate: Rectangle {
                            id: noteCard
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
                            
                            // Add states for hover
                            states: [
                                State {
                                    name: "hovered"
                                    when: mouseArea.containsMouse && index !== selectedNoteIndex
                                    PropertyChanges {
                                        target: noteCard
                                        color: Qt.lighter(notesManager.config.cardColor, 1.1)
                                    }
                                },
                                State {
                                    name: "selected"
                                    when: index === selectedNoteIndex
                                    PropertyChanges {
                                        target: noteCard
                                        color: Qt.lighter(notesManager.config.accentColor, 1.3)
                                    }
                                }
                            ]
                            
                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    selectedNoteIndex = index
                                    editNote(modelData.id)
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

    // Note Editor Component - Updated with focus improvements
    Component {
        id: noteEditor
        
        Rectangle {
            color: notesManager.config.backgroundColor
            
            // Add StackView status handler for focus when transition completes
            StackView.onStatusChanged: {
                if (StackView.status === StackView.Active) {
                    var textArea = contentArea
                    if (textArea) {
                        textArea.forceActiveFocus()
                        textArea.cursorPosition = textArea.length
                    }
                }
            }
            
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
                            text: "← Back (" + notesManager.config.shortcuts.back + ")"
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
                            text: "Auto-saved • " + notesManager.config.shortcuts.save + " to save manually"
                            font.family: notesManager.config.fontFamily
                            font.pixelSize: 12
                            color: Qt.lighter(notesManager.config.textColor, 0.6)
                            Layout.rightMargin: 15
                        }
                        
                        Button {
                            text: "Delete (" + notesManager.config.shortcuts.quickDelete + ")"
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
                            placeholderText: "Start writing your note...\n\nThe first line will become your note's title automatically.\n\nKeyboard shortcuts:\n" +
                                            notesManager.config.shortcuts.save + " - Save\n" +
                                            notesManager.config.shortcuts.back + " - Back to grid\n" +
                                            notesManager.config.shortcuts.quickDelete + " - Delete note\n" +
                                            notesManager.config.shortcuts.help + " - Show all shortcuts"
                            text: currentNote.content || ""
                            font.family: notesManager.config.fontFamily
                            font.pixelSize: notesManager.config.fontSize
                            color: notesManager.config.textColor
                            wrapMode: TextArea.Wrap
                            selectByMouse: true
                            
                            // Force focus immediately when component is created
                            Component.onCompleted: {
                                forceActiveFocus()
                                cursorPosition = length
                            }
                            
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