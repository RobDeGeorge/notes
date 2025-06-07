import QtQuick 2.15
import QtQuick.Controls 2.15

Row {
    property string label: ""
    property string shortcut: ""
    
    spacing: 20
    width: parent.width
    height: 25
    
    Text {
        text: label
        font.family: notesManager.config.fontFamily
        font.pixelSize: 12
        color: notesManager.config.textColor
        width: 200
        elide: Text.ElideRight
    }
    
    Text {
        text: shortcut
        font.family: notesManager.config.fontFamily
        font.pixelSize: 12
        font.bold: true
        color: notesManager.config.accentColor
    }
}