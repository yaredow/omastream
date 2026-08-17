import QtQuick
import QtMultimedia
import Quickshell.Io

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
  readonly property bool resolving: resolveProcess.running
  readonly property bool seekable: player.seekable
  readonly property bool buffering: player.mediaStatus === MediaPlayer.LoadingMedia
    || player.mediaStatus === MediaPlayer.BufferingMedia
    || player.mediaStatus === MediaPlayer.StalledMedia
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

  property int requestSerial: 0
  property int activeRequestSerial: 0
  property var pendingRequest: null

  function playMedia(item, options) {
    if (!item || !item.id || !item.sourceType) return

    options = options || {}
    root.requestSerial += 1
    root.pendingRequest = {
      serial: root.requestSerial,
      item: item,
      mode: options.mode || "video"
    }
    root.currentItem = item
    root.mode = root.pendingRequest.mode
    root.playerError = ""
    root.resolveError = ""
    player.source = ""
    player.stop()

    if (resolveProcess.running) {
      resolveProcess.running = false
    } else {
      root.startPendingResolution()
    }
  }

  function startPendingResolution() {
    if (!root.pendingRequest || resolveProcess.running) return

    var request = root.pendingRequest
    root.pendingRequest = null
    root.activeRequestSerial = request.serial

    if (request.item.sourceType === "youtube") {
      var format = request.mode === "audio"
        ? "bestaudio[protocol^=http]/bestaudio"
        : "best[protocol^=http]/best"
      resolveProcess.command = [
        "yt-dlp",
        "--no-warnings",
        "--extractor-args", "youtube:player_client=android,web",
        "-g",
        "-f", format,
        "https://www.youtube.com/watch?v=" + request.item.id
      ]
      resolveProcess.running = true
      return
    }

    if (request.item.sourceType === "direct" || request.item.sourceType === "local") {
      root.startPlayback(request.item.url)
      return
    }

    root.resolveError = "Unsupported media source: " + request.item.sourceType
  }

  function startPlayback(url) {
    if (!url) {
      root.resolveError = "The media source did not provide a playable URL."
      return
    }
    player.source = url
    player.play()
  }

  function togglePlayback() {
    if (player.playbackState === MediaPlayer.PlayingState) player.pause()
    else if (player.playbackState === MediaPlayer.PausedState) player.play()
    else if (player.mediaStatus === MediaPlayer.EndOfMedia) {
      player.position = 0
      player.play()
    }
  }

  function stop() {
    root.requestSerial += 1
    root.pendingRequest = null
    if (resolveProcess.running) resolveProcess.running = false
    player.stop()
    player.source = ""
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

  MediaPlayer {
    id: player
    videoOutput: root.videoOutput
    playbackRate: root.playbackRate
    audioOutput: AudioOutput {
      volume: root.volume / 100.0
      muted: root.muted
    }
    onErrorOccurred: function(error, errorString) {
      root.playerError = errorString || "Media playback failed."
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
    }
  }
}
