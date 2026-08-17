import QtQuick
import QtQuick.Controls as QQC
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "components"
import "services/MediaModel.js" as MediaModel

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var service: null
  property bool opened: false
  property var videoList: []
  property int selectedIndex: -1
  property var selectedVideo: null
  property bool isSearching: false
  property string errorMessage: ""
  property string currentQuery: ""

  // Playback state is owned by the keep-loaded plugin service.
  readonly property bool playerRunning: service ? service.running : false
  readonly property bool playerPaused: service ? service.paused : false
  readonly property string playingTitle: service && service.currentItem ? service.currentItem.title || "" : ""
  readonly property string playingAuthor: service && service.currentItem ? service.currentItem.author || "" : ""
  readonly property string playingThumb: service && service.currentItem ? service.currentItem.artworkUrl || "" : ""
  readonly property string playingVideoId: service && service.currentItem ? service.currentItem.id || "" : ""
  readonly property int playerVolume: service ? service.volume : 70
  readonly property string playerMode: service ? service.mode : "none"
  readonly property bool playerResolving: service ? service.resolving : false
  readonly property int playerPosition: service ? service.position : 0
  readonly property int playerDuration: service ? service.duration : 0
  readonly property bool playerSeekable: service ? service.seekable : false
  readonly property bool playerMuted: service ? service.muted : false
  readonly property bool inlineVideoActive: (playerRunning || playerResolving)
    && playerMode === "video"
    && selectedVideo
    && playingVideoId === selectedVideo.videoId
  property bool fullscreen: false
  property bool controlsVisible: true

  readonly property string searchScriptPath: Qt.resolvedUrl("scripts/omastream-search").toString().replace(/^file:\/\//, "")
  readonly property string downloadScriptPath: Qt.resolvedUrl("scripts/omastream-download").toString().replace(/^file:\/\//, "")

  // Consistent Omarchy style sizing
  readonly property int cardWidth: Math.min(Style.space(1100), (panel ? panel.width : 1200) - Style.gapsOut * 2)
  readonly property int cardHeight: Math.min(Style.space(720), (panel ? panel.height : 800) - Style.gapsOut * 2)

  Timer {
    id: fullscreenControlsTimer
    interval: 3000
    repeat: false
    onTriggered: if (root.fullscreen) root.controlsVisible = false
  }

  function open(payloadJson) {
    root.opened = true
    Qt.callLater(function() { searchInput.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "user.omastream")
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open("{}")
  }

  onServiceChanged: attachVideoOutput()

  Component.onCompleted: attachVideoOutput()

  function attachVideoOutput() {
    if (root.service)
      root.service.videoOutput = root.fullscreen ? fullscreenVideoOutput : videoOutputArea
  }

  function setFullscreen(enabled) {
    root.fullscreen = enabled && root.playerMode === "video"
    root.controlsVisible = true
    attachVideoOutput()
    if (root.fullscreen) fullscreenControlsTimer.restart()
    keyCatcher.forceActiveFocus()
  }

  function toggleFullscreen() {
    setFullscreen(!root.fullscreen)
  }

  function playSelectedVideo() {
    if (!root.selectedVideo) return
    root.runPlayer("play", root.selectedVideo.videoId, "video",
      root.selectedVideo.title, root.selectedVideo.author,
      root.selectedVideo.thumbnailUrl)
    keyCatcher.forceActiveFocus()
  }

  function toggleInlinePlayback() {
    if (root.inlineVideoActive) root.runPlayer("toggle", "", "", "", "", "")
    else root.playSelectedVideo()
    keyCatcher.forceActiveFocus()
  }

  function formatTime(milliseconds) {
    var total = Math.max(0, Math.floor(milliseconds / 1000))
    var hours = Math.floor(total / 3600)
    var minutes = Math.floor((total % 3600) / 60)
    var seconds = total % 60
    var secondText = seconds < 10 ? "0" + seconds : String(seconds)
    if (hours > 0)
      return hours + ":" + (minutes < 10 ? "0" + minutes : minutes) + ":" + secondText
    return minutes + ":" + secondText
  }

  function runPlayer(action, vId, mode, title, author, thumb) {
    if (!root.service) return

    if (action === "toggle") {
      root.service.togglePlayback()
    } else if (action === "stop") {
      root.service.stop()
    } else if (action === "play") {
      root.service.playMedia({
        id: vId,
        sourceType: "youtube",
        mediaType: "video",
        title: title,
        author: author,
        artworkUrl: thumb,
        providerData: { videoId: vId }
      }, { mode: mode })
    } else if (action === "volume") {
      root.service.setVolume(parseInt(vId) || 0)
    }
  }

  function performSearch(query) {
    if (!query || query.trim() === "") return
    root.currentQuery = query.trim()
    root.isSearching = true
    root.errorMessage = ""
    root.videoList = []
    root.selectedIndex = -1
    root.selectedVideo = null

    searchProcess.command = [root.searchScriptPath, query.trim()]
    searchProcess.running = true
  }

  function selectVideo(index) {
    if (index >= 0 && index < root.videoList.length) {
      root.selectedIndex = index
      root.selectedVideo = root.videoList[index]
    }
  }

  function downloadCurrentVideo() {
    if (!root.selectedVideo) return
    downloadProcess.command = [root.downloadScriptPath, root.selectedVideo.videoId]
    downloadProcess.running = true
  }



  Process {
    id: searchProcess
    command: []
    stdout: StdioCollector {
      id: searchCollector
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.isSearching = false
      var rawOutput = String(searchCollector.text || "").trim()
      if (exitCode !== 0 || !rawOutput) {
        root.errorMessage = "Search process failed."
        return
      }
      try {
        var parsedJson = JSON.parse(rawOutput)
        var cards = MediaModel.parseSearchResults(parsedJson)
        root.videoList = cards
        if (cards.length > 0) {
          root.selectVideo(0)
        } else {
          root.errorMessage = "No videos found matching: \"" + root.currentQuery + "\""
        }
      } catch (err) {
        root.errorMessage = "Failed to parse search results."
      }
    }
  }

  Process {
    id: downloadProcess
    command: []
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region { item: card }
    color: "transparent"
    WlrLayershell.namespace: "omastream-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened && panelHover.hovered
      ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    HoverHandler {
      id: panelHover
    }

    // Main Card Surface (Exact Radio Atlas theme spec)
    BorderSurface {
      id: card
      width: root.fullscreen ? parent.width : root.cardWidth
      height: root.fullscreen ? parent.height : root.cardHeight
      anchors.centerIn: parent
      color: Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.normalBorderWidth))
      radius: Style.cornerRadius

      MouseArea {
        id: cardMouse
        anchors.fill: parent
        onClicked: keyCatcher.forceActiveFocus()
      }

      HoverHandler {
        id: cardHover
        onHoveredChanged: if (hovered) keyCatcher.forceActiveFocus()
      }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        z: 1

        Keys.priority: Keys.AfterItem
        Keys.onPressed: function(event) {
          if (searchInput.activeFocus) {
            if (event.key === Qt.Key_Escape) {
              if (searchInput.text) {
                searchInput.clear()
              } else {
                keyCatcher.forceActiveFocus()
              }
              event.accepted = true
            }
            return
          }
          if (event.key === Qt.Key_Escape) {
            if (root.fullscreen) root.setFullscreen(false)
            else root.dismiss()
            event.accepted = true
          } else if (event.key === Qt.Key_Slash) {
            searchInput.forceActiveFocus()
            searchInput.selectAll()
            event.accepted = true
          } else if (event.key === Qt.Key_Space) {
            if (root.playerRunning) root.runPlayer("toggle", "", "", "", "", "")
            event.accepted = true
          } else if (event.key === Qt.Key_Left) {
            if (root.service) root.service.seekRelative(-10000)
            event.accepted = true
          } else if (event.key === Qt.Key_Right) {
            if (root.service) root.service.seekRelative(10000)
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            if (root.service) root.service.setVolume(root.playerVolume + 5)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            if (root.service) root.service.setVolume(root.playerVolume - 5)
            event.accepted = true
          } else if (event.key === Qt.Key_M) {
            if (root.service) root.service.toggleMute()
            event.accepted = true
          } else if (event.key === Qt.Key_F) {
            root.toggleFullscreen()
            event.accepted = true
          }
        }
      }

      // Fullscreen player surface. It reuses the service MediaPlayer and only
      // changes the output target and presentation chrome.
      Item {
        id: fullscreenPlayer
        anchors.fill: parent
        visible: root.fullscreen
        z: 20

        Rectangle {
          anchors.fill: parent
          color: "#000000"
        }

        VideoOutput {
          id: fullscreenVideoOutput
          anchors.fill: parent
          fillMode: VideoOutput.PreserveAspectFit
        }

        MouseArea {
          anchors.fill: parent
          onClicked: {
            root.controlsVisible = true
            fullscreenControlsTimer.restart()
          }
        }

        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: Style.space(112)
          color: "#cc000000"
          visible: root.controlsVisible

          Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Style.spacing.panelPadding
            spacing: Style.spacing.sm

            PanelSlider {
              width: parent.width
              minimum: 0
              maximum: Math.max(1, root.playerDuration)
              step: 1000
              value: root.playerPosition
              enabled: root.playerSeekable
              trackColor: "#666666"
              fillColor: Color.accent
              knobColor: "#ffffff"
              onMoved: function(value) { if (root.service) root.service.seek(value) }
            }

            Row {
              width: parent.width
              spacing: Style.spacing.sm

              Button {
                iconText: root.playerRunning && !root.playerPaused ? "\uf04c" : "\uf04b"
                tooltipText: root.playerPaused ? "Play" : "Pause"
                foreground: "#ffffff"
                accent: Color.accent
                onClicked: root.runPlayer("toggle", "", "", "", "", "")
              }

              Text {
                text: root.formatTime(root.playerPosition) + " / " + root.formatTime(root.playerDuration)
                color: "#ffffff"
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }

              Item { width: parent.width - parent.children[0].width - parent.children[1].width - Style.spacing.sm; height: 1 }

              Button {
                iconText: "\uf066"
                tooltipText: "Exit fullscreen"
                foreground: "#ffffff"
                accent: Color.accent
                onClicked: root.setFullscreen(false)
              }
            }
          }
        }
      }

      // ==========================================
      // 1. TOP HEADER BAR
      // ==========================================
      Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Style.space(64)
        z: 2

        Row {
          anchors.left: parent.left
          anchors.leftMargin: Style.spacing.panelPadding
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing.md

          Text {
            text: "OMA STREAM"
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.heading
            font.bold: true
            color: Color.menu.text
            anchors.verticalCenter: parent.verticalCenter
          }

          // Live / Active status dot
          Rectangle {
            width: Style.space(6)
            height: width
            radius: width / 2
            color: root.playerRunning ? (root.playerPaused ? Color.urgent : Color.accent) : Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.25)
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        // Header Right: Settings & Dismiss (Official Button components)
        Row {
          id: headerRightControls
          anchors.right: parent.right
          anchors.rightMargin: Style.spacing.md
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing.xs

          Button {
            iconText: "\uf00d" // Close X
            tooltipText: "Close (Esc)"
            foreground: Color.menu.text
            accent: Color.urgent
            onClicked: root.dismiss()
          }
        }

        // Search Field
        TextField {
          id: searchInput
          anchors.right: headerRightControls.left
          anchors.rightMargin: Style.spacing.md
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(Style.space(310), card.width * 0.3)
          placeholderText: "Search YouTube videos..."
          foreground: Color.menu.text
          accent: Color.accent
          onAccepted: {
            if (text.trim()) root.performSearch(text.trim())
          }
        }

        // Header Divider Line
        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: 1
          color: Qt.rgba(Color.menu.border.r, Color.menu.border.g, Color.menu.border.b, 0.2)
        }
      }

      // ==========================================
      // 2. INTEGRATED BOTTOM PLAYER DOCK
      // ==========================================
      Item {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Style.space(104)
        z: 2

        // Bottom Player Divider Line
        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          height: 1
          color: Qt.rgba(Color.menu.border.r, Color.menu.border.g, Color.menu.border.b, 0.2)
        }

        Column {
          anchors.fill: parent
          anchors.leftMargin: Style.spacing.panelPadding
          anchors.rightMargin: Style.spacing.panelPadding
          anchors.topMargin: Style.spacing.xs
          anchors.bottomMargin: Style.spacing.xs
          spacing: Style.spacing.xs

          Row {
            width: parent.width
            height: Style.space(24)
            spacing: Style.spacing.sm

            Text {
              text: root.formatTime(root.playerPosition)
              color: Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.65)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
              width: Style.space(42)
              anchors.verticalCenter: parent.verticalCenter
            }

            PanelSlider {
              width: parent.width - Style.space(92)
              minimum: 0
              maximum: Math.max(1, root.playerDuration)
              step: 1000
              value: root.playerPosition
              enabled: root.playerSeekable
              trackColor: Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.12)
              fillColor: Color.accent
              knobColor: Color.menu.text
              onMoved: function(value) { if (root.service) root.service.seek(value) }
            }

            Text {
              text: root.formatTime(root.playerDuration)
              color: Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.65)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
              width: Style.space(42)
              horizontalAlignment: Text.AlignRight
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Row {
            width: parent.width
            height: parent.height - Style.space(28)
            spacing: Style.spacing.md

          // Left Section: Now Playing Metadata (Fixed width so it never overlaps controls)
          Row {
            width: parent.width - transportControls.width - volumeControls.width - (Style.spacing.md * 2) - 10
            height: parent.height
            spacing: Style.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            clip: true

            // Thumbnail
            Rectangle {
              width: Style.space(42)
              height: Style.space(42)
              radius: Math.max(2, Style.cornerRadius - 4)
              color: "#181818"
              anchors.verticalCenter: parent.verticalCenter
              clip: true

              Image {
                anchors.fill: parent
                source: root.playingThumb
                fillMode: Image.PreserveAspectCrop
                visible: root.playingThumb.length > 0
              }

              Text {
                anchors.centerIn: parent
                text: "\uf03d"
                font.family: Style.font.family
                font.pixelSize: 16
                color: Color.accent
                visible: !root.playingThumb
              }
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - Style.space(52)
              spacing: 2
              clip: true

              Text {
                width: parent.width
                text: root.playerRunning ? root.playingTitle : "No audio currently playing"
                color: Color.menu.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: root.playerResolving ? "Resolving stream..." : (root.playerRunning ? (root.playerPaused ? "Paused" : "Live Streaming · " + root.playingAuthor) : "Choose a stream to begin playback")
                color: root.playerResolving ? Color.accent : (root.playerRunning ? (root.playerPaused ? Color.urgent : Color.accent) : Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.45))
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }
          }

          // Center Section: Transport Controls (Play/Pause, Stop) using qs.Ui Button
          Row {
            id: transportControls
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.xs

            Button {
              iconText: root.playerRunning && !root.playerPaused ? "\uf04c" : "\uf04b"
              tooltipText: root.playerRunning && !root.playerPaused ? "Pause" : "Play"
              enabled: root.playerRunning
              foreground: Color.menu.text
              accent: Color.accent
              onClicked: root.runPlayer("toggle", "", "", "", "", "")
            }

            Button {
              iconText: "\uf04d"
              tooltipText: "Stop playback"
              enabled: root.playerRunning
              foreground: Color.menu.text
              accent: Color.urgent
              onClicked: root.runPlayer("stop", "", "", "", "", "")
            }
          }

          // Right Section: Volume Slider
          Row {
            id: volumeControls
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.xs

            Button {
              anchors.verticalCenter: parent.verticalCenter
              iconText: root.playerMuted || root.playerVolume === 0 ? "\uf026" : "\uf028"
              tooltipText: root.playerMuted ? "Unmute" : "Mute"
              enabled: root.playerRunning
              foreground: Color.menu.text
              accent: Color.accent
              onClicked: if (root.service) root.service.toggleMute()
            }

            PanelSlider {
              width: Style.space(110)
              anchors.verticalCenter: parent.verticalCenter
              minimum: 0
              maximum: 100
              step: 1
              integer: true
              value: root.playerVolume
              trackColor: Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.12)
              fillColor: Color.accent
              knobColor: Color.menu.text
              onMoved: function(nextValue) {
                root.runPlayer("volume", String(nextValue), "", "", "", "")
              }
            }
            Button {
              anchors.verticalCenter: parent.verticalCenter
              iconText: "\uf065"
              tooltipText: "Fullscreen (F)"
              enabled: root.playerRunning && root.playerMode === "video"
              foreground: Color.menu.text
              accent: Color.accent
              onClicked: root.setFullscreen(true)
            }
          }
        }
      }
      }

      // ==========================================
      // 3. MAIN SPLIT BODY AREA (Master / Detail)
      // ==========================================
      Item {
        id: body
        anchors.top: header.bottom
        anchors.bottom: footer.top
        anchors.left: parent.left
        anchors.right: parent.right

        // Search and detail view
        Item {
          anchors.fill: parent

          Row {
            anchors.fill: parent
            spacing: 0

            // ----------------------------------------
            // LEFT: Master Video Search Results (40% width)
            // ----------------------------------------
            Item {
              width: Math.floor(parent.width * 0.40)
              height: parent.height

              // Empty State
              Column {
                anchors.centerIn: parent
                spacing: Style.spacing.md
                visible: !root.isSearching && root.videoList.length === 0

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "\uf167" // YouTube icon
                  font.family: Style.font.family
                  font.pixelSize: 42
                  color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.6)
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.errorMessage ? root.errorMessage : "Search for a video to start streaming"
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.bodySmall
                  color: root.errorMessage ? Color.urgent : Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.5)
                }
              }

              // Loading State
              Column {
                anchors.centerIn: parent
                spacing: Style.spacing.sm
                visible: root.isSearching

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "\uf110" // Spinner
                  font.family: Style.font.family
                  font.pixelSize: 28
                  color: Color.accent

                  NumberAnimation on rotation {
                    from: 0; to: 360; duration: 1000
                    loops: Animation.Infinite; running: root.isSearching
                  }
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "LOADING SEARCH RESULTS"
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.caption
                  color: Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.5)
                }
              }

              // Video List View
              ListView {
                id: videoListView
                anchors.fill: parent
                anchors.margins: Style.spacing.sm
                spacing: Style.spacing.xs
                clip: true
                visible: !root.isSearching && root.videoList.length > 0
                model: root.videoList

                delegate: BorderSurface {
                  id: itemCard
                  width: ListView.view.width
                  height: Style.space(72)
                  radius: Style.cornerRadius
                  color: root.selectedIndex === index
                    ? Style.selectedFillFor(Color.menu.text, Color.accent)
                    : (cardMouseHover.containsMouse ? Style.hoverFillFor(Color.menu.text, Color.accent) : "transparent")
                  borderSpec: root.selectedIndex === index
                    ? Border.controlSpec("selected", Color.menu.text, Color.accent)
                    : (cardMouseHover.containsMouse ? Border.controlSpec("hover-cursor", Color.menu.text, Color.accent) : Border.none())

                  MouseArea {
                    id: cardMouseHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectVideo(index)
                  }

                  Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    spacing: Style.spacing.sm

                    // Thumbnail
                    Rectangle {
                      width: Style.space(88)
                      height: parent.height
                      radius: Math.max(2, Style.cornerRadius - 2)
                      color: "#181818"
                      clip: true

                      Image {
                        anchors.fill: parent
                        source: modelData.thumbnailUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                      }

                      // Duration Badge
                      Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 3
                        height: 15
                        width: dLabel.implicitWidth + 6
                        color: "#d9000000"
                        radius: 2

                        Text {
                          id: dLabel
                          anchors.centerIn: parent
                          text: modelData.durationText
                          color: "#ffffff"
                          font.family: Style.font.family
                          font.pixelSize: 8
                          font.bold: true
                        }
                      }
                    }

                    // Title & Channel
                    Column {
                      width: parent.width - Style.space(98)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 2

                      Text {
                        width: parent.width
                        text: modelData.title
                        color: root.selectedIndex === index ? Color.accent : Color.menu.text
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: root.selectedIndex === index
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                      }

                      Text {
                        width: parent.width
                        text: modelData.author + (modelData.viewCountText ? " · " + modelData.viewCountText : "")
                        color: Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.55)
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                      }
                    }
                  }
                }
              }
            }

            // Vertical Split Border Line
            Rectangle {
              width: 1
              height: parent.height
              color: Qt.rgba(Color.menu.border.r, Color.menu.border.g, Color.menu.border.b, 0.2)
            }

            // ----------------------------------------
            // RIGHT: Video Showcase, Details & Actions (60% width)
            // ----------------------------------------
            Item {
              width: parent.width - Math.floor(parent.width * 0.40) - 1
              height: parent.height

              Item {
                anchors.fill: parent
                anchors.margins: Style.spacing.md
                visible: root.selectedVideo !== null

                Column {
                  anchors.fill: parent
                  spacing: Style.spacing.md

                  // Inline video player
                  Rectangle {
                    id: inlinePlayer
                    width: parent.width
                    height: Math.floor(width * 9 / 18)
                    radius: Style.cornerRadius
                    color: "#121212"
                    clip: true
                    activeFocusOnTab: true

                    Keys.onSpacePressed: root.toggleInlinePlayback()
                    Keys.onLeftPressed: if (root.service) root.service.seekRelative(-10000)
                    Keys.onRightPressed: if (root.service) root.service.seekRelative(10000)

                    HoverHandler { id: inlinePlayerHover }

                    Image {
                      anchors.fill: parent
                      source: root.selectedVideo ? root.selectedVideo.thumbnailUrl : ""
                      fillMode: Image.PreserveAspectCrop
                      asynchronous: true
                      visible: !root.inlineVideoActive || root.playerResolving
                    }

                    VideoOutput {
                      id: videoOutputArea
                      anchors.fill: parent
                      fillMode: VideoOutput.PreserveAspectFit
                      visible: root.inlineVideoActive && !root.playerResolving
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.toggleInlinePlayback()
                    }

                    // Keep the thumbnail readable before playback and while resolving.
                    Rectangle {
                      anchors.fill: parent
                      visible: !root.inlineVideoActive || root.playerResolving
                      gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: "#b3000000" }
                      }
                    }

                    Rectangle {
                      anchors.fill: parent
                      color: "#33000000"
                      opacity: inlinePlayerHover.hovered || root.playerPaused ? 1 : 0
                      visible: opacity > 0

                      Behavior on opacity { NumberAnimation { duration: 140 } }
                    }

                    // Central action mirrors conventional video players.
                    Button {
                      anchors.centerIn: parent
                      visible: !root.inlineVideoActive || root.playerPaused || inlinePlayerHover.hovered
                      focusable: true
                      iconText: root.playerResolving ? "\uf110"
                        : (root.inlineVideoActive && !root.playerPaused ? "\uf04c" : "\uf04b")
                      iconSpinning: root.playerResolving
                      tooltipText: root.playerResolving ? "Loading video"
                        : (root.inlineVideoActive && !root.playerPaused ? "Pause (Space)" : "Play (Space)")
                      foreground: "#ffffff"
                      accent: Color.accent
                      iconSize: Style.font.heading * 1.5
                      enabled: !root.playerResolving
                      onClicked: root.toggleInlinePlayback()
                    }

                    Rectangle {
                      id: inlineControls
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.bottom: parent.bottom
                      height: Style.space(70)
                      color: "#d9000000"
                      opacity: inlinePlayerHover.hovered || root.playerPaused || root.playerResolving ? 1 : 0
                      visible: opacity > 0 && root.inlineVideoActive

                      Behavior on opacity { NumberAnimation { duration: 140 } }

                      Column {
                        anchors.fill: parent
                        anchors.leftMargin: Style.spacing.sm
                        anchors.rightMargin: Style.spacing.sm
                        anchors.topMargin: Style.spacing.xs
                        anchors.bottomMargin: Style.spacing.xs
                        spacing: Style.spacing.xs

                        PanelSlider {
                          width: parent.width
                          minimum: 0
                          maximum: Math.max(1, root.playerDuration)
                          step: 1000
                          value: root.playerPosition
                          enabled: root.playerSeekable
                          trackColor: "#666666"
                          fillColor: Color.accent
                          knobColor: "#ffffff"
                          onMoved: function(value) { if (root.service) root.service.seek(value) }
                        }

                        Row {
                          width: parent.width
                          height: Style.space(28)
                          spacing: Style.spacing.xs

                          Button {
                            id: inlinePlayButton
                            focusable: true
                            iconText: root.playerPaused ? "\uf04b" : "\uf04c"
                            tooltipText: root.playerPaused ? "Play (Space)" : "Pause (Space)"
                            foreground: "#ffffff"
                            accent: Color.accent
                            onClicked: root.toggleInlinePlayback()
                          }

                          Text {
                            id: inlineTimeLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.formatTime(root.playerPosition) + " / " + root.formatTime(root.playerDuration)
                            color: "#ffffff"
                            font.family: Style.font.menuFamily
                            font.pixelSize: Style.font.caption
                          }

                          Item {
                            width: Math.max(0, parent.width - inlinePlayButton.width
                              - inlineTimeLabel.width - inlineMuteButton.width
                              - inlineFullscreenButton.width - Style.spacing.xs * 4)
                            height: 1
                          }

                          Button {
                            id: inlineMuteButton
                            focusable: true
                            iconText: root.playerMuted || root.playerVolume === 0 ? "\uf026" : "\uf028"
                            tooltipText: root.playerMuted ? "Unmute (M)" : "Mute (M)"
                            foreground: "#ffffff"
                            accent: Color.accent
                            onClicked: if (root.service) root.service.toggleMute()
                          }

                          Button {
                            id: inlineFullscreenButton
                            focusable: true
                            iconText: "\uf065"
                            tooltipText: "Fullscreen (F)"
                            foreground: "#ffffff"
                            accent: Color.accent
                            onClicked: root.setFullscreen(true)
                          }
                        }
                      }
                    }
                  }

                  // Video Title
                  Text {
                    width: parent.width
                    text: root.selectedVideo ? root.selectedVideo.title : ""
                    color: Color.menu.text
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.font.heading
                    font.bold: true
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                  }

                  // Channel & Metrics Info Bar
                  Row {
                    width: parent.width
                    spacing: Style.spacing.md

                    Text {
                      text: "\uf007 " + (root.selectedVideo ? root.selectedVideo.author : "")
                      color: Color.accent
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                    }

                    Text {
                      text: "\uf06e " + (root.selectedVideo ? root.selectedVideo.viewCountText : "")
                      color: Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.65)
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.font.bodySmall
                    }

                    Text {
                      text: "\uf073 " + (root.selectedVideo ? root.selectedVideo.publishedText : "")
                      color: Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.65)
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.font.bodySmall
                      visible: root.selectedVideo && root.selectedVideo.publishedText !== ""
                    }
                  }

                  // Official Action Buttons Row (qs.Ui Button Components)
                  Row {
                    spacing: Style.spacing.sm

                    Button {
                      iconText: "\uf001" // Music
                      text: "Stream Audio"
                      tooltipText: "Play audio in background dock"
                      bordered: true
                      foreground: Color.menu.text
                      accent: Color.accent
                      onClicked: {
                        if (root.selectedVideo) {
                          root.runPlayer("play", root.selectedVideo.videoId, "audio", root.selectedVideo.title, root.selectedVideo.author, root.selectedVideo.thumbnailUrl)
                        }
                      }
                    }

                    Button {
                      iconText: "\uf03d" // Camera
                      text: "Watch Video"
                      tooltipText: "Play video in the embedded player"
                      bordered: true
                      foreground: Color.menu.text
                      accent: Color.accent
                      onClicked: {
                        if (root.selectedVideo) {
                          root.runPlayer("play", root.selectedVideo.videoId, "video", root.selectedVideo.title, root.selectedVideo.author, root.selectedVideo.thumbnailUrl)
                        }
                      }
                    }

                    Button {
                      iconText: "\uf019" // Download
                      text: "Download"
                      tooltipText: "Save to ~/Downloads"
                      bordered: true
                      foreground: Color.menu.text
                      accent: Color.accent
                      onClicked: root.downloadCurrentVideo()
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
