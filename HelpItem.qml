import QtQuick 2.15
import QtQuick.Controls 2.15

Row {
    property string label: ""
    property string shortcut: ""
    property real itemHeight: 25  // Default height
    property real fontSize: 12    // Default font size
    
    spacing: width * 0.05  // Spacing scales with width
    width: parent ? parent.width : 0
    height: itemHeight
    
    Text {
        text: label
        font.family: notesManager.config.fontFamily
        font.pixelSize: fontSize
        color: notesManager.config.textColor
        width: parent.width * 0.6  // 60% of width for label
        elide: Text.ElideRight
        anchors.verticalCenter: parent.verticalCenter
    }
    
    Text {
        text: shortcut
        font.family: notesManager.config.fontFamily
        font.pixelSize: fontSize
        font.bold: true
        color: notesManager.config.accentColor
        anchors.verticalCenter: parent.verticalCenter
    }
}