import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui

import "../services/DownloadModel.js" as DownloadModel

QQC.Popup {
  id: root

  property var mediaItem: null
  property var formats: ({ streamable: [], downloadVideo: [], downloadAudio: [] })

  property string selectedMode: "video_audio" // "video_audio", "audio_only", "video_only"
  property string selectedContainer: "mp4"
  property string selectedFormatId: "best"
  property string selectedQualityLabel: "Best Available"
  property string destinationDir: "~/Downloads"

  signal downloadRequested(var jobOptions)

  anchors.centerIn: parent
  width: Style.space(480)
  padding: Style.gapsOut * 2
  modal: true
  focus: true
  closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutside

  background: BorderSurface {
    color: Color.menu.background
    borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.normalBorderWidth))
    radius: Style.cornerRadius
  }

  contentItem: Column {
    spacing: Style.gapsOut * 1.5
    width: parent.width

    // Header
    Row {
      width: parent.width
      spacing: Style.gapsOut

      Text {
        text: "\uf019 Custom Download"
        font.pixelSize: Style.font.title
        font.bold: true
        color: Color.menu.text
        width: parent.width - closeBtn.width - Style.gapsOut
        elide: Text.ElideRight
      }

      Button {
        id: closeBtn
        iconText: "\uf00d"
        onClicked: root.close()
      }
    }

    // Media preview summary
    Row {
      width: parent.width
      spacing: Style.gapsOut

      Rectangle {
        width: Style.space(64)
        height: Style.space(36)
        radius: 2
        color: "#000000"
        clip: true

        Image {
          anchors.fill: parent
          source: (root.mediaItem && root.mediaItem.thumbnailUrl) || ""
          fillMode: Image.PreserveAspectCrop
        }
      }

      Column {
        width: parent.width - Style.space(64) - Style.gapsOut
        spacing: 2

        Text {
          text: (root.mediaItem && root.mediaItem.title) || "Untitled"
          font.pixelSize: Style.font.body
          font.bold: true
          color: Color.menu.text
          elide: Text.ElideRight
          width: parent.width
        }

        Text {
          text: (root.mediaItem && root.mediaItem.author) || ""
          font.pixelSize: Style.font.caption
          color: Color.muted
        }
      }
    }

    // Mode Selector
    Column {
      width: parent.width
      spacing: Style.gapsOut / 2

      Text {
        text: "DOWNLOAD TYPE"
        font.pixelSize: Style.font.caption
        font.bold: true
        color: Color.muted
      }

      Row {
        spacing: Style.gapsOut

        Button {
          text: "Video + Audio"
          iconText: "\uf03d"
          selected: root.selectedMode === "video_audio"
          active: root.selectedMode === "video_audio"
          onClicked: {
            root.selectedMode = "video_audio"
            root.selectedContainer = "mp4"
          }
        }

        Button {
          text: "Audio Only"
          iconText: "\uf028"
          selected: root.selectedMode === "audio_only"
          active: root.selectedMode === "audio_only"
          onClicked: {
            root.selectedMode = "audio_only"
            root.selectedContainer = "mp3"
          }
        }

        Button {
          text: "Video Only"
          iconText: "\uf008"
          selected: root.selectedMode === "video_only"
          active: root.selectedMode === "video_only"
          onClicked: {
            root.selectedMode = "video_only"
            root.selectedContainer = "mp4"
          }
        }
      }
    }

    // Resolution / Quality Selection
    Column {
      width: parent.width
      spacing: Style.gapsOut / 2

      Text {
        text: root.selectedMode === "audio_only" ? "AUDIO FORMAT & QUALITY" : "RESOLUTION & QUALITY"
        font.pixelSize: Style.font.caption
        font.bold: true
        color: Color.muted
      }

      Flow {
        width: parent.width
        spacing: Style.gapsOut / 2

        Button {
          text: "Best Available"
          selected: root.selectedFormatId === "best"
          active: root.selectedFormatId === "best"
          onClicked: {
            root.selectedFormatId = "best"
            root.selectedQualityLabel = "Best"
          }
        }

        Repeater {
          model: root.selectedMode === "audio_only"
            ? (root.formats && root.formats.downloadAudio ? root.formats.downloadAudio : [])
            : (root.formats && root.formats.downloadVideo ? root.formats.downloadVideo : [])

          delegate: Button {
            text: modelData.label || modelData.resolution
            selected: root.selectedFormatId === String(modelData.id)
            active: root.selectedFormatId === String(modelData.id)
            onClicked: {
              root.selectedFormatId = String(modelData.id)
              root.selectedQualityLabel = modelData.label || modelData.resolution
            }
          }
        }
      }
    }

    // Container / Format Selector
    Column {
      width: parent.width
      spacing: Style.gapsOut / 2

      Text {
        text: "OUTPUT CONTAINER"
        font.pixelSize: Style.font.caption
        font.bold: true
        color: Color.muted
      }

      Row {
        spacing: Style.gapsOut

        Repeater {
          model: root.selectedMode === "audio_only"
            ? ["mp3", "m4a", "opus"]
            : ["mp4", "mkv", "webm"]

          delegate: Button {
            text: String(modelData).toUpperCase()
            selected: root.selectedContainer === modelData
            active: root.selectedContainer === modelData
            onClicked: root.selectedContainer = modelData
          }
        }
      }
    }

    // Destination Notice
    Row {
      spacing: Style.gapsOut
      Text {
        text: "\uf07c Destination: ~/Downloads"
        font.pixelSize: Style.font.caption
        color: Color.muted
      }
    }

    // Bottom Action Row
    Row {
      anchors.right: parent.right
      spacing: Style.gapsOut

      Button {
        text: "Cancel"
        onClicked: root.close()
      }

      Button {
        text: "Start Download"
        iconText: "\uf019"
        active: true
        selected: true
        onClicked: {
          root.downloadRequested({
            formatMode: root.selectedMode,
            container: root.selectedContainer,
            formatId: root.selectedFormatId,
            qualityLabel: root.selectedQualityLabel,
            destination: root.destinationDir
          })
          root.close()
        }
      }
    }
  }
}
