import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property string videoId: ""
  property string title: ""
  property string author: ""
  property string durationText: ""
  property string viewCountText: ""
  property string publishedText: ""
  property string thumbnailUrl: ""

  signal playRequested(string videoId)

  height: Style.space(110)
  radius: Style.space(12)
  color: hoverArea.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12) : Qt.rgba(Color.menu.background.r, Color.menu.background.g, Color.menu.background.b, 0.6)
  border.color: hoverArea.containsMouse ? Color.accent : Qt.rgba(Color.menu.border.r, Color.menu.border.g, Color.menu.border.b, 0.3)
  border.width: 1

  Behavior on color { ColorAnimation { duration: 150 } }
  Behavior on border.color { ColorAnimation { duration: 150 } }

  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.playRequested(root.videoId)
  }

  Row {
    anchors.fill: parent
    anchors.margins: Style.space(10)
    spacing: Style.space(14)

    // Thumbnail Preview Card
    Rectangle {
      width: Style.space(150)
      height: parent.height
      radius: Style.space(8)
      color: "#181818"
      clip: true

      Image {
        id: thumb
        anchors.fill: parent
        source: root.thumbnailUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
      }

      // Thumbnail gradient overlay
      Rectangle {
        anchors.fill: parent
        gradient: Gradient {
          GradientStop { position: 0.0; color: "transparent" }
          GradientStop { position: 1.0; color: "#aa000000" }
        }
      }

      // Duration Badge Overlay
      Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 6
        height: 18
        width: durationTextLabel.implicitWidth + 10
        color: "#d9000000"
        radius: 4

        Text {
          id: durationTextLabel
          anchors.centerIn: parent
          text: root.durationText
          color: "#ffffff"
          font.family: Style.font.family
          font.pixelSize: 10
          font.bold: true
        }
      }
    }

    // Video Meta Column
    Column {
      width: parent.width - Style.space(235)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(5)

      Text {
        width: parent.width
        text: root.title
        color: Color.menu.text
        font.family: Style.font.family
        font.pixelSize: 13
        font.bold: true
        elide: Text.ElideRight
        maximumLineCount: 2
        wrapMode: Text.Wrap
        lineHeight: 1.15
      }

      Row {
        spacing: 6
        Text {
          text: "\uf007" // NerdFont User
          font.family: Style.font.family
          font.pixelSize: 10
          color: Color.accent
          opacity: 0.8
        }
        Text {
          text: root.author
          color: Color.accent
          font.family: Style.font.family
          font.pixelSize: 11
          font.bold: true
          elide: Text.ElideRight
        }
      }

      Row {
        spacing: 8
        Text {
          text: "\uf06e " + root.viewCountText // NerdFont Eye
          color: Color.menu.text
          font.family: Style.font.family
          opacity: 0.55
          font.pixelSize: 10
        }
        Text {
          text: "•"
          color: Color.menu.text
          font.family: Style.font.family
          opacity: 0.3
          font.pixelSize: 10
          visible: root.publishedText.length > 0
        }
        Text {
          text: root.publishedText
          color: Color.menu.text
          font.family: Style.font.family
          opacity: 0.55
          font.pixelSize: 10
        }
      }
    }

    // Play Action Pill Button
    Rectangle {
      width: Style.space(42)
      height: Style.space(42)
      radius: Style.space(21)
      color: playHover.containsMouse ? Color.accent : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
      border.color: Color.accent
      border.width: 1
      anchors.verticalCenter: parent.verticalCenter

      Behavior on color { ColorAnimation { duration: 150 } }

      Text {
        anchors.centerIn: parent
        text: "\uf04b" // NerdFont Play
        font.family: Style.font.family
        font.pixelSize: 14
        color: playHover.containsMouse ? "#ffffff" : Color.accent
      }

      MouseArea {
        id: playHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.playRequested(root.videoId)
      }
    }
  }
}
