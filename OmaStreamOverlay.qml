import QtQuick
import QtQuick.Controls as QQC
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

import "services/MediaModel.js" as MediaModel
import "views"
import "components"

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var service: null
  property bool opened: false

  property string currentMode: "discover" // "discover", "downloads"


  // Search state
  property var rawVideoList: []
  property bool isSearching: false
  property string errorMessage: ""
  property string currentQuery: ""
  property int searchSerial: 0

  property color foreground: Color.menu.text
  property color accent: Color.accent
  property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.56)
  property color faint: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)

  // Fullscreen state
  property bool fullscreen: false
  property bool controlsVisible: true

  // Playback state references
  readonly property bool playerRunning: service ? service.running : false
  readonly property bool playerPaused: service ? service.paused : false
  readonly property bool playerActive: service ? service.playbackActive : false
  readonly property string playingTitle: service && service.currentItem ? service.currentItem.title || "" : ""
  readonly property string playingAuthor: service && service.currentItem ? service.currentItem.author || "" : ""
  readonly property string playingThumb: service && service.currentItem ? service.currentItem.artworkUrl || "" : ""
  readonly property int activeDownloadCount: service && service.downloads ? service.downloads.activeCount : 0

  readonly property string searchScriptPath: Qt.resolvedUrl("scripts/omastream-search").toString().replace(/^file:\/\//, "")
  readonly property string uploadTimeScriptPath: Qt.resolvedUrl("scripts/omastream-upload-time").toString().replace(/^file:\/\//, "")
  property var metadataCache: ({})

  readonly property int cardWidth: Math.min(Style.space(1100), (panel ? panel.width : 1200) - Style.gapsOut * 2)
  readonly property int cardHeight: Math.min(Style.space(720), (panel ? panel.height : 800) - Style.gapsOut * 2)

  Timer {
    id: fullscreenControlsTimer
    interval: 3000
    repeat: false
    onTriggered: {
      if (!root.fullscreen || root.playerPaused) return
      if (root.qualityPopupOpen) return
      if (root.service && root.service.errorMessage) return
      root.controlsVisible = false
    }
  }

  readonly property bool qualityPopupOpen: fullscreenQualityMenu && fullscreenQualityMenu.popupOpen

  readonly property string playerErrorText: root.service ? (root.service.errorMessage || "") : ""
  readonly property string playerStatusText: root.service ? (root.service.statusMessage || "") : ""

  function stopPlaybackSession() {
    if (root.service && (root.service.currentItem || root.service.hasCurrentRequest))
      root.service.stop()
  }

  function revealFullscreenControls() {
    root.controlsVisible = true
    if (root.playerPaused || root.qualityPopupOpen || root.playerErrorText)
      fullscreenControlsTimer.stop()
    else
      fullscreenControlsTimer.restart()
  }

  function toggleControls() {
    root.controlsVisible = !root.controlsVisible
    if (root.controlsVisible) root.revealFullscreenControls()
    else fullscreenControlsTimer.stop()
  }

  onPlayerPausedChanged: {
    if (!root.fullscreen) return
    root.revealFullscreenControls()
  }

  Connections {
    target: root.service
    ignoreUnknownSignals: true
    function onCurrentItemChanged() {
      if (!root.service || !root.service.currentItem) {
        if (root.fullscreen) root.setFullscreen(false)
      }
    }
    function onModeChanged() {
      if (root.fullscreen && root.service && root.service.mode !== "video")
        root.setFullscreen(false)
    }
  }

  Connections {
    target: fullscreenQualityMenu
    ignoreUnknownSignals: true
    function onPopupOpenChanged() {
      if (fullscreenQualityMenu.popupOpen)
        root.revealFullscreenControls()
    }
  }

  function open(payloadJson) {
    root.opened = true
    if (root.currentMode === "discover") {
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  function close() {
    root.opened = false
    if (searchProcess.running) searchProcess.running = false
    if (hydrationProcess.running) hydrationProcess.running = false
  }

  function dismiss() {
    root.opened = false
    if (searchProcess.running) searchProcess.running = false
    if (hydrationProcess.running) hydrationProcess.running = false
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
    if (!root.service) return
    if (root.fullscreen) {
      root.service.videoOutput = fullscreenVideoOutput
    } else {
      root.service.videoOutput = discoverView.playerVideoOutput
    }
  }

  function setFullscreen(enabled) {
    root.fullscreen = enabled && root.service && root.service.mode === "video"
    root.controlsVisible = true
    attachVideoOutput()
    if (root.fullscreen) root.revealFullscreenControls()
    else fullscreenControlsTimer.stop()
    keyCatcher.forceActiveFocus()
  }

  function toggleFullscreen() {
    setFullscreen(!root.fullscreen)
  }

  function performSearch(query) {
    if (!query || query.trim() === "") return
    if (searchProcess.running) searchProcess.running = false
    if (hydrationProcess.running) hydrationProcess.running = false
    root.stopPlaybackSession()
    root.currentQuery = query.trim()
    root.isSearching = true
    root.errorMessage = ""
    root.rawVideoList = []
    root.searchSerial += 1

    searchProcess.activeSerial = root.searchSerial
    searchProcess.command = [root.searchScriptPath, query.trim(), "30"]
    searchProcess.running = true
  }

  function clearSearch() {
    if (searchProcess.running) searchProcess.running = false
    if (hydrationProcess.running) hydrationProcess.running = false
    root.stopPlaybackSession()
    root.searchSerial += 1
    root.currentQuery = ""
    root.rawVideoList = []
    root.errorMessage = ""
    root.isSearching = false
  }

  function startHydration(cards, serial) {
    if (!cards || cards.length === 0) return
    if (hydrationProcess.running) hydrationProcess.running = false

    var nowSecs = Math.floor(Date.now() / 1000)
    var toFetch = []
    var updatedCards = cards.slice(0)
    var cacheModified = false

    for (var i = 0; i < updatedCards.length; i++) {
      var item = updatedCards[i]
      if (item.uploadTimeState === "exact") continue

      var cached = root.metadataCache[item.id]
      if (cached && (nowSecs - cached.cachedAt) < 86400) {
        MediaModel.mergeHydrationUpdate(item, cached)
        cacheModified = true
      } else if (toFetch.length < 12) {
        toFetch.push(item.id)
      }
    }

    if (cacheModified) {
      root.rawVideoList = updatedCards
    }

    if (toFetch.length > 0) {
      hydrationProcess.activeSerial = serial
      hydrationProcess.command = [root.uploadTimeScriptPath].concat(toFetch)
      hydrationProcess.running = true
    }
  }

  function handleHydrationLine(line, serial) {
    if (serial !== root.searchSerial) return
    if (!line || !line.trim()) return
    try {
      var ev = JSON.parse(line.trim())
      if (!ev || !ev.id) return

      if (ev.state === "exact") {
        ev.cachedAt = Math.floor(Date.now() / 1000)
        root.metadataCache[ev.id] = ev

        var list = root.rawVideoList
        var found = false
        for (var i = 0; i < list.length; i++) {
          if (list[i].id === ev.id) {
            MediaModel.mergeHydrationUpdate(list[i], ev)
            found = true
            break
          }
        }
        if (found) {
          root.rawVideoList = list.slice(0)
        }
      }
    } catch (err) {
      // ignore parse error
    }
  }

  function playMedia(item, options) {
    if (!root.service || !item) return
    root.service.playMedia(item, options)
    root.currentMode = "discover"
    attachVideoOutput()
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

  function quickDownload(item) {
    if (!root.service || !root.service.downloads || !item) return
    var selector = "bestvideo*+bestaudio/best"
    var label = "Best Available"
    if (root.service.bestDownloadSelector)
      selector = root.service.bestDownloadSelector()
    var downloads = root.service.currentFormats && root.service.currentFormats.downloadVideo
      ? root.service.currentFormats.downloadVideo : []
    if (downloads.length > 0) {
      selector = downloads[0].downloadSelector || selector
      label = downloads[0].label || label
    }
    root.service.downloads.startDownload(item, {
      formatMode: "video_audio",
      container: "mp4",
      formatId: selector,
      qualityLabel: label,
      destination: "~/Downloads"
    })
  }

  function startCustomDownload(item, options) {
    if (!root.service || !root.service.downloads || !item) return
    root.service.downloads.startDownload(item, options)
  }

  Process {
    id: searchProcess
    property int activeSerial: 0
    command: []
    stdout: StdioCollector {
      id: searchCollector
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: searchStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (searchProcess.activeSerial !== root.searchSerial) return
      root.isSearching = false

      var rawOutput = String(searchCollector.text || "").trim()
      if (exitCode !== 0 || !rawOutput || rawOutput === "[]") {
        root.errorMessage = String(searchStderr.text || "").trim() || (rawOutput === "[]"
          ? "No videos found matching: \"" + root.currentQuery + "\""
          : "Search failed. Check that yt-dlp and jq are installed.")
        return
      }
      try {
        var parsedJson = JSON.parse(rawOutput)
        var cards = MediaModel.parseSearchResults(parsedJson)
        root.rawVideoList = cards
        if (cards.length === 0) {
          root.errorMessage = "No videos found matching: \"" + root.currentQuery + "\""
        } else {
          root.startHydration(cards, searchProcess.activeSerial)
        }
      } catch (err) {
        root.errorMessage = "Failed to parse search results."
      }
    }
  }

  Process {
    id: hydrationProcess
    property int activeSerial: 0
    command: []
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) {
        root.handleHydrationLine(line, hydrationProcess.activeSerial)
      }
    }
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

    BorderSurface {
      id: card
      width: root.fullscreen ? parent.width : root.cardWidth
      height: root.fullscreen ? parent.height : root.cardHeight
      anchors.centerIn: parent
      color: Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.normalBorderWidth))
      radius: root.fullscreen ? 0 : Style.cornerRadius

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        z: 1

        Keys.priority: Keys.AfterItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.fullscreen) root.setFullscreen(false)
            else root.dismiss()
            event.accepted = true
          } else if (event.key === Qt.Key_Space) {
            if (root.service) root.service.togglePlayback()
            event.accepted = true
          } else if (event.key === Qt.Key_Left) {
            if (root.service) root.service.seekRelative(-10000)
            event.accepted = true
          } else if (event.key === Qt.Key_Right) {
            if (root.service) root.service.seekRelative(10000)
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            if (root.service) root.service.setVolume(root.service.volume + 5)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            if (root.service) root.service.setVolume(root.service.volume - 5)
            event.accepted = true
          } else if (event.key === Qt.Key_F) {
            root.toggleFullscreen()
            event.accepted = true
          } else if (event.key === Qt.Key_M) {
            if (root.service) root.service.toggleMute()
            event.accepted = true
          } else if (event.key === Qt.Key_Slash) {
            if (!root.fullscreen && discoverView && discoverView.focusSearch)
              discoverView.focusSearch()
            event.accepted = true
          } else if (event.key === Qt.Key_C) {
            if (root.fullscreen) root.toggleControls()
            event.accepted = true
          }
        }

        // Fullscreen Mode Surface
        Rectangle {
          anchors.fill: parent
          color: "#000000"
          visible: root.fullscreen

          VideoOutput {
            id: fullscreenVideoOutput
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectFit
          }

          MouseArea {
            id: fullscreenSurfaceMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: (root.controlsVisible || root.playerErrorText) ? Qt.ArrowCursor : Qt.BlankCursor
            onPositionChanged: root.revealFullscreenControls()
            onClicked: function(mouse) {
              if (!root.controlsVisible && !root.playerErrorText) {
                root.revealFullscreenControls()
                return
              }
              if (root.service && !root.playerErrorText)
                root.service.togglePlayback()
              keyCatcher.forceActiveFocus()
            }
          }

          Rectangle {
            id: fullscreenLoadingOverlay
            anchors.centerIn: parent
            width: Style.space(52)
            height: width
            radius: width / 2
            color: "#cc000000"
            visible: root.service
              && !root.playerErrorText
              && root.service.showLoadingOverlay
            z: 2

            Text {
              anchors.centerIn: parent
              text: "\uf110"
              color: Color.accent
              font.pixelSize: Style.font.title
              transformOrigin: Item.Center

              RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                running: fullscreenLoadingOverlay.visible
              }
            }
          }

          Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Style.spacing.md
            anchors.bottomMargin: root.controlsVisible ? Style.space(100) : Style.spacing.md
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.playerStatusText
            visible: !!root.playerStatusText && !root.playerErrorText
            color: "#dddddd"
            font.pixelSize: Style.font.caption
            textFormat: Text.PlainText
            z: 3
          }

          Rectangle {
            anchors.fill: parent
            color: "#cc000000"
            visible: !!root.playerErrorText
            z: 4

            Column {
              anchors.centerIn: parent
              width: Math.min(parent.width - Style.spacing.lg * 2, Style.space(360))
              spacing: Style.spacing.md

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\uf071"
                font.pixelSize: Style.space(28)
                color: "#f59e0b"
                textFormat: Text.PlainText
              }

              Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: (root.service && root.service.mode === "audio")
                  ? "Unable to play audio"
                  : "Unable to play media"
                font.pixelSize: Style.font.body
                font.bold: true
                color: root.foreground
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
              }

              Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.playerErrorText
                font.pixelSize: Style.font.caption
                color: "#cccccc"
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
              }

              Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Retry"
                iconText: "\uf01e"
                tooltipText: "Retry playback"
                foreground: root.foreground
                accent: root.accent
                onClicked: {
                  if (root.service && root.service.retryCurrentRequest)
                    root.service.retryCurrentRequest()
                }
              }
            }
          }

          // Fullscreen Controls Overlay - Top Bar
          Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Style.space(56)
            color: "#cc000000"
            visible: root.controlsVisible && !root.playerErrorText
            z: 5

            Row {
              anchors.fill: parent
              anchors.margins: Style.gapsOut
              spacing: Style.gapsOut

              Text {
                text: root.playingTitle
                font.pixelSize: Style.font.title
                font.bold: true
                color: root.foreground
                textFormat: Text.PlainText
                elide: Text.ElideRight
                width: parent.width - fsTopActions.width - Style.gapsOut
                anchors.verticalCenter: parent.verticalCenter
              }

              Row {
                id: fsTopActions
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.spacing.sm

                QualityMenu {
                  id: fullscreenQualityMenu
                  formats: root.service ? root.service.currentFormats : ({})
                  formatsLoading: root.service ? root.service.formatsLoading : false
                  activeFormatId: root.service ? root.service.activeFormatId : "auto"
                  onQualitySelected: function(item) {
                    if (root.service && root.service.currentItem) {
                      root.service.playMedia(root.service.currentItem, {
                        mode: root.service.mode,
                        formatId: item.id,
                        formatLabel: item.label,
                        startPositionMs: root.service.position
                      })
                    }
                  }
                }

                Button {
                  id: fsCloseBtn
                  text: "Exit Fullscreen"
                  iconText: "\uf066"
                  onClicked: root.setFullscreen(false)
                }
              }
            }
          }

          // Fullscreen Controls Overlay - Bottom Transport Bar
          Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: Style.space(88)
            color: "#cc000000"
            visible: root.controlsVisible && !root.playerErrorText
            z: 5

            Column {
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: Style.spacing.panelPadding
              anchors.rightMargin: Style.spacing.panelPadding
              anchors.bottomMargin: Style.spacing.md
              spacing: Style.spacing.lg

              Row {
                width: parent.width
                spacing: Style.gapsOut

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.formatTime(root.service ? root.service.position : 0)
                  font.pixelSize: Style.font.body
                  color: "#cccccc"
                  width: Style.space(50)
                }

                Rectangle {
                  width: parent.width - Style.space(100) - Style.gapsOut * 2
                  height: Style.space(8)
                  radius: height / 2
                  color: "#44ffffff"
                  anchors.verticalCenter: parent.verticalCenter
                  opacity: (root.service && root.service.seekable) ? 1.0 : 0.45

                  Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: {
                      var dur = root.service ? root.service.duration : 0
                      var buf = root.service ? root.service.bufferProgress : 0
                      if (dur <= 0) return 0
                      return Math.max(0, parent.width * buf)
                    }
                    radius: height / 2
                    color: "#66ffffff"
                  }

                  Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: {
                      var dur = root.service ? root.service.duration : 0
                      var pos = root.service ? root.service.position : 0
                      if (dur <= 0) return 0
                      return Math.max(height, parent.width * (pos / dur))
                    }
                    radius: height / 2
                    color: Color.accent
                  }

                  MouseArea {
                    anchors.fill: parent
                    enabled: root.service && root.service.seekable && root.service.duration > 0
                    cursorShape: Qt.PointingHandCursor
                    function seekAt(mouseX) {
                      if (!root.service || !root.service.duration) return
                      var ratio = Math.max(0, Math.min(1, mouseX / width))
                      root.service.seek(ratio * root.service.duration)
                      root.revealFullscreenControls()
                    }
                    onClicked: function(mouse) { seekAt(mouse.x) }
                    onPositionChanged: function(mouse) {
                      if (pressed) seekAt(mouse.x)
                    }
                  }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.formatTime(root.service ? root.service.duration : 0)
                  font.pixelSize: Style.font.body
                  color: "#cccccc"
                  width: Style.space(50)
                  horizontalAlignment: Text.AlignRight
                }
              }

              Row {
                width: parent.width
                spacing: Style.gapsOut

                Row {
                  spacing: Style.spacing.sm
                  anchors.verticalCenter: parent.verticalCenter

                  Button {
                    iconText: "\uf04a"
                    tooltipText: "Seek -10s"
                    foreground: root.foreground
                    accent: root.accent
                    onClicked: if (root.service) root.service.seekRelative(-10000)
                  }

                  Button {
                    iconText: (root.service && root.service.running && !root.service.paused) ? "\uf04c" : "\uf04b"
                    tooltipText: (root.service && root.service.running && !root.service.paused) ? "Pause" : "Play"
                    foreground: root.foreground
                    accent: root.accent
                    selected: root.service && root.service.running && !root.service.paused
                    onClicked: if (root.service) root.service.togglePlayback()
                  }

                  Button {
                    iconText: "\uf04e"
                    tooltipText: "Seek +10s"
                    foreground: root.foreground
                    accent: root.accent
                    onClicked: if (root.service) root.service.seekRelative(10000)
                  }

                  Button {
                    iconText: "\uf04d"
                    tooltipText: "Stop"
                    foreground: root.foreground
                    accent: root.accent
                    onClicked: if (root.service) root.service.stop()
                  }
                }

                Item { width: Style.spacing.md; height: 1 }

                Row {
                  spacing: Style.spacing.sm
                  anchors.verticalCenter: parent.verticalCenter

                  Button {
                    text: ((root.service ? root.service.playbackRate : 1.0) + "x")
                    tooltipText: "Cycle Speed"
                    foreground: root.foreground
                    accent: root.accent
                    onClicked: {
                      if (!root.service) return
                      var r = root.service.playbackRate
                      if (r === 1.0) root.service.setPlaybackRate(1.25)
                      else if (r === 1.25) root.service.setPlaybackRate(1.5)
                      else if (r === 1.5) root.service.setPlaybackRate(2.0)
                      else if (r === 2.0) root.service.setPlaybackRate(0.75)
                      else root.service.setPlaybackRate(1.0)
                    }
                  }

                  Row {
                    spacing: Style.spacing.sm
                    anchors.verticalCenter: parent.verticalCenter

                    Button {
                      iconText: (root.service && root.service.muted) ? "\uf6a9" : "\uf028"
                      tooltipText: "Mute"
                      foreground: root.foreground
                      accent: root.accent
                      onClicked: if (root.service) root.service.toggleMute()
                    }

                    Rectangle {
                      width: Style.space(100)
                      height: Style.space(6)
                      radius: height / 2
                      color: root.faint
                      anchors.verticalCenter: parent.verticalCenter

                      Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(height, parent.width * ((root.service ? root.service.volume : 70) / 100.0))
                        radius: height / 2
                        color: Color.accent
                      }

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        function setVol(mouseX) {
                          if (!root.service) return
                          var vol = Math.max(0, Math.min(100, Math.round((mouseX / width) * 100)))
                          root.service.setVolume(vol)
                          root.revealFullscreenControls()
                        }
                        onClicked: function(mouse) { setVol(mouse.x) }
                        onPositionChanged: function(mouse) {
                          if (pressed) setVol(mouse.x)
                        }
                      }
                    }

                    Text {
                      text: (root.service ? Math.round(root.service.volume) : 70) + "%"
                      font.pixelSize: Style.font.body
                      color: "#cccccc"
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }
                }
              }
            }
          }
        }

        // Top Header & Mode Navigation Bar
        Item {
          id: topHeader
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: Style.space(64)
          visible: !root.fullscreen

          Row {
            anchors.left: parent.left
            anchors.leftMargin: Style.spacing.panelPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.md

            // App Brand Title
            Row {
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.sm

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "OMASTREAM"
                font.pixelSize: Style.font.title
                font.bold: true
                color: root.foreground
                textFormat: Text.PlainText
              }
            }

            Item { width: Style.spacing.lg; height: 1 }

            // Navigation Tabs
            Row {
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.xs

              Button {
                text: "Discover"
                selected: root.currentMode === "discover"
                foreground: root.foreground
                accent: root.accent
                fontSize: Style.font.caption
                onClicked: root.currentMode = "discover"
              }

              Button {
                text: "Downloads" + (root.activeDownloadCount > 0 ? " (" + root.activeDownloadCount + ")" : "")
                selected: root.currentMode === "downloads"
                foreground: root.foreground
                accent: root.accent
                fontSize: Style.font.caption
                onClicked: root.currentMode = "downloads"
              }
            }
          }

          // Close button anchored right
          Button {
            anchors.right: parent.right
            anchors.rightMargin: Style.spacing.panelPadding
            anchors.verticalCenter: parent.verticalCenter
            iconText: "\uf00d"
            tooltipText: "Close (Esc)"
            foreground: root.foreground
            accent: root.accent
            onClicked: root.dismiss()
          }

          // Header bottom separator
          Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: root.faint
          }
        }

        // Active View Container
        Item {
          anchors.top: topHeader.bottom
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          visible: !root.fullscreen

          DiscoverView {
            id: discoverView
            anchors.fill: parent
            visible: root.currentMode === "discover"
            service: root.service
            rawVideoList: root.rawVideoList
            isSearching: root.isSearching
            errorMessage: root.errorMessage
            currentQuery: root.currentQuery
            playerService: root.service
            playerActive: root.playerActive

            onSearchTriggered: function(q) {
              root.performSearch(q)
            }

            onClearSearchRequested: {
              root.clearSearch()
            }

            onPlayRequested: function(item, opts) {
              root.playMedia(item, opts)
            }

            onQuickDownloadRequested: function(item) {
              root.quickDownload(item)
            }

            onCustomDownloadRequested: function(item, opts) {
              root.startCustomDownload(item, opts)
            }

            onFullscreenRequested: root.setFullscreen(true)

            onQualityChanged: function(formatItem) {
              if (root.service && root.service.currentItem) {
                root.service.playMedia(root.service.currentItem, {
                  mode: root.service.mode,
                  formatId: formatItem.id,
                  formatLabel: formatItem.label,
                  startPositionMs: root.service.position
                })
              }
            }
          }

          DownloadsView {
            id: downloadsView
            anchors.fill: parent
            anchors.margins: Style.spacing.panelPadding
            visible: root.currentMode === "downloads"
            downloadService: root.service ? root.service.downloads : null
          }
        }
      }
    }
  }
}
