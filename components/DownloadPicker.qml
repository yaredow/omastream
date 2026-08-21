import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui

QQC.Popup {
  id: root

  property var item: null
  property var formats: ({ playback: [], downloadVideo: [], downloadAudio: [] })
  property bool formatsLoading: false

  property color foreground: Color.menu.text
  property color accent: Color.accent
  property color mutedText: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.56)
  property color faint: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)

  signal downloadRequested(var item, var options)

  property bool showAudioOnly: false

  modal: true
  dim: true
  focus: true
  closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutside

  width: Style.space(260)
  padding: Style.spacing.md

  x: Math.max(0, ((parent ? parent.width : 500) - width) / 2)
  y: Math.max(0, ((parent ? parent.height : 460) - height) / 2)

  background: BorderSurface {
    color: Color.menu.background
    borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.normalBorderWidth))
    radius: Style.cornerRadius
  }

  onOpened: {
    root.showAudioOnly = false
  }

  contentItem: Column {
    spacing: Style.spacing.xs
    width: parent.width

    // Header
    Item {
      width: parent.width
      height: Style.space(32)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.formatsLoading ? "DETECTING FORMATS..." : (root.showAudioOnly ? "DOWNLOAD AUDIO" : "DOWNLOAD VIDEO")
        font.pixelSize: Style.font.caption
        font.bold: true
        color: root.mutedText
        textFormat: Text.PlainText
      }

      Button {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        iconText: root.showAudioOnly ? "\uf03d" : "\uf028"
        text: root.showAudioOnly ? "Video" : "Audio"
        fontSize: Style.font.caption
        foreground: root.foreground
        accent: root.accent
        onClicked: root.showAudioOnly = !root.showAudioOnly
      }
    }

    // Quality List
    Repeater {
      model: {
        if (root.showAudioOnly) {
          var aud = (root.formats && root.formats.downloadAudio && root.formats.downloadAudio.length > 0)
            ? root.formats.downloadAudio
            : []
          return [{ id: "best", label: "Best Audio Quality", detail: "MP3" }].concat(aud)
        } else {
          var vid = (root.formats && root.formats.downloadVideo && root.formats.downloadVideo.length > 0)
            ? root.formats.downloadVideo
            : []
          return [{ id: "best", label: "Best Available", detail: "Video + Audio" }].concat(vid)
        }
      }

      delegate: Rectangle {
        width: parent.width
        height: Style.space(36)
        radius: 2
        color: itemMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"

        Row {
          anchors.fill: parent
          anchors.leftMargin: Style.spacing.sm
          anchors.rightMargin: Style.spacing.sm
          spacing: Style.spacing.sm

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf019"
            color: root.mutedText
            font.pixelSize: Style.font.body
            width: Style.space(16)
            textFormat: Text.PlainText
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
              text: modelData.resolution || modelData.label || "Best"
              font.pixelSize: Style.font.body
              font.bold: false
              color: root.foreground
              textFormat: Text.PlainText
            }

            Text {
              text: root.showAudioOnly ? (modelData.ext ? modelData.ext.toUpperCase() : "MP3") : "MP4"
              font.pixelSize: Style.font.caption
              color: root.mutedText
              textFormat: Text.PlainText
            }
          }
        }

        MouseArea {
          id: itemMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            var opts = {
              formatMode: root.showAudioOnly ? "audio_only" : "video_audio",
              container: root.showAudioOnly ? (modelData.ext === "m4a" || modelData.ext === "opus" ? modelData.ext : "mp3") : "mp4",
              formatId: modelData.downloadSelector || modelData.id,
              qualityLabel: modelData.resolution || modelData.label || "Best",
              destination: "~/Downloads"
            }
            root.downloadRequested(root.item, opts)
            root.close()
          }
        }
      }
    }
  }
}
