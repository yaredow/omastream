import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui

Column {
  id: root

  property string activeInstanceUrl: "https://inv.tux.pizza"
  property var defaultInstances: [
    "https://inv.tux.pizza",
    "https://invidious.nerdvpn.de",
    "https://invidious.privacydev.net"
  ]
  property var customInstances: []

  signal instanceSelected(string url)
  signal customInstanceAdded(string url)

  spacing: Style.space(16)
  width: parent.width

  Text {
    text: "Invidious Instance Manager"
    font.pixelSize: 16
    font.bold: true
    color: Color.menu.text
  }

  Text {
    text: "Select a public server or enter your custom/self-hosted Invidious instance URL for privacy and high speed."
    font.pixelSize: 12
    color: Color.menu.text
    opacity: 0.7
    wrapMode: Text.Wrap
    width: parent.width
  }

  // Active Instance indicator
  Rectangle {
    width: parent.width
    height: Style.space(40)
    radius: Style.space(6)
    color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.1)
    border.color: Color.accent
    border.width: 1

    Row {
      anchors.fill: parent
      anchors.margins: 10
      spacing: 8

      Text {
        text: "Active Instance:"
        font.bold: true
        font.pixelSize: 12
        color: Color.accent
      }

      Text {
        text: root.activeInstanceUrl
        font.pixelSize: 12
        color: Color.menu.text
      }
    }
  }

  // Section: Public instances list
  Text {
    text: "Public Instances"
    font.pixelSize: 13
    font.bold: true
    color: Color.menu.text
  }

  Column {
    width: parent.width
    spacing: Style.space(8)

    Repeater {
      model: root.defaultInstances

      delegate: Rectangle {
        required property string modelData

        width: parent.width
        height: Style.space(36)
        radius: Style.space(6)
        color: modelData === root.activeInstanceUrl ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : Color.menu.background
        border.color: modelData === root.activeInstanceUrl ? Color.accent : Color.menu.border
        border.width: 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.instanceSelected(modelData)
        }

        Row {
          anchors.fill: parent
          anchors.margins: 8
          spacing: 10

          Text {
            text: modelData === root.activeInstanceUrl ? "\uf00c" : "\uf111"
            font.pixelSize: 12
            color: modelData === root.activeInstanceUrl ? Color.accent : Color.menu.text
            opacity: modelData === root.activeInstanceUrl ? 1.0 : 0.4
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: modelData
            font.pixelSize: 12
            color: Color.menu.text
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
  }

  // Section: Add Custom Instance
  Text {
    text: "Add Custom / Self-Hosted Instance"
    font.pixelSize: 13
    font.bold: true
    color: Color.menu.text
  }

  Row {
    width: parent.width
    spacing: Style.space(8)

    Rectangle {
      width: parent.width - Style.space(90)
      height: Style.space(36)
      radius: Style.space(6)
      color: Color.menu.background
      border.color: customInput.activeFocus ? Color.accent : Color.menu.border
      border.width: 1

      TextInput {
        id: customInput
        anchors.fill: parent
        anchors.margins: 8
        color: Color.menu.text
        font.pixelSize: 12
        clip: true

        Text {
          text: "e.g. https://my-invidious.example.com"
          color: Color.menu.text
          opacity: 0.4
          font.pixelSize: 12
          visible: customInput.text.length === 0 && !customInput.activeFocus
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }

    Rectangle {
      width: Style.space(80)
      height: Style.space(36)
      radius: Style.space(6)
      color: Color.accent

      Text {
        anchors.centerIn: parent
        text: "Add"
        color: "#ffffff"
        font.bold: true
        font.pixelSize: 12
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (customInput.text.trim().length > 0) {
            root.customInstanceAdded(customInput.text.trim())
            customInput.text = ""
          }
        }
      }
    }
  }
}
