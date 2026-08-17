import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "components"
import "services/MockData.js" as MockData

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property int activeTab: 0 // 0: Search, 1: Settings
  property string activeInstanceUrl: "https://inv.tux.pizza"
  property var videoList: []

  readonly property string mpvScriptPath: Qt.resolvedUrl("scripts/omastream-mpv").toString().replace(/^file:\/\//, "")

  function open(payloadJson) {
    opened = true
    loadMockData("")
  }

  function close() {
    opened = false
    if (shell) shell.toggle("user.omastream")
  }

  function loadMockData(query) {
    root.videoList = MockData.getSampleResults(query)
  }

  function launchMpv(videoId) {
    mpvProcess.command = [root.mpvScriptPath, videoId]
    mpvProcess.running = true
  }

  Process {
    id: mpvProcess
    command: []
  }

  Rectangle {
    id: panel
    anchors.centerIn: parent
    width: Math.min(Style.space(800), parent.width - Style.space(40))
    height: Math.min(Style.space(600), parent.height - Style.space(40))
    radius: Style.space(12)
    color: Color.menu.background
    border.color: Color.menu.border
    border.width: 1

    Column {
      anchors.fill: parent
      anchors.margins: Style.space(16)
      spacing: Style.space(14)

      // Header Bar
      Row {
        width: parent.width

        Text {
          text: "omaStream"
          font.pixelSize: 20
          font.bold: true
          color: Color.accent
          anchors.verticalCenter: parent.verticalCenter
        }

        Item {
          width: parent.width - 250
          height: 1
        }

        // Navigation Tabs
        Row {
          spacing: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter

          Rectangle {
            width: Style.space(80)
            height: Style.space(30)
            radius: Style.space(6)
            color: root.activeTab === 0 ? Color.accent : Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.08)

            Text {
              anchors.centerIn: parent
              text: "🔍 Search"
              color: root.activeTab === 0 ? "#ffffff" : Color.menu.text
              font.pixelSize: 12
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.activeTab = 0
            }
          }

          Rectangle {
            width: Style.space(90)
            height: Style.space(30)
            radius: Style.space(6)
            color: root.activeTab === 1 ? Color.accent : Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.08)

            Text {
              anchors.centerIn: parent
              text: "⚙️ Settings"
              color: root.activeTab === 1 ? "#ffffff" : Color.menu.text
              font.pixelSize: 12
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.activeTab = 1
            }
          }
        }
      }

      // Divider line
      Rectangle {
        width: parent.width
        height: 1
        color: Color.menu.border
        opacity: 0.5
      }

      // TAB 0: YouTube Search & Mock Results View
      Item {
        width: parent.width
        height: parent.height - Style.space(80)
        visible: root.activeTab === 0

        Column {
          anchors.fill: parent
          spacing: Style.space(12)

          SearchBar {
            width: parent.width
            onSearchRequested: function(q) {
              root.loadMockData(q)
            }
          }

          ListView {
            width: parent.width
            height: parent.height - Style.space(60)
            spacing: Style.space(8)
            clip: true

            model: root.videoList

            delegate: VideoCard {
              width: ListView.view.width
              videoId: modelData.videoId
              title: modelData.title
              author: modelData.author
              durationText: modelData.durationText
              viewCountText: modelData.viewCountText
              publishedText: modelData.publishedText
              thumbnailUrl: modelData.thumbnailUrl

              onPlayRequested: function(vId) {
                root.launchMpv(vId)
              }
            }
          }
        }
      }

      // TAB 1: Invidious Instance Settings View
      Item {
        width: parent.width
        height: parent.height - Style.space(80)
        visible: root.activeTab === 1

        InstanceSettings {
          width: parent.width
          activeInstanceUrl: root.activeInstanceUrl
          onInstanceSelected: function(url) {
            root.activeInstanceUrl = url
          }
          onCustomInstanceAdded: function(url) {
            root.activeInstanceUrl = url
          }
        }
      }
    }
  }
}
