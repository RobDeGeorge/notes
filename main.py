import sys
import json
import os
from pathlib import Path
from PySide6.QtGui import QGuiApplication, QFont
from PySide6.QtQml import QmlElement, qmlRegisterType
from PySide6.QtCore import QObject, Signal, Slot, Property, QUrl
from PySide6.QtQml import QQmlApplicationEngine

QML_IMPORT_NAME = "NotesApp"
QML_IMPORT_MAJOR_VERSION = 1

@QmlElement
class NotesManager(QObject):
    notesChanged = Signal()
    configChanged = Signal()
    
    def __init__(self):
        super().__init__()
        self.notes_file = "notes.json"
        self.config_file = "config.json"
        self._notes = []
        self._config = {}
        self.load_config()
        self.load_notes()
    
    def load_config(self):
        default_config = {
            "backgroundColor": "#2b2b2b",
            "cardColor": "#3c3c3c",
            "textColor": "#ffffff",
            "accentColor": "#4a9eff",
            "fontFamily": "Arial",
            "fontSize": 14,
            "cardFontSize": 12
        }
        
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r') as f:
                    loaded_config = json.load(f)
                    self._config = {**default_config, **loaded_config}
            else:
                self._config = default_config
                self.save_config()
        except Exception as e:
            print(f"Error loading config: {e}")
            self._config = default_config
    
    def save_config(self):
        try:
            with open(self.config_file, 'w') as f:
                json.dump(self._config, f, indent=2)
        except Exception as e:
            print(f"Error saving config: {e}")
    
    def load_notes(self):
        try:
            if os.path.exists(self.notes_file):
                with open(self.notes_file, 'r') as f:
                    self._notes = json.load(f)
            else:
                self._notes = []
        except Exception as e:
            print(f"Error loading notes: {e}")
            self._notes = []
        self.notesChanged.emit()
    
    def save_notes(self):
        try:
            with open(self.notes_file, 'w') as f:
                json.dump(self._notes, f, indent=2)
        except Exception as e:
            print(f"Error saving notes: {e}")
    
    def generate_title(self, content):
        """Generate a title from the first line of content"""
        if not content.strip():
            return "Untitled Note"
        
        # Get first line, remove extra whitespace
        first_line = content.split('\n')[0].strip()
        
        # Limit to reasonable title length
        if len(first_line) > 50:
            first_line = first_line[:47] + "..."
        
        return first_line if first_line else "Untitled Note"
    
    @Property(list, notify=notesChanged)
    def notes(self):
        return self._notes
    
    @Property('QVariant', notify=configChanged)
    def config(self):
        return self._config
    
    @Slot(str, result=int)
    def createNote(self, content):
        note_id = len(self._notes)
        title = self.generate_title(content)
        new_note = {
            "id": note_id,
            "title": title,
            "content": content
        }
        self._notes.append(new_note)
        self.save_notes()
        self.notesChanged.emit()
        return note_id
    
    @Slot(int, str)
    def updateNote(self, note_id, content):
        for note in self._notes:
            if note["id"] == note_id:
                note["title"] = self.generate_title(content)
                note["content"] = content
                break
        self.save_notes()
        self.notesChanged.emit()
    
    @Slot(int)
    def deleteNote(self, note_id):
        self._notes = [note for note in self._notes if note["id"] != note_id]
        self.save_notes()
        self.notesChanged.emit()
    
    @Slot(int, result='QVariant')
    def getNote(self, note_id):
        for note in self._notes:
            if note["id"] == note_id:
                return note
        return {}

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