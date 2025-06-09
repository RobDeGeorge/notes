import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import NotesApp 1.0

ApplicationWindow {
    id: window
    width: 1200
    height: 800
    minimumWidth: 600
    minimumHeight: 400
    visible: true
    title: "Simple Notes - Ultra Keyboard Friendly"
    color: notesManager.config.backgroundColor

    // State management - cleaner than multiple booleans
    QtObject {
        id: appState
        property string view: "grid"  // "grid" or "editor"
        property string modal: "none" // "none", "search", "delete", "help"
        
        function isGridView() { return view === "grid" }
        function isEditing() { return view === "editor" }
        function canNavigate() { return view === "grid" && modal === "none" }
        function hasModal() { return modal !== "none" }
    }

    property int currentNoteId: -1
    property var currentNote: ({})
    property int selectedNoteIndex: 0
    property int unsavedChanges: 0
    property bool navigating: false

    // Timer management centralized
    QtObject {
        id: timerManager
        
        property Timer autoSaveTimer: Timer {
            id: autoSaveTimer
            interval: notesManager.config.autoSaveInterval
            repeat: false
            onTriggered: {
                if (appState.isEditing() && currentNote.content !== undefined) {
                    saveCurrentNote()
                    unsavedChanges = 0
                }
            }
        }
        
        property Timer focusTimer: Timer {
            id: focusTimer
            interval: 10
            repeat: false
            property var targetItem: null
            onTriggered: {
                if (targetItem) {
                    targetItem.forceActiveFocus()
                    if (targetItem.hasOwnProperty('cursorPosition')) {
                        targetItem.cursorPosition = targetItem.length
                    }
                    targetItem = null
                }
            }
        }
        
        property Timer navigationTimer: Timer {
            id: navigationTimer
            interval: 50
            repeat: false
            onTriggered: navigating = false
        }
        
        property Timer searchDebounceTimer: Timer {
            id: searchDebounceTimer
            interval: notesManager.config.searchDebounceInterval
            repeat: false
            onTriggered: notesManager.updateFilteredNotes()
        }
        
        function scheduleFocus(item) {
            focusTimer.targetItem = item
            focusTimer.restart()
        }
    }

    // Error/Success notifications
    Connections {
        target: notesManager
        function onSaveError(message) {
            notification.show(message, "error")
        }
        function onLoadError(message) {
            notification.show(message, "error")
        }
        function onSaveSuccess() {
            // Silent success - only show errors
        }
    }

    // Notification system
    Rectangle {
        id: notification
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: appState.modal === "search" ? 70 : 10
        width: Math.min(parent.width * 0.8, 600)
        height: 50
        radius: 5
        visible: false
        z: 300
        
        property string type: "info"
        color: {
            switch(type) {
                case "error": return notesManager.config.deleteButtonColor
                case "success": return notesManager.config.successColor
                case "warning": return notesManager.config.warningColor
                default: return notesManager.config.accentColor
            }
        }
        
        Text {
            anchors.centerIn: parent
            id: notificationText
            color: "white"
            font.family: notesManager.config.fontFamily
            font.pixelSize: 14
        }
        
        Timer {
            id: notificationTimer
            interval: 3000
            onTriggered: notification.visible = false
        }
        
        function show(message, msgType = "info") {
            notificationText.text = message
            type = msgType
            visible = true
            notificationTimer.restart()
        }
        
        Behavior on visible {
            NumberAnimation { duration: 200 }
        }
    }

    // Keyboard shortcuts
    Shortcut {
        sequence: notesManager.config.shortcuts.newNote
        enabled: appState.canNavigate()
        onActivated: createNewNote()
    }
    
    Shortcut {
        sequence: notesManager.config.shortcuts.search
        enabled: appState.isGridView() && appState.modal !== "delete"
        onActivated: {
            appState.modal = "search"
            timerManager.scheduleFocus(searchField)
        }
    }
    
    Shortcut {
        sequence: notesManager.config.shortcuts.help
        onActivated: appState.modal = appState.modal === "help" ? "none" : "help"
    }
    
    Shortcut {
        sequence: notesManager.config.shortcuts.quit
        onActivated: {
            if (appState.isEditing()) saveCurrentNote()
            Qt.quit()
        }
    }
    
    // Navigation shortcuts with throttling
    Shortcut {
        sequences: ["Up", "K"]
        enabled: appState.canNavigate() && !navigating
        onActivated: navigateGrid("up")
    }
    
    Shortcut {
        sequences: ["Down", "J"]
        enabled: appState.canNavigate() && !navigating
        onActivated: navigateGrid("down")
    }
    
    Shortcut {
        sequences: ["Left", "H"]
        enabled: appState.canNavigate() && !navigating
        onActivated: navigateGrid("left")
    }
    
    Shortcut {
        sequences: ["Right", "L"]
        enabled: appState.canNavigate() && !navigating
        onActivated: navigateGrid("right")
    }
    
    // Open note shortcuts
    Shortcut {
        sequences: ["Return", "Space"]
        enabled: appState.canNavigate() && notesManager.filteredNotes.length > 0
        onActivated: {
            if (selectedNoteIndex >= 0 && selectedNoteIndex < notesManager.filteredNotes.length) {
                editNote(notesManager.filteredNotes[selectedNoteIndex].id)
            }
        }
    }
    
    // Delete shortcuts
    Shortcut {
        sequence: "Delete"
        enabled: appState.canNavigate() && notesManager.filteredNotes.length > 0
        onActivated: appState.modal = "delete"
    }
    
    Shortcut {
        sequence: "Ctrl+D"
        enabled: appState.isEditing() && currentNoteId >= 0 && !appState.hasModal()
        onActivated: {
            appState.modal = "delete"
            window.forceActiveFocus()
        }
    }
    
    // Delete confirmation shortcuts
    Shortcut {
        sequences: ["Y", "Return"]
        enabled: appState.modal === "delete"
        onActivated: confirmDelete()
    }
    
    Shortcut {
        sequences: ["N", "Escape"]
        enabled: appState.modal === "delete"
        onActivated: {
            appState.modal = "none"
            if (appState.isEditing()) {
                timerManager.scheduleFocus(contentArea)
            }
        }
    }
    
    // Escape handler
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (appState.modal === "delete") {
                appState.modal = "none"
                if (appState.isEditing()) {
                    timerManager.scheduleFocus(contentArea)
                }
            } else if (appState.modal === "help") {
                appState.modal = "none"
            } else if (appState.modal === "search") {
                exitSearchMode()
            } else if (appState.isEditing()) {
                saveCurrentNote()
                showGridView()
            }
        }
    }
    
    // Save shortcut
    Shortcut {
        sequence: notesManager.config.shortcuts.save
        enabled: appState.isEditing() && !appState.hasModal()
        onActivated: saveCurrentNote()
    }
    
    // Navigation helper shortcuts
    Shortcut {
        sequence: notesManager.config.shortcuts.firstNote
        enabled: appState.canNavigate()
        onActivated: selectedNoteIndex = 0
    }
    
    Shortcut {
        sequence: notesManager.config.shortcuts.lastNote
        enabled: appState.canNavigate()
        onActivated: selectedNoteIndex = Math.max(0, notesManager.filteredNotes.length - 1)
    }

    // Font size control shortcuts
    Shortcut {
        sequence: notesManager.config.shortcuts.increaseFontSize
        onActivated: notesManager.increaseFontSize()
    }

    Shortcut {
        sequence: notesManager.config.shortcuts.decreaseFontSize
        onActivated: notesManager.decreaseFontSize()
    }

    Shortcut {
        sequence: notesManager.config.shortcuts.increaseCardFontSize
        onActivated: notesManager.increaseCardFontSize()
    }

    Shortcut {
        sequence: notesManager.config.shortcuts.decreaseCardFontSize
        onActivated: notesManager.decreaseCardFontSize()
    }

    // Card dimension control shortcuts
    Shortcut {
        sequence: notesManager.config.shortcuts.increaseCardWidth
        onActivated: notesManager.increaseCardWidth()
    }

    Shortcut {
        sequence: notesManager.config.shortcuts.decreaseCardWidth
        onActivated: notesManager.decreaseCardWidth()
    }

    Shortcut {
        sequence: notesManager.config.shortcuts.increaseCardHeight
        onActivated: notesManager.increaseCardHeight()
    }

    Shortcut {
        sequence: notesManager.config.shortcuts.decreaseCardHeight
        onActivated: notesManager.decreaseCardHeight()
    }

    function navigateGrid(direction) {
        if (notesManager.filteredNotes.length === 0 || navigating) return
    
        navigating = true
        navigationTimer.restart()
    
        // Simple calculation based on fixed margins and card spacing
        var cols = Math.floor((window.width - 40) / (notesManager.config.cardWidth + 20))
    
        var oldIndex = selectedNoteIndex
    
        switch (direction) {
            case "up":
                selectedNoteIndex = Math.max(0, selectedNoteIndex - cols)
                break
            case "down":
                selectedNoteIndex = Math.min(notesManager.filteredNotes.length - 1, selectedNoteIndex + cols)
                break
            case "left":
                selectedNoteIndex = Math.max(0, selectedNoteIndex - 1)
                break
            case "right":
                selectedNoteIndex = Math.min(notesManager.filteredNotes.length - 1, selectedNoteIndex + 1)
                break
        }
    }

    // Search functions
    function exitSearchMode() {
        appState.modal = "none"
        notesManager.setSearchText("")
        if (searchField) {
            searchField.text = ""
            searchField.focus = false
        }
        selectedNoteIndex = Math.min(selectedNoteIndex, Math.max(0, notesManager.filteredNotes.length - 1))
        window.forceActiveFocus()
    }

    // Core functions
    function createNewNote() {
        if (appState.modal === "search") exitSearchMode()
        
        if (appState.isEditing()) {
            saveCurrentNote()
            showGridView()
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
        appState.view = "grid"
        appState.modal = "none"
        stackView.pop()
        selectedNoteIndex = Math.min(selectedNoteIndex, Math.max(0, notesManager.filteredNotes.length - 1))
    }

    function showNoteEditor() {
        appState.view = "editor"
        appState.modal = "none"
        unsavedChanges = 0
        stackView.push(noteEditor)
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
            unsavedChanges = 0
        }
    }

    function confirmDelete() {
        if (appState.isGridView() && selectedNoteIndex >= 0 && selectedNoteIndex < notesManager.filteredNotes.length) {
            var noteToDelete = notesManager.filteredNotes[selectedNoteIndex]
            if (noteToDelete && noteToDelete.id !== undefined) {
                notesManager.deleteNote(noteToDelete.id)
                selectedNoteIndex = Math.min(selectedNoteIndex, Math.max(0, notesManager.filteredNotes.length - 1))
            }
        } else if (appState.isEditing() && currentNoteId >= 0) {
            notesManager.deleteNote(currentNoteId)
            showGridView()
        }
        appState.modal = "none"
    }
    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: gridView

        pushEnter: Transition {
            ParallelAnimation {
                PropertyAnimation {
                    property: "scale"
                    from: 0.8
                    to: 1.0
                    duration: 250
                    easing.type: Easing.OutCubic
                }
                PropertyAnimation {
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }
        }

        pushExit: Transition {
            PropertyAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 150
                easing.type: Easing.InQuad
            }
        }

        popEnter: Transition {
            PropertyAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 200
                easing.type: Easing.OutQuad
            }
        }

        popExit: Transition {
            ParallelAnimation {
                PropertyAnimation {
                    property: "scale"
                    from: 1.0
                    to: 0.8
                    duration: 250
                    easing.type: Easing.InCubic
                }
                PropertyAnimation {
                    property: "opacity"
                    from: 1.0
                    to: 0.0
                    duration: 200
                    easing.type: Easing.InQuad
                }
            }
        }
    }

    // Search overlay
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: appState.modal === "search" ? 60 : 0
        color: notesManager.config.accentColor
        visible: appState.modal === "search"
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
                text: notesManager.searchText
                font.family: notesManager.config.fontFamily
                font.pixelSize: 14
                color: notesManager.config.searchBarTextColor
                placeholderTextColor: notesManager.config.placeholderColor
                
                onTextChanged: {
                    notesManager.setSearchText(text)
                    searchDebounceTimer.restart()
                }
                
                onAccepted: {
                    if (notesManager.filteredNotes.length > 0 && selectedNoteIndex >= 0) {
                        editNote(notesManager.filteredNotes[selectedNoteIndex].id)
                    }
                }
                
                Keys.onEscapePressed: (event)=> {
                    event.accepted = true
                    exitSearchMode()
                }
                
                Keys.onPressed: (event)=> {
                    if (event.key === Qt.Key_Up || event.key === Qt.Key_Down ||
                        event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                        event.accepted = true
                        var direction = {
                            [Qt.Key_Up]: "up",
                            [Qt.Key_Down]: "down",
                            [Qt.Key_Left]: "left",
                            [Qt.Key_Right]: "right"
                        }[event.key]
                        navigateGrid(direction)
                    } else if (event.key === Qt.Key_Return) {
                        if (notesManager.filteredNotes.length > 0 && selectedNoteIndex >= 0) {
                            event.accepted = true
                            editNote(notesManager.filteredNotes[selectedNoteIndex].id)
                        }
                    } else if (event.key === Qt.Key_Home) {
                        event.accepted = true
                        selectedNoteIndex = 0
                    } else if (event.key === Qt.Key_End) {
                        event.accepted = true
                        selectedNoteIndex = Math.max(0, notesManager.filteredNotes.length - 1)
                    }
                }
                
                background: Rectangle {
                    color: notesManager.config.searchBarColor
                    radius: 5
                }
            }
            
            Text {
                text: "Found: " + notesManager.filteredNotes.length + " | Esc to exit"
                color: "white"
                font.family: notesManager.config.fontFamily
                font.pixelSize: 12
            }
        }
    }

    // Delete confirmation overlay
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: appState.modal === "delete" ? 0.7 : 0
        visible: appState.modal === "delete"
        z: 200
        
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                appState.modal = "none"
                if (appState.isEditing()) {
                    timerManager.scheduleFocus(contentArea)
                }
            }
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
        visible: appState.modal === "delete"
        z: 201
        focus: appState.modal === "delete"
        
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
                color: notesManager.config.secondaryTextColor
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
                        color: notesManager.config.deleteButtonColor
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
                    onClicked: {
                        appState.modal = "none"
                        if (appState.isEditing()) {
                            timerManager.scheduleFocus(contentArea)
                        }
                    }
                    
                    background: Rectangle {
                        color: "transparent"
                        border.color: notesManager.config.borderColor
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
        width: window.width * 0.8
        height: window.height * 0.8
        color: notesManager.config.cardColor
        radius: Math.max(5, width * 0.015)
        border.color: notesManager.config.accentColor
        border.width: Math.max(1, width * 0.003)
        visible: appState.modal === "help"
        z: 202
        
        Column {
            anchors.fill: parent
            anchors.margins: parent.width * 0.04
            spacing: parent.height * 0.02
            
            Text {
                text: "Keyboard Shortcuts"
                font.family: notesManager.config.fontFamily
                font.pixelSize: 28
                font.bold: true
                color: notesManager.config.textColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Grid {
                width: parent.width
                height: parent.height * 0.75
                columns: 1
                spacing: 5
                
                HelpItem { 
                    label: "New Note" 
                    shortcut: notesManager.config.shortcuts.newNote 
                    width: parent.width
                    itemHeight: 30 
                    fontSize: 12   
                }
                HelpItem { 
                    label: "Search" 
                    shortcut: notesManager.config.shortcuts.search 
                    width: parent.width
                    itemHeight: parent.height * 0.055
                    fontSize: parent.height * 0.035
                }
                HelpItem { 
                    label: "Navigate" 
                    shortcut: "Arrow keys or HJKL" 
                    width: parent.width
                    itemHeight: parent.height * 0.055
                    fontSize: parent.height * 0.035
                }
                HelpItem { 
                    label: "Open Note" 
                    shortcut: "Enter or Space" 
                    width: parent.width
                    itemHeight: parent.height * 0.055
                    fontSize: parent.height * 0.035
                }
                HelpItem { 
                    label: "Delete (Grid)" 
                    shortcut: notesManager.config.shortcuts.delete 
                    width: parent.width
                    itemHeight: parent.height * 0.055
                    fontSize: parent.height * 0.035
                }
                HelpItem { 
                    label: "Quick Delete (Editor)" 
                    shortcut: notesManager.config.shortcuts.quickDelete 
                    width: parent.width
                    itemHeight: parent.height * 0.055
                    fontSize: parent.height * 0.035
                }
                HelpItem { 
                    label: "Save" 
                    shortcut: notesManager.config.shortcuts.save 
                    width: parent.width
                    itemHeight: parent.height * 0.055
                    fontSize: parent.height * 0.035
                }
                HelpItem { 
                    label: "Back/Cancel" 
                    shortcut: notesManager.config.shortcuts.back 
                    width: parent.width
                    itemHeight: parent.height * 0.055
                    fontSize: parent.height * 0.035
                }
                HelpItem { 
                    label: "Quit" 
                    shortcut: notesManager.config.shortcuts.quit 
                    width: parent.width
                    itemHeight: parent.height * 0.055
                    fontSize: parent.height * 0.035
                }
                HelpItem { 
                    label: "Help" 
                    shortcut: notesManager.config.shortcuts.help 
                    width: parent.width
                    itemHeight: parent.height * 0.055
                    fontSize: parent.height * 0.035
                }
                HelpItem { 
                    label: "First Note" 
                    shortcut: notesManager.config.shortcuts.firstNote 
                    width: parent.width
                    itemHeight: parent.height * 0.055
                    fontSize: parent.height * 0.035
                }
                HelpItem { 
                    label: "Last Note" 
                    shortcut: notesManager.config.shortcuts.lastNote 
                    width: parent.width
                    itemHeight: parent.height * 0.055
                    fontSize: parent.height * 0.035
                }
                HelpItem { 
                    label: "Increase Font Size" 
                    shortcut: notesManager.config.shortcuts.increaseFontSize 
                    width: parent.width
                    itemHeight: parent.height * 0.055
                    fontSize: parent.height * 0.035
                }
                HelpItem { 
                    label: "Decrease Font Size" 
                    shortcut: notesManager.config.shortcuts.decreaseFontSize 
                    width: parent.width
                    itemHeight: parent.height * 0.055
                    fontSize: parent.height * 0.035
                }
            }

            Button {
                text: "Close"
                width: parent.width * 0.2
                height: parent.height * 0.08
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: appState.modal = "none"
                
                background: Rectangle {
                    color: notesManager.config.accentColor
                    radius: parent.height * 0.2
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.family: notesManager.config.fontFamily
                    font.pixelSize: parent.height * 0.35
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
                anchors.topMargin: appState.modal === "search" ? 60 : 0
                
                Behavior on anchors.topMargin {
                    NumberAnimation { duration: 200 }
                }
                
                // Header section
                Rectangle {
                    width: parent.width
                    height: 80
                    color: notesManager.config.cardColor
                    z: 2
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        
                        Column {
                            Layout.fillWidth: true
                            
                            Text {
                                text: "Note Collection" + (appState.modal === "search" ? " - Search Mode" : "")
                                font.family: notesManager.config.fontFamily
                                font.pixelSize: 24
                                color: notesManager.config.textColor
                            }
                        }                   
                        Button {
                            text: "New (" + notesManager.config.shortcuts.newNote + ")"
                            enabled: !appState.hasModal()
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
                
                // Notes grid sectioncontent
                // Notes grid section
                ScrollView {
                    width: parent.width
                    height: parent.height - 80
                    ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    GridView {
                        id: notesGrid
                        focus: true
                        anchors.fill: parent

                        // Simple left-aligned layout with consistent margins
                        leftMargin: 20
                        rightMargin: 20
                        topMargin: 20
                        bottomMargin: 20

                        cellWidth: notesManager.config.cardWidth + 20
                        cellHeight: notesManager.config.cardHeight + 20
                        model: notesManager.filteredNotes

                        // Enable built-in auto-scrolling
                        currentIndex: selectedNoteIndex
                        highlightFollowsCurrentItem: true
                        keyNavigationEnabled: false

                        // Optimize highlight positioning
                        preferredHighlightBegin: height * 0.2
                        preferredHighlightEnd: height * 0.8
                        highlightRangeMode: GridView.ApplyRange

                        // Performance optimizations
                        cacheBuffer: Math.max(0, height * 2)
                        displayMarginBeginning: 100
                        displayMarginEnd: 100

                        // React to selectedNoteIndex changes from window
                        Connections {
                            target: window
                            function onSelectedNoteIndexChanged() {
                                notesGrid.currentIndex = selectedNoteIndex
                            }
                        }

                        delegate: Rectangle {
                            id: noteCard
                            width: notesManager.config.cardWidth
                            height: notesManager.config.cardHeight
                            color: index === selectedNoteIndex ? 
                                    notesManager.config.selectedCardColor : 
                                    notesManager.config.cardColor
                            radius: 8
                            border.color: index === selectedNoteIndex ? 
                                            notesManager.config.accentColor : 
                                            notesManager.config.borderColor
                            border.width: index === selectedNoteIndex ? 3 : 1

                            states: [
                                State {
                                    name: "hovered"
                                    when: mouseArea.containsMouse && index !== selectedNoteIndex
                                    PropertyChanges {
                                        target: noteCard
                                        color: notesManager.config.hoverColor
                                    }
                                },
                                State {
                                    name: "selected"
                                    when: index === selectedNoteIndex
                                    PropertyChanges {
                                        target: noteCard
                                        color: notesManager.config.selectedCardColor
                                        border.color: notesManager.config.accentColor
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

                            Item {
                                anchors.fill: parent
                                anchors.margins: 10
                                Text {
                                    id: titleText
                                    text: modelData.title
                                    font.family: notesManager.config.fontFamily
                                    font.pixelSize: notesManager.config.cardTitleFontSize
                                    font.bold: true
                                    color: index === selectedNoteIndex ? "white" : notesManager.config.textColor
                                    width: parent.width
                                    height: 20
                                    elide: Text.ElideRight
                                    anchors.top: parent.top
                                    wrapMode: Text.NoWrap
                                }

                                Text {
                                    id: contentText
                                    text: {
                                        const idx = modelData.content.indexOf("\n");
                                        return idx === -1 ? "" : modelData.content.slice(idx + 1);
                                    }
                                    font.family: notesManager.config.fontFamily
                                    font.pixelSize: notesManager.config.cardFontSize
                                    color: index === selectedNoteIndex ? 
                                            Qt.lighter("white", 0.5) : 
                                            notesManager.config.secondaryTextColor
                                    width: parent.width
                                    anchors.top: titleText.bottom
                                    anchors.topMargin: 5
                                    anchors.bottom: timestampText.top
                                    anchors.bottomMargin: 5
                                    wrapMode: Text.WordWrap
                                    clip: true
                                }

                                Text {
                                    id: timestampText
                                    text: {
                                        if (modelData.modified) {
                                            var date = new Date(modelData.modified)
                                            var now = new Date()
                                            var diff = now - date
                                            var days = Math.floor(diff / (1000 * 60 * 60 * 24))

                                            if (days === 0) return "Today"
                                            else if (days === 1) return "Yesterday"
                                            else if (days < 7) return days + " days ago"
                                            else return date.toLocaleDateString()
                                        }
                                        return ""
                                    }
                                    font.family: notesManager.config.fontFamily
                                    font.pixelSize: Math.max(8, notesManager.config.cardFontSize - 2)
                                    color: notesManager.config.secondaryTextColor
                                    opacity: 0.5
                                    width: parent.width
                                    height: 12
                                    anchors.bottom: parent.bottom
                                    elide: Text.ElideRight
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
            
            StackView.onStatusChanged: {
                if (StackView.status === StackView.Active && !appState.hasModal()) {
                    timerManager.scheduleFocus(contentArea)
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
                                border.color: notesManager.config.borderColor
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
                            color: notesManager.config.secondaryTextColor
                            Layout.rightMargin: 15
                        }
                        
                        Button {
                            text: "Delete (" + notesManager.config.shortcuts.quickDelete + ")"
                            visible: currentNoteId >= 0
                            onClicked: {
                                appState.modal = "delete"
                                window.forceActiveFocus()
                            }
                            
                            background: Rectangle {
                                color: notesManager.config.deleteButtonColor
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
                            placeholderTextColor: notesManager.config.placeholderColor
                            text: currentNote.content || ""
                            font.family: notesManager.config.fontFamily
                            font.pixelSize: notesManager.config.fontSize
                            color: notesManager.config.textColor
                            wrapMode: TextArea.Wrap
                            selectByMouse: true
                            
                            Component.onCompleted: {
                                if (!appState.hasModal()) {
                                    forceActiveFocus()
                                    cursorPosition = length
                                }
                            }
                            
                            onTextChanged: {
                                currentNote.content = text
                                unsavedChanges++
                                
                                // Update title in real-time
                                if (text.trim()) {
                                    var firstLine = text.split('\n')[0].trim()
                                    // Remove any markdown headers
                                    firstLine = firstLine.replace(/^#+\s*/, '')
                                    if (firstLine.length > 50) {
                                        firstLine = firstLine.substring(0, 47) + "..."
                                    }
                                    currentNote.title = firstLine || "Untitled Note"
                                } else {
                                    currentNote.title = "New Note"
                                }
                                
                                // Trigger update for the title display
                                currentNote = currentNote  // This forces a property change notification
                                
                                // Force save if too many unsaved changes (silently)
                                if (unsavedChanges >= notesManager.config.maxUnsavedChanges) {
                                    saveCurrentNote()
                                } else {
                                    // Normal auto-save timer
                                    autoSaveTimer.restart()
                                }
                            }
                            
                            Keys.onPressed: (event)=> {
                                if (event.key === Qt.Key_D && (event.modifiers & Qt.ControlModifier)) {
                                    event.accepted = true
                                    appState.modal = "delete"
                                    window.forceActiveFocus()
                                }
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