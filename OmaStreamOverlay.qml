import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Wayland
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
    root.opened = true
    loadMockData("")
  }

  function close() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function") {
      root.shell.hide((root.manifest && root.manifest.id) || "user.omastream")
    }
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open("{}")
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

  PanelWindow {
    id: panelWindow
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omastream-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    // Dimmed scrim background
    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim
    }

    // Dismiss when clicking outside panel
    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    // Main Card Frame
    Rectangle {
      id: panel
      anchors.centerIn: parent
      width: Math.min(Style.space(840), parent.width - Style.space(40))
      height: Math.min(Style.space(640), parent.height - Style.space(40))
      radius: Style.space(16)
      color: Color.menu.background
      border.color: Qt.rgba(Color.menu.border.r, Color.menu.border.g, Color.menu.border.b, 0.4)
      border.width: 1

      MouseArea {
        anchors.fill: parent
        onClicked: {}
      }

      Column {
        anchors.fill: parent
        anchors.margins: Style.space(20)
        spacing: Style.space(16)

        // Header Navigation Bar Container (Anchored Left & Right)
        Item {
          width: parent.width
          height: Style.space(36)

          // Brand title & icon (Left aligned)
          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
              text: "\uf03d" // NerdFont Video Camera
              font.family: Style.font.family
              font.pixelSize: 20
              color: Color.accent
            }

            Text {
              text: "omaStream"
              font.family: Style.font.family
              font.pixelSize: 20
              font.bold: true
              color: Color.menu.text
            }

            Rectangle {
              height: 18
              width: 52
              radius: 9
              color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
              border.color: Color.accent
              border.width: 1
              anchors.verticalCenter: parent.verticalCenter

              Text {
                anchors.centerIn: parent
                text: "PREVIEW"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: 8
                font.bold: true
              }
            }
          }

          // Segmented Tab Controls (Right aligned)
          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: Style.space(34)
            width: Style.space(210)
            radius: Style.space(17)
            color: Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.08)

            Row {
              anchors.fill: parent
              anchors.margins: 3

              Rectangle {
                width: (parent.width) / 2
                height: parent.height
                radius: Style.space(14)
                color: root.activeTab === 0 ? Color.accent : "transparent"

                Text {
                  anchors.centerIn: parent
                  text: "\uf002 Search"
                  font.family: Style.font.family
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
                width: (parent.width) / 2
                height: parent.height
                radius: Style.space(14)
                color: root.activeTab === 1 ? Color.accent : "transparent"

                Text {
                  anchors.centerIn: parent
                  text: "\uf013 Server"
                  font.family: Style.font.family
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
        }

        // Subtly styled divider line
        Rectangle {
          width: parent.width
          height: 1
          color: Qt.rgba(Color.menu.border.r, Color.menu.border.g, Color.menu.border.b, 0.25)
        }

        // TAB 0: YouTube Search & Mock Results View
        Item {
          width: parent.width
          height: parent.height - Style.space(90)
          visible: root.activeTab === 0

          Column {
            anchors.fill: parent
            spacing: Style.space(14)

            SearchBar {
              width: parent.width
              onSearchRequested: function(q) {
                root.loadMockData(q)
              }
            }

            ListView {
              width: parent.width
              height: parent.height - Style.space(64)
              spacing: Style.space(10)
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
          height: parent.height - Style.space(90)
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
}
