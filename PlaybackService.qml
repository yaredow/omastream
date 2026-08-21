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
  readonly property bool resolving: resolveProcess.running || waitingForRelayUrl
  // Relay MPEG-TS is not natively seekable; soft-seek via relay ?t= when we know duration.
  readonly property bool seekable: root.duration > 0
    && !!(currentItem && !currentItem.liveNow)
    && (player.seekable || activeTransport === "relay" || state === "playing" || state === "paused" || buffering)
  readonly property bool buffering: player.mediaStatus === MediaPlayer.LoadingMedia
    || player.mediaStatus === MediaPlayer.BufferingMedia
    || player.mediaStatus === MediaPlayer.StalledMedia
  readonly property bool loading: requestLoading || buffering
  // Big spinner only for resolve / initial load / stall — not routine BufferingMedia while playing.
  readonly property bool showLoadingOverlay: resolving || requestLoading
    || player.mediaStatus === MediaPlayer.LoadingMedia
    || player.mediaStatus === MediaPlayer.StalledMedia
  readonly property bool playbackActive: currentItem !== null
    && !errorMessage
    && (loading || state === "playing" || state === "paused" || state === "ended")
  readonly property bool hasCurrentRequest: currentItem !== null
  readonly property int position: player.position + streamStartOffsetMs
  readonly property int duration: {
    var metaMs = 0
    if (currentItem) {
      var secs = Number(currentItem.durationSeconds || currentItem.lengthSeconds || 0)
      if (secs > 0)
        metaMs = Math.round(secs * 1000)
    }
    if (metaMs > 0)
      return metaMs
    if (player.duration > 0)
      return player.duration + streamStartOffsetMs
    return 0
  }
  readonly property real bufferProgress: player.bufferProgress
  readonly property string errorMessage: playerError || resolveError
  readonly property string statusMessage: resolveStatusHint

  property var currentItem: null
  property string mode: "video"
  property int volume: 70
  property bool muted: false
  property real playbackRate: 1.0
  property string playerError: ""
  property string resolveError: ""
  property string resolveStatusHint: ""
  property bool requestLoading: false
  property bool waitingForRelayUrl: false
  property string activeTransport: ""
  property string relayBaseUrl: ""
  property int streamStartOffsetMs: 0
  property int pendingStartPositionMs: 0
  property int softSeekTargetMs: -1
  property int playbackRetries: 0
  readonly property int maximumPlaybackRetries: 2
  property int resolveAttempt: 0
  property int networkRetries: 0
  readonly property int maximumNetworkRetries: 1
  property string lastResolveAttemptId: ""
  property var activeResolveRequest: null
  property bool forceCombinedAudioFallback: false

  property string activeFormatId: "auto"
  property string activeFormatLabel: "Auto"
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
  readonly property string autoRelaySelector: "best[ext=mp4][protocol^=http]/best"

  readonly property var downloads: downloadServiceInstance

  DownloadService {
    id: downloadServiceInstance
  }

  Timer {
    id: playbackTimeoutTimer
    interval: 60000
    repeat: false
    onTriggered: {
      if (!root.currentItem || root.state === "playing" || root.state === "paused") return
      if (root.activeRequestSerial !== root.requestSerial) return
      root.resolveError = root.mode === "audio"
        ? "Timed out while resolving a playable audio stream."
        : "Timed out while resolving a playable stream."
      root.resolveStatusHint = ""
      root.requestLoading = false
      root.waitingForRelayUrl = false
      if (resolveProcess.running) resolveProcess.running = false
      if (relayProcess.running) relayProcess.running = false
    }
  }

  Timer {
    id: softSeekDebounceTimer
    interval: 280
    repeat: false
    onTriggered: {
      if (root.softSeekTargetMs < 0) return
      root.applySoftSeek(root.softSeekTargetMs)
      root.softSeekTargetMs = -1
    }
  }

  function audioSelectors() {
    return [
      {
        id: "direct-audio",
        selector: "bestaudio[ext=m4a][protocol^=http]/bestaudio[protocol^=http]"
      },
      {
        id: "combined-mp4",
        selector: "best[ext=mp4][protocol^=http]/best[protocol^=http]/best"
      }
    ]
  }

  function classifyResolveError(stderrText, exitCode, hadUrl) {
    var text = String(stderrText || "").toLowerCase()
    if (text.indexOf("requested format is not available") !== -1)
      return "requested-format-unavailable"
    if (text.indexOf("sign in") !== -1
        || text.indexOf("login required") !== -1
        || text.indexOf("confirm your age") !== -1
        || text.indexOf("age-restricted") !== -1
        || text.indexOf("private video") !== -1
        || text.indexOf("members-only") !== -1)
      return "auth-required"
    if (text.indexOf("http error") !== -1
        || text.indexOf("unable to download") !== -1
        || text.indexOf("timed out") !== -1
        || text.indexOf("timeout") !== -1
        || text.indexOf("network is unreachable") !== -1
        || text.indexOf("temporary failure") !== -1
        || text.indexOf("connection reset") !== -1
        || text.indexOf("connection refused") !== -1)
      return "temporary-network"
    if (exitCode === 0 && !hadUrl)
      return "no-url"
    if (exitCode !== 0)
      return "resolve-failed"
    return "ok"
  }

  function userFacingResolveError(category, mode) {
    if (category === "auth-required") {
      return mode === "audio"
        ? "This video requires sign-in or is restricted. Audio playback cannot continue."
        : "This video requires sign-in or is restricted. Playback cannot continue."
    }
    if (mode === "audio")
      return "Unable to resolve a playable audio stream for this video."
    return "Unable to resolve a playable stream for this video."
  }

  function cancelFormatProcess() {
    root.formatRequestSerial += 1
    if (formatProcess.running)
      formatProcess.running = false
  }

  function playMedia(item, options) {
    if (!item || !item.id || !item.sourceType) return

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

    var startMs = 0
    if (options.startPositionMs !== undefined && options.startPositionMs !== null)
      startMs = Math.max(0, Math.round(Number(options.startPositionMs) || 0))
    else if (options.resume && root.currentItem && root.currentItem.id === item.id)
      startMs = Math.max(0, root.position)

    root.requestSerial += 1
    root.pendingRequest = {
      serial: root.requestSerial,
      item: item,
      mode: options.mode || "video",
      formatId: options.formatId || "auto",
      formatLabel: options.formatLabel || "Auto",
      startPositionMs: startMs
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
    root.resolveStatusHint = ""
    root.requestLoading = true
    root.playbackRetries = 0
    root.resolveAttempt = 0
    root.networkRetries = 0
    root.lastResolveAttemptId = ""
    root.forceCombinedAudioFallback = false
    root.activeResolveRequest = null
    root.activeTransport = ""
    root.relayBaseUrl = ""
    root.streamStartOffsetMs = startMs
    root.pendingStartPositionMs = startMs
    root.softSeekTargetMs = -1
    softSeekDebounceTimer.stop()
    playbackRetryTimer.stop()
    playbackTimeoutTimer.restart()
    player.source = ""
    player.stop()

    console.log("omaStream playback request serial=" + root.requestSerial
      + " mode=" + root.pendingRequest.mode
      + " item=" + item.id
      + " startMs=" + startMs)

    if (resolveProcess.running) {
      resolveProcess.running = false
    } else if (relayProcess.running) {
      relayProcess.running = false
    } else {
      root.startPendingResolution()
    }

    root.fetchFormats(item)
  }

  function fetchFormats(item) {
    if (!item || !item.id) return
    root.formatRequestSerial += 1
    formatProcess.targetId = item.id
    formatProcess.targetSerial = root.formatRequestSerial
    formatProcess.command = [root.formatsScriptPath, item.originalUrl]
    if (formatProcess.running) {
      formatProcess.running = false
      Qt.callLater(function() {
        if (formatProcess.targetSerial === root.formatRequestSerial)
          formatProcess.running = true
      })
    } else {
      formatProcess.running = true
    }
  }

  function startPendingResolution() {
    if (!root.pendingRequest || resolveProcess.running || relayProcess.running) return

    var request = root.pendingRequest
    root.pendingRequest = null
    root.activeRequestSerial = request.serial
    root.activeResolveRequest = request
    root.resolveAttempt = root.forceCombinedAudioFallback ? 1 : 0
    root.networkRetries = 0
    root.resolveStatusHint = ""
    root.beginResolveAttempt()
  }

  function beginResolveAttempt() {
    var request = root.activeResolveRequest
    if (!request || resolveProcess.running || relayProcess.running) return
    if (request.serial !== root.requestSerial) return

    if (request.item.sourceType === "youtube") {
      var format = root.autoRelaySelector
      var attemptId = "video-auto-relay"
      var useRelay = false

      if (request.item.liveNow) {
        format = "best"
        attemptId = "live-best"
        useRelay = false
        if (request.mode === "audio") {
          root.resolveError = "Live streams are not supported in Audio Mode."
          root.resolveStatusHint = ""
          root.requestLoading = false
          playbackTimeoutTimer.stop()
          return
        }
      } else if (request.mode === "audio") {
        var selectors = root.audioSelectors()
        if (root.resolveAttempt < 0 || root.resolveAttempt >= selectors.length) {
          root.resolveError = root.userFacingResolveError("resolve-failed", "audio")
          root.resolveStatusHint = ""
          root.requestLoading = false
          playbackTimeoutTimer.stop()
          return
        }
        attemptId = selectors[root.resolveAttempt].id
        format = selectors[root.resolveAttempt].selector
        useRelay = false
      } else if (!request.formatId || request.formatId === "auto") {
        useRelay = false
        format = root.autoRelaySelector
        attemptId = "video-auto-relay"
      } else {
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
        attemptId = "format-" + request.formatId
        useRelay = !!(selected && selected.transport === "relay")
      }

      root.lastResolveAttemptId = attemptId
      console.log("omaStream resolve start serial=" + request.serial
        + " attempt=" + attemptId
        + (useRelay ? " transport=relay" : ""))

      if (useRelay) {
        root.resolveStatusHint = "Starting high-quality stream…"
        root.waitingForRelayUrl = true
        root.activeTransport = "relay"
        var startSecs = root.pendingStartPositionMs > 0 ? String(root.pendingStartPositionMs / 1000.0) : "0"
        console.log("SEEKING TO", startSecs); relayProcess.command = [root.relayScriptPath, request.item.originalUrl, String(format), startSecs]
        relayProcess.running = true
        return
      }

      root.activeTransport = "direct"
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
    playbackTimeoutTimer.stop()
  }

  function handleResolveFailure(exitCode, stderrText, hadUrl) {
    var request = root.activeResolveRequest
    if (!request || request.serial !== root.requestSerial) return

    var category = root.classifyResolveError(stderrText, exitCode, hadUrl)
    console.log("omaStream resolve failed serial=" + request.serial
      + " attempt=" + root.lastResolveAttemptId
      + " exit=" + exitCode
      + " reason=" + category)

    if (category === "auth-required") {
      root.resolveError = root.userFacingResolveError(category, request.mode)
      root.resolveStatusHint = ""
      root.requestLoading = false
      playbackTimeoutTimer.stop()
      return
    }

    if (category === "temporary-network"
        && root.networkRetries < root.maximumNetworkRetries) {
      root.networkRetries += 1
      root.resolveStatusHint = "Network issue while resolving. Retrying…"
      console.log("omaStream resolve network-retry serial=" + request.serial
        + " attempt=" + root.lastResolveAttemptId
        + " networkRetry=" + root.networkRetries)
      Qt.callLater(root.beginResolveAttempt)
      return
    }

    if (request.mode === "audio") {
      var selectors = root.audioSelectors()
      var canFallback = (category === "requested-format-unavailable"
          || category === "no-url"
          || category === "resolve-failed"
          || category === "temporary-network")
        && (root.resolveAttempt + 1) < selectors.length

      if (canFallback) {
        root.resolveAttempt += 1
        root.networkRetries = 0
        root.resolveStatusHint = "YouTube did not provide a playable audio-only stream. Trying a compatible stream…"
        console.log("omaStream resolve fallback serial=" + request.serial
          + " attempt=" + selectors[root.resolveAttempt].id)
        Qt.callLater(root.beginResolveAttempt)
        return
      }

      root.resolveError = root.userFacingResolveError(category, "audio")
      root.resolveStatusHint = ""
      root.requestLoading = false
      playbackTimeoutTimer.stop()
      return
    }

    root.resolveError = root.userFacingResolveError(category, request.mode)
    root.resolveStatusHint = ""
    root.requestLoading = false
    playbackTimeoutTimer.stop()
  }

  function startPlayback(url) {
    if (!url) {
      root.resolveError = "The media source did not provide a playable URL."
      root.resolveStatusHint = ""
      root.waitingForRelayUrl = false
      root.requestLoading = false
      playbackTimeoutTimer.stop()
      return
    }
    if (!root.currentItem || root.activeRequestSerial !== root.requestSerial)
      return

    root.waitingForRelayUrl = false
    root.playerError = ""
    root.resolveError = ""
    root.resolveStatusHint = ""
    playbackTimeoutTimer.stop()

    var playUrl = String(url)
    if (root.activeTransport === "relay") {
      var base = playUrl.replace(/\?.*$/, "").replace(/\/$/, "")
      root.relayBaseUrl = base
      playUrl = base + "/"
      root.streamStartOffsetMs = 0
      root.pendingStartPositionMs = 0
    } else {
      root.relayBaseUrl = ""
      root.streamStartOffsetMs = 0
      // Keep pendingStartPositionMs for native seek once seekable.
    }

    console.log("omaStream playback started serial=" + root.activeRequestSerial
      + " mode=" + root.mode
      + " transport=" + (root.activeTransport || "direct")
      + " fallback=" + (root.lastResolveAttemptId || "none"))
    player.source = playUrl
    player.play()
  }

  function applyPendingNativeSeek() {
    if (root.pendingStartPositionMs <= 0) return
    if (!player.seekable || player.duration <= 0) return
    var target = Math.min(root.pendingStartPositionMs, player.duration)
    player.position = target
    root.pendingStartPositionMs = 0
  }

  function applySoftSeek(positionMs) {
    if (!root.currentItem) return
    var target = Math.max(0, Math.round(positionMs))
    if (root.duration > 0)
      target = Math.min(target, root.duration)

    if (root.activeTransport === "relay" && root.relayBaseUrl) {
      console.log("omaStream: Cannot seek in a live relay stream.")
      return
    }

    root.playMedia(root.currentItem, {
      mode: root.mode,
      formatId: root.requestedFormatId,
      formatLabel: root.requestedFormatLabel,
      startPositionMs: target
    })
  }

  function retryPlayback() {
    if (!root.currentItem || root.currentItem.sourceType !== "youtube"
        || root.playbackRetries >= root.maximumPlaybackRetries) return

    root.playbackRetries += 1

    if (root.mode === "audio" && root.lastResolveAttemptId === "direct-audio") {
      root.forceCombinedAudioFallback = true
      root.resolveStatusHint = "Direct audio failed in the player. Trying a compatible stream…"
    }

    root.retryCurrentRequest(false)
  }

  function retryCurrentRequest(resetPlaybackRetries) {
    if (!root.currentItem) return

    if (resetPlaybackRetries !== false) {
      root.playbackRetries = 0
      root.forceCombinedAudioFallback = false
    }

    root.requestSerial += 1
    var resumeMs = Math.max(0, root.position)
    root.pendingRequest = {
      serial: root.requestSerial,
      item: root.currentItem,
      mode: root.mode,
      formatId: root.requestedFormatId,
      formatLabel: root.requestedFormatLabel,
      startPositionMs: resumeMs
    }
    root.playerError = ""
    root.resolveError = ""
    root.resolveStatusHint = ""
    root.requestLoading = true
    root.streamStartOffsetMs = resumeMs
    root.pendingStartPositionMs = resumeMs
    root.resolveAttempt = root.forceCombinedAudioFallback ? 1 : 0
    root.networkRetries = 0
    root.lastResolveAttemptId = ""
    root.activeResolveRequest = null
    playbackRetryTimer.stop()
    playbackTimeoutTimer.restart()
    player.stop()
    player.source = ""

    console.log("omaStream playback retry serial=" + root.requestSerial
      + " mode=" + root.mode
      + " item=" + root.currentItem.id)

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
    root.activeResolveRequest = null
    root.requestLoading = false
    root.waitingForRelayUrl = false
    root.activeTransport = ""
    root.relayBaseUrl = ""
    root.streamStartOffsetMs = 0
    root.pendingStartPositionMs = 0
    root.softSeekTargetMs = -1
    softSeekDebounceTimer.stop()
    root.resolveAttempt = 0
    root.networkRetries = 0
    root.resolveStatusHint = ""
    root.playerError = ""
    root.resolveError = ""
    root.lastResolveAttemptId = ""
    root.forceCombinedAudioFallback = false
    playbackRetryTimer.stop()
    playbackTimeoutTimer.stop()
    root.cancelFormatProcess()
    player.stop()
    player.source = ""
    root.currentItem = null
    if (resolveProcess.running) resolveProcess.running = false
    if (relayProcess.running) relayProcess.running = false
  }

  function seek(positionMs) {
    var target = Math.max(0, Math.round(positionMs))
    if (root.duration > 0)
      target = Math.min(target, root.duration)

    // Progressive / direct streams: native seek when the player allows it.
    if (root.activeTransport !== "relay" && player.seekable && player.duration > 0) {
      player.position = target
      return
    }

    // Relay MPEG-TS: debounced soft-seek via ?t=
    root.softSeekTargetMs = target
    softSeekDebounceTimer.restart()
  }

  function seekRelative(deltaMs) {
    seek(root.position + deltaMs)
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

  function bestDownloadSelector() {
    var downloads = root.currentFormats && root.currentFormats.downloadVideo
      ? root.currentFormats.downloadVideo : []
    if (downloads.length > 0 && downloads[0].downloadSelector)
      return downloads[0].downloadSelector
    return "bestvideo*+bestaudio/best"
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
      if (playbackState === MediaPlayer.PlayingState) {
        root.requestLoading = false
        playbackTimeoutTimer.stop()
        root.applyPendingNativeSeek()
      }
    }
    onMediaStatusChanged: {
      if (player.mediaStatus === MediaPlayer.LoadedMedia
          || player.mediaStatus === MediaPlayer.BufferedMedia
          || player.mediaStatus === MediaPlayer.BufferingMedia) {
        root.applyPendingNativeSeek()
      }
    }
    onSeekableChanged: root.applyPendingNativeSeek()
    onDurationChanged: root.applyPendingNativeSeek()
    onAudioTracksChanged: {
      if (player.audioTracks.length > 0 && player.activeAudioTrack === -1) {
        player.activeAudioTrack = 0
      }
    }
    onErrorOccurred: function(error, errorString) {
      var raw = String(errorString || "")
      var lower = raw.toLowerCase()
      if (lower.indexOf("403") !== -1 || lower.indexOf("forbidden") !== -1 || lower.indexOf("access denied") !== -1)
        root.playerError = "YouTube denied the media stream (HTTP 403). Retrying with a fresh URL…"
      else
        root.playerError = raw || "Media playback failed."

      var willRetry = root.currentItem && root.currentItem.sourceType === "youtube"
        && root.playbackRetries < root.maximumPlaybackRetries
      if (willRetry) playbackRetryTimer.restart()
      else {
        if (lower.indexOf("403") !== -1 || lower.indexOf("forbidden") !== -1 || lower.indexOf("access denied") !== -1)
          root.playerError = "YouTube denied the media stream. Try again, or download the video instead."
        root.requestLoading = false
      }
    }
  }

  Process {
    id: relayProcess
    command: []
    stdout: SplitParser {
      onRead: function(line) {
        var url = String(line || "").trim()
        if (url.indexOf("http://") === 0 && root.activeRequestSerial === root.requestSerial) {
          root.resolveStatusHint = ""
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
      if (root.activeRequestSerial !== root.requestSerial) return
      root.waitingForRelayUrl = false
      if (exitCode !== 0) {
        var detail = String(relayErrors.text || "").trim()
        root.resolveError = detail || "Adaptive playback relay failed."
        root.resolveStatusHint = ""
        root.requestLoading = false
        playbackTimeoutTimer.stop()
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

      var stderrText = String(resolveErrors.text || "")
      var lines = String(resolveOutput.text || "").trim().split("\n")
      var httpUrls = []
      for (var i = 0; i < lines.length; i++) {
        var url = lines[i].trim()
        if (url.indexOf("https://") === 0 || url.indexOf("http://") === 0)
          httpUrls.push(url)
      }

      if (exitCode === 0 && httpUrls.length === 1) {
        root.startPlayback(httpUrls[0])
        return
      }

      if (exitCode === 0 && httpUrls.length > 1) {
        // Adaptive pair without relay — fall through to failure handling
        root.handleResolveFailure(exitCode, "Resolver returned separate video/audio URLs.", true)
        return
      }

      root.handleResolveFailure(exitCode, stderrText, httpUrls.length > 0)
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
      if (formatProcess.targetSerial !== root.formatRequestSerial
          || formatProcess.targetId !== (root.currentItem ? root.currentItem.id : "")) return
      if (exitCode === 0 && formatOutput.text) {
        try {
          var parsed = JSON.parse(formatOutput.text)
          if (parsed && parsed.formats) {
            root.currentFormats = YoutubeProvider.normalizeFormats(parsed.formats)
          }
        } catch (e) {
        }
      }
    }
  }
}
