import QtQuick
import QtMultimedia
import Quickshell.Io

import "services/DownloadModel.js" as DownloadModel
import "providers/YoutubeProvider.js" as YoutubeProvider
import "services"

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var videoOutput: null

  readonly property string state: resolving ? "resolving"
    : errorMessage ? "error"
    : player.mediaStatus === MediaPlayer.EndOfMedia ? "ended"
    : player.playbackState === MediaPlayer.PlayingState ? "playing"
    : player.playbackState === MediaPlayer.PausedState ? "paused"
    : currentItem ? "stopped" : "idle"
  readonly property bool running: state === "playing" || state === "paused"
  readonly property bool paused: state === "paused"
  readonly property bool canTogglePlayback: currentItem !== null
    && !resolving
    && (state === "playing" || state === "paused" || state === "ended")
  readonly property bool resolving: resolveProcess.running || relayProcess.running
  readonly property bool seekable: player.seekable
  readonly property bool buffering: player.mediaStatus === MediaPlayer.LoadingMedia
    || player.mediaStatus === MediaPlayer.BufferingMedia
    || player.mediaStatus === MediaPlayer.StalledMedia
  readonly property bool loading: requestLoading || buffering
  readonly property bool playbackActive: currentItem !== null
    && !errorMessage
    && (loading || state === "playing" || state === "paused" || state === "ended")
  readonly property int position: player.position
  readonly property int duration: player.duration
  readonly property real bufferProgress: player.bufferProgress
  readonly property string errorMessage: playerError || resolveError

  property var currentItem: null
  property string mode: "video"
  property int volume: 70
  property bool muted: false
  property real playbackRate: 1.0
  property string playerError: ""
  property string resolveError: ""
  property bool requestLoading: false
  property int playbackRetries: 0
  readonly property int maximumPlaybackRetries: 2

  property string activeFormatId: "auto"
  property string activeFormatLabel: "Auto"
  onActiveFormatIdChanged: console.log("ACTIVE FORMAT ID CHANGED TO:", activeFormatId)
  property string requestedFormatId: "auto"
  property string requestedFormatLabel: "Auto"
  property int formatRequestSerial: 0
  readonly property bool discoveringFormats: formatProcess.running

  property int requestSerial: 0
  property int activeRequestSerial: 0
  property var pendingRequest: null

  property var currentFormats: ({ playback: [], downloadVideo: [], downloadAudio: [] })
  property bool formatsLoading: discoveringFormats

  readonly property string formatsScriptPath: Qt.resolvedUrl("scripts/omastream-formats").toString().replace(/^file:\/\//, "")
  readonly property string resolveScriptPath: Qt.resolvedUrl("scripts/omastream-resolve").toString().replace(/^file:\/\//, "")
  readonly property string relayScriptPath: Qt.resolvedUrl("scripts/omastream-relay").toString().replace(/^file:\/\//, "")

  // Keep download service instance inside the long-lived service singleton
  readonly property var downloads: downloadServiceInstance

  DownloadService {
    id: downloadServiceInstance
  }

  function playMedia(item, options) {
    if (!item || !item.id || !item.sourceType) return
    console.log("PLAY MEDIA CALLED WITH options:", JSON.stringify(options))

    options = options || {}
    var requestedFormatId = options.formatId || "auto"
    var requestedFormatLabel = options.formatLabel || "Auto"
    if (requestedFormatId !== "auto" && item.sourceType === "youtube") {
      var available = root.currentFormats && root.currentFormats.playback
        ? root.currentFormats.playback : []
      var playable = false
      for (var i = 0; i < available.length; i++) {
        if (available[i].id === requestedFormatId
            && (available[i].isDirectStreamable 
                || available[i].transport === "hls"
                || available[i].transport === "relay")) {
          playable = true
          break
        }
      }
      if (!playable) {
        root.playerError = requestedFormatLabel + " is not directly playable by the embedded player."
        return
      }
    }

    root.requestSerial += 1
    root.pendingRequest = {
      serial: root.requestSerial,
      item: item,
      mode: options.mode || "video",
      formatId: options.formatId || "auto",
      formatLabel: options.formatLabel || "Auto"
    }
    if (!root.currentItem || root.currentItem.id !== item.id) {
      root.currentFormats = ({ playback: [], downloadVideo: [], downloadAudio: [] })
    }
    root.currentItem = item
    root.mode = root.pendingRequest.mode
    root.activeFormatId = root.pendingRequest.formatId
    root.activeFormatLabel = root.pendingRequest.formatLabel
    root.requestedFormatId = root.pendingRequest.formatId
    root.requestedFormatLabel = root.pendingRequest.formatLabel
    root.playerError = ""
    root.resolveError = ""
    root.requestLoading = true
    root.playbackRetries = 0
    player.source = ""
    player.stop()

    if (resolveProcess.running) {
      resolveProcess.running = false
    } else if (relayProcess.running) {
      relayProcess.running = false
    } else {
      root.startPendingResolution()
    }

    // Inspect available formats in background
    root.fetchFormats(item)
  }

  function fetchFormats(item) {
    if (!item || !item.id) return
    formatRequestSerial += 1
    formatProcess.targetId = item.id
    formatProcess.targetSerial = formatRequestSerial
    formatProcess.command = [root.formatsScriptPath, item.originalUrl]
    formatProcess.running = true
  }

  function startPendingResolution() {
    if (!root.pendingRequest || resolveProcess.running) return

    var request = root.pendingRequest
    root.pendingRequest = null
    root.activeRequestSerial = request.serial

    if (request.item.sourceType === "youtube") {
      var format = "best[protocol^=http]/best"
      if (request.mode === "audio") {
        format = "bestaudio[ext=m4a][protocol^=http]/bestaudio[protocol^=http]/bestaudio"
      } else if (request.formatId && request.formatId !== "auto") {
        var selected = null
        var playback = root.currentFormats && root.currentFormats.playback
          ? root.currentFormats.playback : []
        for (var p = 0; p < playback.length; p++) {
          if (playback[p].id === request.formatId) {
            selected = playback[p]
            break
          }
        }
        format = selected && selected.playbackSelector
          ? selected.playbackSelector
          : request.formatId
        if (selected && selected.transport === "relay") {
          relayProcess.command = [root.relayScriptPath, request.item.originalUrl, String(selected.playbackSelector)]
          relayProcess.running = true
          return
        }
      }

      resolveProcess.command = [
        root.resolveScriptPath,
        "--no-warnings",
        "-g",
        "-f", format,
        request.item.originalUrl
      ]
      resolveProcess.running = true
      return
    }

    if (request.item.sourceType === "direct" || request.item.sourceType === "local") {
      root.startPlayback(request.item.url)
      return
    }

    root.resolveError = "Unsupported media source: " + request.item.sourceType
    root.requestLoading = false
  }

  function startPlayback(url) {
    if (!url) {
      root.resolveError = "The media source did not provide a playable URL."
      root.requestLoading = false
      return
    }
    player.source = url
    player.play()
  }

  function retryPlayback() {
    if (!root.currentItem || root.currentItem.sourceType !== "youtube"
        || root.playbackRetries >= root.maximumPlaybackRetries) return

    root.playbackRetries += 1
    root.requestSerial += 1
    root.pendingRequest = {
      serial: root.requestSerial,
      item: root.currentItem,
      mode: root.mode,
      formatId: root.requestedFormatId,
      formatLabel: root.requestedFormatLabel
    }
    root.playerError = ""
    root.resolveError = ""
    root.requestLoading = true
    player.stop()
    player.source = ""

    if (resolveProcess.running) resolveProcess.running = false
    else if (relayProcess.running) relayProcess.running = false
    else root.startPendingResolution()
  }

  function togglePlayback() {
    if (player.playbackState === MediaPlayer.PlayingState) player.pause()
    else if (player.playbackState === MediaPlayer.PausedState) player.play()
    else if (player.mediaStatus === MediaPlayer.EndOfMedia) {
      player.position = 0
      player.play()
    } else if (player.source) player.play()
  }

  function stop() {
    root.requestSerial += 1
    root.pendingRequest = null
    root.requestLoading = false
    player.stop()
    player.source = ""
    root.currentItem = null
    if (resolveProcess.running) resolveProcess.running = false
    if (relayProcess.running) relayProcess.running = false
  }

  function seek(positionMs) {
    if (!player.seekable) return
    player.position = Math.max(0, Math.min(player.duration, Math.round(positionMs)))
  }

  function seekRelative(deltaMs) {
    seek(player.position + deltaMs)
  }

  function setVolume(value) {
    root.volume = Math.max(0, Math.min(100, Math.round(value)))
  }

  function toggleMute() {
    root.muted = !root.muted
  }

  function setPlaybackRate(value) {
    root.playbackRate = Math.max(0.25, Math.min(2.0, Number(value) || 1.0))
  }

  Timer {
    id: playbackRetryTimer
    interval: 650
    repeat: false
    onTriggered: root.retryPlayback()
  }

  MediaPlayer {
    id: player
    videoOutput: root.videoOutput
    playbackRate: root.playbackRate
    audioOutput: AudioOutput {
      volume: root.volume / 100.0
      muted: root.muted
    }
    onPlaybackStateChanged: {
      if (playbackState === MediaPlayer.PlayingState) root.requestLoading = false
    }
    onAudioTracksChanged: {
      if (player.audioTracks.length > 0 && player.activeAudioTrack === -1) {
        player.activeAudioTrack = 0
      }
    }
    onErrorOccurred: function(error, errorString) {
      root.playerError = errorString || "Media playback failed."
      var willRetry = root.currentItem && root.currentItem.sourceType === "youtube"
        && root.playbackRetries < root.maximumPlaybackRetries
      if (willRetry) playbackRetryTimer.restart()
      else root.requestLoading = false
    }
  }

  Process {
    id: relayProcess
    command: []
    stdout: SplitParser {
      onRead: function(line) {
        var url = String(line || "").trim()
        if (url.indexOf("http://") === 0 && root.activeRequestSerial === root.requestSerial) {
          root.startPlayback(url)
        }
      }
    }
    stderr: StdioCollector {
      id: relayErrors
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (root.pendingRequest) {
        Qt.callLater(root.startPendingResolution)
        return
      }
      if (exitCode !== 0 && root.activeRequestSerial === root.requestSerial) {
        root.resolveError = String(relayErrors.text || "").trim() || "Adaptive playback relay failed."
        root.requestLoading = false
      }
    }
  }

  Process {
    id: resolveProcess
    command: []
    stdout: StdioCollector {
      id: resolveOutput
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: resolveErrors
      waitForEnd: true
    }
    onExited: function(exitCode) {
      var completedSerial = root.activeRequestSerial

      if (root.pendingRequest) {
        Qt.callLater(root.startPendingResolution)
        return
      }
      if (completedSerial !== root.requestSerial) return

      if (exitCode !== 0) {
        root.resolveError = String(resolveErrors.text || "").trim()
          || "Failed to resolve the media stream."
        root.requestLoading = false
        return
      }

      var lines = String(resolveOutput.text || "").trim().split("\n")
      for (var i = 0; i < lines.length; i++) {
        var url = lines[i].trim()
        if (url.indexOf("https://") === 0 || url.indexOf("http://") === 0) {
          root.startPlayback(url)
          return
        }
      }
      root.resolveError = "The resolver returned no playable stream."
      root.requestLoading = false
    }
  }

  Process {
    id: formatProcess
    property string targetId: ""
    property int targetSerial: 0
    command: []
    stdout: StdioCollector {
      id: formatOutput
      waitForEnd: true
    }
    onExited: function(exitCode) {
      console.log("FORMAT PROCESS EXITED. Code:", exitCode, "Target:", formatProcess.targetId, "Current:", root.currentItem ? root.currentItem.id : "null", "TextLen:", formatOutput.text ? formatOutput.text.length : 0);
      if (formatProcess.targetSerial !== root.formatRequestSerial
          || formatProcess.targetId !== (root.currentItem ? root.currentItem.id : "")) return
      if (exitCode === 0 && formatOutput.text) {
        try {
          var parsed = JSON.parse(formatOutput.text)
          if (parsed && parsed.formats) {
            root.currentFormats = YoutubeProvider.normalizeFormats(parsed.formats)
            console.log("NORMALIZED FORMATS:", root.currentFormats.playback.length, "playback items");
          } else {
            console.log("JSON parsed but no formats array!");
          }
        } catch (e) {
            console.log("JSON PARSE ERROR:", e);
        }
      } else {
        console.log("FORMAT PROCESS FAILED OR EMPTY TEXT");
      }
    }
  }
}
