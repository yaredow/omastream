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

  height: Style.space(100)
  radius: Style.space(8)
  color: hoverArea.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.08) : Color.menu.background
  border.color: hoverArea.containsMouse ? Color.accent : Color.menu.border
  border.width: 1

  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.playRequested(root.videoId)
  }

  Row {
    anchors.fill: parent
    anchors.margins: Style.space(8)
    spacing: Style.space(12)

    // Thumbnail container
    Item {
      width: Style.space(140)
      height: parent.height

      Image {
        id: thumb
        anchors.fill: parent
        source: root.thumbnailUrl
        fillMode: Image.PreserveAspectCrop
        clip: true

        Rectangle {
          anchors.fill: parent
          color: "#20000000"
        }
      }

      // Duration badge overlay
      Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 4
        height: 18
        width: durationTextLabel.implicitWidth + 8
        color: "#d0000000"
        radius: 3

        Text {
          id: durationTextLabel
          anchors.centerIn: parent
          text: root.durationText
          color: "#ffffff"
          font.pixelSize: 10
          font.bold: true
        }
      }
    }

    // Video details column
    Column {
      width: parent.width - Style.space(210)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(4)

      Text {
        width: parent.width
        text: root.title
        color: Color.menu.text
        font.pixelSize: 13
        font.bold: true
        elide: Text.ElideRight
        maximumLineCount: 2
        wrapMode: Text.Wrap
      }

      Text {
        text: root.author
        color: Color.accent
        font.pixelSize: 11
        elide: Text.ElideRight
      }

      Row {
        spacing: 8
        Text {
          text: root.viewCountText
          color: Color.menu.text
          opacity: 0.6
          font.pixelSize: 10
        }
        Text {
          text: "•"
          color: Color.menu.text
          opacity: 0.4
          font.pixelSize: 10
          visible: root.publishedText.length > 0
        }
        Text {
          text: root.publishedText
          color: Color.menu.text
          opacity: 0.6
          font.pixelSize: 10
        }
      }
    }

    // Play action button
    Rectangle {
      width: Style.space(36)
      height: Style.space(36)
      radius: Style.space(18)
      color: playHover.containsMouse ? Color.accent : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
      anchors.verticalCenter: parent.verticalCenter

      Text {
        anchors.centerIn: parent
        text: "\uf04b"
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
