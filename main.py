import sys
import json
import os
import re
from pathlib import Path
from datetime import datetime
from PySide6.QtGui import QGuiApplication, QFont
from PySide6.QtQml import QmlElement, qmlRegisterType
from PySide6.QtCore import QObject, Signal, Slot, Property, QUrl, QTimer, Qt
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication  # Need this for widget attributes

QML_IMPORT_NAME = "NotesApp"
QML_IMPORT_MAJOR_VERSION = 1

@QmlElement
class NotesManager(QObject):
    notesChanged = Signal()
    configChanged = Signal()
    filteredNotesChanged = Signal()
    saveError = Signal(str)
    loadError = Signal(str)
    saveSuccess = Signal()
    
    def __init__(self):
        super().__init__()
        self.notes_file = "notes.json"
        self.config_file = "config.json"
        self._notes = []
        self._config = {}
        self._next_id = 0
        self._search_text = ""
        self._filtered_notes = []
        
        # Performance optimization: pre-compiled regex for search
        self._search_regex = None
        
        self.load_config()
        self.load_notes()

    def load_config(self):
        default_config = {
            "backgroundColor": "#2b2b2b",
            "cardColor": "#3c3c3c",
            "textColor": "#ffffff",
            "accentColor": "#4a9eff",
            "secondaryTextColor": "#b0b0b0",
            "hoverColor": "#4c4c4c",
            "selectedCardColor": "#5c5c5c",
            "borderColor": "#505050",
            "placeholderColor": "#808080",
            "deleteButtonColor": "#e74c3c",
            "successColor": "#27ae60",
            "warningColor": "#f39c12",
            "searchBarColor": "#ffffff",
            "searchBarTextColor": "#2b2b2b",
            "fontFamily": "Arial",
            "fontSize": 14,
            "cardFontSize": 12,
            "cardTitleFontSize": 14,
            "headerFontSize": 24,
            "cardWidth": 250,        # Add this
            "cardHeight": 200,       # Add this
            "windowWidth": 1280,
            "windowHeight": 800,           
            "maxUnsavedChanges": 50,
            "autoSaveInterval": 1000,
            "searchDebounceInterval": 300,
            "shortcuts": {
            "newNote": "Ctrl+N",
            "save": "Ctrl+S",
            "back": "Escape",
            "delete": "Delete",
            "confirmDelete": ["Y", "Return"],
            "cancelDelete": ["N", "Escape"],
            "quickDelete": "Ctrl+D",
            "search": "Ctrl+F",
            "searchNext": "F3",
            "searchPrev": "Shift+F3",
            "toggleView": "Tab",
            "nextNote": ["Down", "J"],
            "prevNote": ["Up", "K"],
            "nextNoteHorizontal": ["Right", "L"],
            "prevNoteHorizontal": ["Left", "H"],
            "openNote": ["Return", "Space"],
            "firstNote": "Home",
            "lastNote": "End",
            "pageUp": "Page_Up",
            "pageDown": "Page_Down",
            "selectAll": "Ctrl+A",
            "copy": "Ctrl+C",
            "cut": "Ctrl+X",
            "paste": "Ctrl+V",
            "undo": "Ctrl+Z",
            "redo": "Ctrl+Y",
            "find": "Ctrl+F",
            "quit": "Ctrl+Q",
            "help": "F1",
            "increaseFontSize": "Ctrl++",    # Add this
            "decreaseFontSize": "Ctrl+-"     # Add this
            }
        }

        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    loaded_config = json.load(f)
                    # Deep merge to preserve new defaults
                    for key, value in default_config.items():
                        if key not in loaded_config:
                            loaded_config[key] = value
                        elif key == "shortcuts" and isinstance(value, dict):
                            loaded_config[key] = {**value, **loaded_config[key]}
                    
                    # Validate configuration
                    self._config = self.validate_config(loaded_config, default_config)
            else:
                self._config = default_config
                self.save_config()
        except json.JSONDecodeError:
            self.loadError.emit("Configuration file is corrupted. Using defaults.")
            self._config = default_config
            self._backup_file(self.config_file)
        except Exception as e:
            self.loadError.emit(f"Error loading config: {str(e)}")
            self._config = default_config

    def validate_config(self, config, defaults):
        """Validate and sanitize configuration values"""
        validated = config.copy()

        # Validate font sizes
        size_keys = ['fontSize', 'cardTitleFontSize', 'headerFontSize', 'cardFontSize']
        for key in size_keys:
            if key in validated:
                try:
                    size = int(validated[key])
                    validated[key] = max(8, min(72, size))
                except (ValueError, TypeError):
                    validated[key] = defaults[key]

        # Validate card dimensions
        card_keys = ['cardWidth', 'cardHeight']
        for key in card_keys:
            if key in validated:
                try:
                    size = int(validated[key])
                    if key == 'cardWidth':
                        validated[key] = max(150, min(500, size))
                    else:  # cardHeight
                        validated[key] = max(120, min(400, size))
                except (ValueError, TypeError):
                    validated[key] = defaults[key]

        # Validate colors
        color_pattern = re.compile(r'^#[0-9A-Fa-f]{6}$')
        for key, value in validated.items():
            if 'Color' in key and not color_pattern.match(str(value)):
                validated[key] = defaults.get(key, "#ffffff")

        # Validate numeric values
        numeric_keys = ['maxUnsavedChanges', 'autoSaveInterval', 'searchDebounceInterval', 'windowWidth', 'windowHeight']
        for key in numeric_keys:
            if key in validated:
                try:
                    val = int(validated[key])
                    validated[key] = max(50, val) if key == 'maxUnsavedChanges' else max(100, val)
                except (ValueError, TypeError):
                    validated[key] = defaults.get(key, 1000)

        return validated    
    
    def save_config(self):
        try:
            # Write to temporary file first for atomic operation
            temp_file = self.config_file + '.tmp'
            with open(temp_file, 'w', encoding='utf-8') as f:
                json.dump(self._config, f, indent=2, ensure_ascii=False)
            
            # Atomic rename
            os.replace(temp_file, self.config_file)
            return True
        except Exception as e:
            error_msg = f"Error saving config: {str(e)}"
            print(error_msg)
            self.saveError.emit(error_msg)
            return False
    
    def load_notes(self):
        try:
            if os.path.exists(self.notes_file):
                with open(self.notes_file, 'r', encoding='utf-8') as f:
                    data = f.read()
                    if not data.strip():
                        self._notes = []
                        self._filtered_notes = []
                        return
                    
                    self._notes = json.loads(data)
                    
                    # Validate note structure and find highest ID
                    max_id = -1
                    for note in self._notes:
                        if not all(key in note for key in ['id', 'title', 'content']):
                            raise ValueError("Invalid note structure")
                        max_id = max(max_id, note['id'])
                    
                    self._next_id = max_id + 1
                    
                    # Add timestamps to old notes if missing
                    for note in self._notes:
                        if 'created' not in note:
                            note['created'] = datetime.now().isoformat()
                        if 'modified' not in note:
                            note['modified'] = note['created']
                    
                    self._filtered_notes = self._notes.copy()
            else:
                self._notes = []
                self._filtered_notes = []
                
        except json.JSONDecodeError:
            self.loadError.emit("Notes file is corrupted. Creating backup...")
            self._backup_file(self.notes_file)
            self._notes = []
            self._filtered_notes = []
        except PermissionError:
            self.loadError.emit("Cannot access notes file. Check file permissions.")
            self._notes = []
            self._filtered_notes = []
        except ValueError as e:
            self.loadError.emit(str(e))
            self._backup_file(self.notes_file)
            self._notes = []
            self._filtered_notes = []
        except Exception as e:
            self.loadError.emit(f"Unexpected error loading notes: {str(e)}")
            self._notes = []
            self._filtered_notes = []
        finally:
            self.notesChanged.emit()
            self.filteredNotesChanged.emit()
    
    def _backup_file(self, filepath):
        """Create a backup of the file with timestamp"""
        try:
            if os.path.exists(filepath):
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                backup_path = f"{filepath}.backup_{timestamp}"
                os.rename(filepath, backup_path)
                print(f"Backup created: {backup_path}")
        except Exception as e:
            print(f"Failed to create backup: {e}")
    
    def save_notes(self):
        """
        Write the notes file **in the same order they are held in memory**
        (no re-sorting).  Uses a temp-file + atomic rename so a crash/power-loss
        can’t corrupt the main JSON.
        """
        try:
            tmp_path = f"{self.notes_file}.tmp"
            with open(tmp_path, "w", encoding="utf-8") as f:
                json.dump(self._notes, f, indent=2, ensure_ascii=False)

            os.replace(tmp_path, self.notes_file)   # atomic on POSIX & Windows
            self.saveSuccess.emit()
            return True

        except PermissionError:
            msg = "Cannot save notes – file is locked or you lack permission."
            print(msg)
            self.saveError.emit(msg)
            return False

        except Exception as e:
            msg = f"Error saving notes: {e}"
            print(msg)
            self.saveError.emit(msg)
            return False
        
    def generate_title(self, content):
        """Generate a title from the first line of content"""
        if not content.strip():
            return "Untitled Note"
        
        # Get first line, remove extra whitespace
        first_line = content.split('\n')[0].strip()
        
        # Remove any markdown headers
        first_line = re.sub(r'^#+\s*', '', first_line)
        
        # Limit to reasonable title length
        if len(first_line) > 50:
            first_line = first_line[:47] + "..."
        
        return first_line if first_line else "Untitled Note"
    
    @Property(list, notify=notesChanged)
    def notes(self):
        return self._notes
    
    @Property(list, notify=filteredNotesChanged)
    def filteredNotes(self):
        return self._filtered_notes
    
    @Property('QVariant', notify=configChanged)
    def config(self):
        return self._config
    
    @Property(str, notify=filteredNotesChanged)
    def searchText(self):
        return self._search_text
    
    @searchText.setter
    def searchText(self, value):
        if self._search_text != value:
            self._search_text = value
            self.updateFilteredNotes()
    
    @Slot(str)
    def setSearchText(self, text):
        self.searchText = text
    
    @Slot()
    def updateFilteredNotes(self):
        """Update filtered notes based on search text"""
        if not self._search_text.strip():
            self._filtered_notes = self._notes.copy()
            self._search_regex = None
        else:
            # Build regex for efficient searching
            search_terms = self._search_text.lower().split()
            escaped_terms = [re.escape(term) for term in search_terms]
            pattern = '.*'.join(escaped_terms)  # All terms must appear in order
            
            try:
                self._search_regex = re.compile(pattern, re.IGNORECASE)
                self._filtered_notes = []
                
                for note in self._notes:
                    combined_text = f"{note['title']} {note['content']}"
                    if self._search_regex.search(combined_text):
                        self._filtered_notes.append(note)
                        
            except re.error:
                # Invalid regex, fall back to simple search
                self._filtered_notes = self._notes.copy()
                
        self.filteredNotesChanged.emit()
    
    @Slot(str, result=int)
    def createNote(self, content):
        note_id = self._next_id
        self._next_id += 1
        
        now = datetime.now().isoformat()
        title = self.generate_title(content)
        
        new_note = {
            "id": note_id,
            "title": title,
            "content": content,
            "created": now,
            "modified": now
        }
        
        self._notes.insert(0, new_note)  # Add to beginning for most recent first
        self.save_notes()
        self.notesChanged.emit()
        self.updateFilteredNotes()
        return note_id
    
    @Slot(int, str)
    def updateNote(self, note_id, content):
        """
        Replace the body of an existing note **without** changing its position
        in the list.  If the text hasn’t really changed, we leave the note
        completely untouched so its modified timestamp (and any autosave) are
        not needlessly updated.
        """
        for note in self._notes:
            if note["id"] == note_id:
                if note["content"] != content:
                    note["content"] = content
                    note["title"] = self.generate_title(content)
                    note["modified"] = datetime.now().isoformat()
                break

        # persist + refresh ui
        self.save_notes()
        self.notesChanged.emit()
        self.updateFilteredNotes()
    
    @Slot(int)
    def deleteNote(self, note_id):
        self._notes = [note for note in self._notes if note["id"] != note_id]
        self.save_notes()
        self.notesChanged.emit()
        self.updateFilteredNotes()
    
    @Slot(int, result='QVariant')
    def getNote(self, note_id):
        for note in self._notes:
            if note["id"] == note_id:
                return note
        return {}
    
    @Slot(int, result='QVariant')
    def getNotePreview(self, note_id):
        """Return note preview for grid view - performance optimization"""
        for note in self._notes:
            if note["id"] == note_id:
                preview_length = 150
                return {
                    "id": note["id"],
                    "title": note["title"],
                    "preview": note["content"][:preview_length] + "..." 
                               if len(note["content"]) > preview_length 
                               else note["content"],
                    "created": note.get("created", ""),
                    "modified": note.get("modified", "")
                }
        return {}

    @Slot()
    def increaseFontSize(self):
        """Increase only the main editor font size by 1 pixel"""
        old_size = self._config["fontSize"]
        self._config["fontSize"] = min(100, self._config["fontSize"] + 1)

        if self._config["fontSize"] != old_size:
            self.save_config()
            self.configChanged.emit()   

    @Slot()
    def decreaseFontSize(self):
        """Decrease only the main editor font size by 1 pixel"""
        old_size = self._config["fontSize"]
        self._config["fontSize"] = max(1, self._config["fontSize"] - 1)

        if self._config["fontSize"] != old_size:
            self.save_config()
            self.configChanged.emit()

    @Slot()
    def increaseCardFontSize(self):
        """Increase card font sizes"""
        old_size = self._config["cardFontSize"]
        self._config["cardFontSize"] = min(100, self._config["cardFontSize"] + 1)
        
        if self._config["cardFontSize"] != old_size:
            self.save_config()
            self.configChanged.emit()   

    @Slot()
    def decreaseCardFontSize(self):
        """Decrease card font sizes"""
        old_size = self._config["cardFontSize"]
        self._config["cardFontSize"] = max(1, self._config["cardFontSize"] - 1)
        
        if self._config["cardFontSize"] != old_size:
            self.save_config()
            self.configChanged.emit()

    @Slot()
    def increaseCardWidth(self):
        """Increase card width"""
        old_width = self._config["cardWidth"]
        self._config["cardWidth"] = min(500, self._config["cardWidth"] + 1)
        
        if self._config["cardWidth"] != old_width:
            self.save_config()
            self.configChanged.emit()
    
    @Slot()
    def decreaseCardWidth(self):
        """Decrease card width"""
        old_width = self._config["cardWidth"]
        self._config["cardWidth"] = max(150, self._config["cardWidth"] - 1)
        
        if self._config["cardWidth"] != old_width:
            self.save_config()
            self.configChanged.emit()
    
    @Slot()
    def increaseCardHeight(self):
        """Increase card height"""
        old_height = self._config["cardHeight"]
        self._config["cardHeight"] = min(400, self._config["cardHeight"] + 1)
        
        if self._config["cardHeight"] != old_height:
            self.save_config()
            self.configChanged.emit()
    
    @Slot()
    def decreaseCardHeight(self):
        """Decrease card height"""
        old_height = self._config["cardHeight"]
        self._config["cardHeight"] = max(120, self._config["cardHeight"] - 1)
        
        if self._config["cardHeight"] != old_height:
            self.save_config()
            self.configChanged.emit()

    @Slot(int)
    def setCardWidth(self, width):
        """Set card width"""
        self._config["cardWidth"] = max(150, min(400, width))
        self.save_config()
        self.configChanged.emit()
    
    @Slot(int)
    def setCardHeight(self, height):
        """Set card height"""
        self._config["cardHeight"] = max(120, min(300, height))
        self.save_config()
        self.configChanged.emit()
    
def main():
    app = QGuiApplication(sys.argv)
    
    engine = QQmlApplicationEngine()
    notes_manager = NotesManager()
    
    engine.rootContext().setContextProperty("notesManager", notes_manager)
    engine.load(QUrl.fromLocalFile("main.qml"))
    
    if not engine.rootObjects():
        return -1
    
    return app.exec()

if __name__ == "__main__":
    sys.exit(main())