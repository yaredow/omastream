# omaStream UI improvements

This document is the implementation plan for making omaStream feel like a dependable Omarchy media application while preserving the current YouTube playback path.

## 1. Current assessment

### What already works

- `PlaybackService.qml` is correctly the single owner of the long-lived `MediaPlayer`.
- `OmaStreamOverlay.qml` already provides a useful master/detail layout, inline playback, fullscreen playback, keyboard controls, thumbnails, and basic metadata.
- Media items already contain a `sourceType` and `providerData`, which is a good starting point for YouTube and future torrent adapters.
- The plugin follows the Omarchy Quattro plugin contract and currently passes `omarchy plugin validate` and `qmllint`.

### What prevents a download-quality release

- Search always returns 12 results and has no visible filter or sort controls.
- The result model has insufficient metadata for trustworthy sorting: publication date is empty, descriptions are only flat-search metadata, and live/unavailable/private states are not presented clearly.
- Playback always resolves `best[protocol^=http]/best` or `bestaudio`; users cannot inspect or select a quality.
- Downloads are launched with `nohup` and their output is discarded. The UI cannot show progress, speed, ETA, destination, failure details, cancellation, or history.
- The download button starts an implicit default format and does not expose video-only, audio-only, container, codec, resolution, or file-size choices.
- The overlay is currently YouTube-centric even though the media contract hints at future providers.
- Search, playback resolution, and downloading are all direct process adapters. This is acceptable for a prototype, but transfer queues and torrent sessions need an owner that survives overlay close and can emit structured state.
- QtMultimedia is not a general DASH compositor. YouTube formats above many progressive options are commonly separate video and audio streams, so exposing every adaptive format as an online playback choice would create unreliable playback.

### Decisions from this assessment

- **Online playback:** default to a compatible progressive/combined HTTP format, or an explicitly supported direct stream. Advertise adaptive-only high-resolution formats as download choices unless a tested local remux path is available.
- **Downloads:** use yt-dlp plus ffmpeg for adaptive video/audio selection, merging, and container conversion. Downloads can therefore support higher resolutions and more formats than direct playback.
- **UI structure:** split the current 43 KB overlay during the first implementation phase. Shared state stays in services; views and reusable controls become separate QML files.
- **Process ownership:** every helper must support cancellation and process-group cleanup. QML cancellation alone is not a sufficient guarantee that yt-dlp, jq, ffmpeg, or a child process has exited.

## 2. Recommended information architecture

Use one application surface with a small top-level mode switch. Keep the player persistent at the bottom or in a compact now-playing bar, regardless of the active mode.

### Primary modes

1. **Discover**
   - Search field with explicit source selector: `YouTube` now, `Torrents` later, `All sources` when both are available.
   - Search results with thumbnails, duration, source badge, live badge, author, views, and publication date.
   - Filter and sort controls directly above the result list.
   - Selecting an item updates the detail pane; clicking play starts playback.

2. **Player**
   - Current media, source/provider badge, quality indicator, playback controls, seek bar, volume, playback speed, and fullscreen.
   - A quality menu that displays the active format and available alternatives.
   - Clear states for resolving, buffering, playing, paused, ended, and failed.

3. **Downloads**
   - Queue and history in one view.
   - Each row shows source, title, selected format, destination, state, progress, downloaded/total size, speed, ETA, and actions.
   - Actions: pause/resume, cancel, retry, reveal in file manager, remove from history.
   - Separate `Add download` flow from the detail pane, so downloading never depends on an opaque default.

Do not create separate YouTube and torrent UIs. Use source badges and provider-specific options inside the shared modes. This keeps the user’s mental model stable as new providers arrive.

## 3. Search, filtering, and sorting

### UI controls

Add a compact toolbar above `ListView`:

- Result count.
- Sort menu: relevance, newest, oldest, most views, shortest, longest.
- Filter menu or chips: all, videos, live, short duration, medium duration, long duration.
- Optional minimum/maximum duration controls in an advanced popover.
- A clear-filters action that is icon-only with a tooltip.
- Loading, no results, and error states that include a retry action.

Use `ComboBox`/menu controls for mutually exclusive sort choices and checkboxes or toggles for independent filters. Keep controls keyboard accessible and make the selected state obvious using the existing `Color` and `Style` APIs.

### Data changes

Update `scripts/omastream-search` and `services/MediaModel.js` to return normalized fields:

```text
id, sourceType, mediaType, title, author, authorId,
durationSeconds, durationText, viewCount, viewCountText,
uploadDate, publishedText, liveNow, availability,
thumbnailUrl, description, providerData
```

Request enough search results for local sorting, such as 30 to 50, but keep the initial request bounded. Do not pretend that local sorting is globally accurate for relevance or newest unless the provider supplies the data.

Implement filtering and sorting in a pure model/helper function, not in delegate code. Preserve the original selected media ID when the filtered list changes; if it disappears, select the first visible item or clear selection. Add tests for empty values, live videos, missing dates, missing view counts, ties, and invalid durations.

### Search process behavior

- Keep stderr separate from JSON stdout.
- Return a nonzero exit code and an actionable error when `yt-dlp` or `jq` is unavailable.
- Add an explicit process cancellation path when a new search starts or the overlay closes.
- Avoid interpolating user input into a shell command. Pass it as a process argument, as the current script does.
- Consider moving from `jq -s` to a small JSON-producing adapter only if it makes error reporting and schema validation easier; do not add a backend solely for stylistic reasons.
- The search helper should run as its own process group where possible. On cancellation, send `SIGTERM`, wait briefly, then use `SIGKILL` for the process group if it remains alive. Verify that no child `yt-dlp`/`jq` processes remain.
- Revoke or ignore stale results using a request serial, so a slower older query cannot overwrite a newer query.

## 4. Quality selection for playback

The current `PlaybackService.qml` chooses one hard-coded format. Replace that with a two-step flow:

1. Resolve available formats for the selected item.
2. Let the user choose a normalized format, then resolve and play that format.

### Format discovery

Add a provider operation, initially backed by `yt-dlp`, that returns JSON rather than human-readable `-F` output. Use fields such as:

```text
formatId, extension, videoCodec, audioCodec, width, height,
fps, bitrate, filesize, hasVideo, hasAudio, protocol
```

For direct online streaming, expose a small set of formats that QtMultimedia can consume reliably:

- `Auto` / recommended combined stream.
- Progressive combined formats by resolution, container, and codec where available.
- Audio-only direct streams when the player is in audio mode.
- Adaptive-only entries can appear under an `Advanced` section, but must be labeled `download/merge required` unless the plugin has a tested local remux implementation.

High-resolution adaptive formats should be fully available in the download flow. yt-dlp can select separate video and audio streams and ffmpeg can merge them into the requested output container. This gives users a truthful quality choice without promising that QtMultimedia can combine two remote sources itself.

### Quality menu

Place a quality button in the player controls and detail pane:

- `Auto` / recommended.
- Resolution labels such as `2160p`, `1080p`, `720p`, `480p`.
- Codec and container as secondary text.
- Audio-only choices such as `Opus`, `M4A`, or `MP3` only when actually available.
- File size or estimated bandwidth where provided.
- A check mark for the active selection.
- A disabled/loading state while formats are being discovered.

Do not label a format merely `1080p` if it has no audio. Show `1080p video only` or hide it from the simple menu and expose it under advanced formats.

Extend `playMedia(item, options)` with a provider-neutral `formatSelection` or `formatId` option. The service should own the selected format and expose it to the UI. If a selected format fails, offer retry and `Auto`; do not silently change quality without an indicator.

## 5. Real downloader experience

The current `scripts/omastream-download` must stop detaching with `nohup` and discarding output. A download needs a durable job identity and structured progress.

### Backend contract

For the first release, a dedicated helper process can be enough. It should:

- Accept a JSON job description through arguments or stdin.
- Run `yt-dlp` with a controlled argument list.
- Emit newline-delimited JSON events on stdout, for example:

```json
{"type":"started","jobId":"...","title":"..."}
{"type":"progress","jobId":"...","percent":42.5,"downloadedBytes":123,"totalBytes":456,"speed":789,"eta":12}
{"type":"status","jobId":"...","state":"merging"}
{"type":"completed","jobId":"...","path":"/home/user/Downloads/file.mp4"}
{"type":"failed","jobId":"...","error":"..."}
```

- Use `--newline --progress-template` or an equivalent stable machine-readable strategy.
- Preserve stderr for diagnostics, but never mix diagnostic text into the JSON event stream.
- Support cancellation by tracking the child process and forwarding termination. Start the helper in its own process group, terminate the group gracefully, wait with a timeout, and then kill the group if required.
- Ensure the helper itself cleans up its child process tree when it receives `SIGTERM`; do not rely only on the QML `Process` object becoming inactive.
- Use safe output templates and destination validation. Do not allow arbitrary shell syntax in a format or path.
- Never require elevated privileges.

A single helper can support one job initially. Before adding concurrent jobs, add a `DownloadService.qml` or a small user-owned local backend that owns the queue and persists state. Because the overlay can close while downloads continue, this state must belong to a keep-loaded service or a process supervised outside the overlay.

### Process lifecycle and shell reloads

- Track every search, format-inspection, playback-resolution, and download process by request/job ID.
- Cancel superseded work when a new query or format request starts.
- On overlay close, cancel only transient discovery/resolution work; do not cancel queued downloads.
- On service destruction or shell reload, terminate owned transient process groups and write a recoverable job state for active downloads.
- Prefer a dedicated helper/daemon for long-lived transfers so shell reload behavior is deterministic. At minimum, the helper must emit a terminal `cancelled` or `failed` event and remove temporary files when interrupted.

### Download row states

Model explicit states: queued, preparing, downloading, merging, paused, completed, cancelled, failed. Never infer them only from whether `Process.running` is true.

Display:

- Progress bar with determinate and indeterminate modes.
- Percent, downloaded/total bytes, speed, and ETA when known.
- Format summary, for example `MP4 · 1080p · H.264 + AAC`.
- Pause/resume and cancel buttons with tooltips.
- Retry and error details after failure.
- Completion path and an action to open the destination.

Keep completed history bounded and persist it in a simple versioned JSON file under the user config/data directory. Do not persist secrets or raw URLs unnecessarily.

## 6. Download format flow

Replace the current one-click default with two deliberate paths:

### Quick download

A primary action uses the user’s saved default, initially `best video + best audio` in a compatible container. The button must show the chosen default in a tooltip or adjacent compact label and provide a settings action to change it.

### Custom download

Open a format sheet for the selected item:

- Video + audio, video-only, audio-only.
- Container: MP4, MKV, WebM, or provider-supported alternatives.
- Resolution and codec.
- Audio format and quality for audio-only downloads.
- Destination directory.
- Playlist/range controls only when playlist support is intentionally added.

Build the command from a validated internal format object. Do not accept arbitrary yt-dlp format expressions from a text field in the normal UI. An advanced mode can expose expert expressions later, with a warning and validation.

Before queuing, show the selected format and an estimated size when available. Make post-processing requirements visible, including the need for `ffmpeg` when merging or converting.

## 7. Provider-neutral architecture for torrents

Keep providers behind small contracts instead of adding `if torrent` branches throughout QML.

### Media provider contract

Define operations conceptually as:

```text
search(query, options) -> media items
getDetails(item) -> normalized item
getStreamOptions(item) -> stream options
resolveStream(item, selection) -> playable source
```

YouTube implements these operations with `yt-dlp`. A torrent provider can later return magnet metadata, files, trackers, and streamable file choices through the same normalized media item shape.

### Download provider contract

Use a separate contract because downloading has different lifecycle concerns:

```text
inspect(item) -> downloadable options
queue(item, selection, destination) -> job
pause(jobId), resume(jobId), cancel(jobId)
observe(jobId) -> progress events
```

Do not force torrent jobs into yt-dlp. A torrent adapter should own its client/session, piece progress, peers, seeding state, and file selection, while exposing the shared download job states used by the UI.

### Suggested file boundaries

```text
services/
  PlaybackService.qml       # playback state and commands
  DownloadService.qml       # queue, progress, persistence, lifecycle
  ProviderRegistry.js       # provider discovery and capabilities
  MediaModel.js             # normalization, filtering, sorting
  DownloadModel.js          # job normalization and display helpers
providers/
  YoutubeProvider.js        # yt-dlp adapter contract
  TorrentProvider.js        # future adapter boundary, initially absent
views/
  DiscoverView.qml          # search, filters, sorting, result list
  PlayerView.qml            # player surface and controls
  DownloadsView.qml         # queue and history
components/
  QualityMenu.qml           # shared playback/download format chooser
  DownloadRow.qml           # progress and job actions
scripts/
  omastream-search
  omastream-formats
  omastream-download        # structured event adapter, no nohup
```

Split `OmaStreamOverlay.qml` after the shared service/model contracts are established, not after all features have been added. The overlay should own navigation, service injection, and global keyboard routing; each view should own only its local presentation and actions. This keeps the refactor reviewable and prevents one large file from becoming the integration point for every future provider.

The exact split can be adjusted during implementation, but the overlay should call service/provider APIs and not construct yt-dlp commands itself.

### Torrent engine boundary

Do not bind a full torrent client deeply into QML. Use a small external adapter or daemon that emits the same NDJSON job events as the yt-dlp helper. Depending on the chosen feature set, candidates include `transmission-remote`/Transmission RPC, `aria2c`, or another user-owned torrent engine. Select the engine only after checking package availability, RPC authentication, file selection, streaming support, seeding controls, and storage behavior on Omarchy.

The QML layer should know about normalized torrent capabilities such as `streamable`, `fileSelection`, `peerCount`, `pieceProgress`, and `seeding`; it should not manage torrent sockets or piece state itself.

## 8. Omarchy and Quattro implementation guidance

Follow the development guide at <https://omarchyplugins.com/develop.html>:

- Keep the plugin in the user-owned `~/.config/omarchy/plugins/user.omastream/` directory.
- Preserve the existing manifest entry points and `keepLoaded: true` while the service owns playback/download lifecycle.
- Reuse `qs.Ui` components, `Style`, `Color`, `Border`, `PanelWindow`, and the existing keyboard focus pattern.
- Preserve the current overlay contract and keep one owner for shared state.
- Split `OmaStreamOverlay.qml` during Phase 1 into `views/DiscoverView.qml`, `views/PlayerView.qml`, `views/DownloadsView.qml`, and shared components such as `components/QualityMenu.qml`. Do this after introducing the service/model interfaces, so the split follows stable ownership boundaries rather than merely moving code around.
- Keep process supervision explicit. QML `Process` objects are adapters; long-lived transfers should be owned by `DownloadService` and preferably a helper/daemon with process-group cleanup.
- Validate after each structural change:

```sh
omarchy plugin validate ~/.config/omarchy/plugins/user.omastream
qmllint -I "$OMARCHY_PATH/shell" \
  ~/.config/omarchy/plugins/user.omastream/PlaybackService.qml \
  ~/.config/omarchy/plugins/user.omastream/OmaStreamOverlay.qml \
  ~/.config/omarchy/plugins/user.omastream/BarWidget.qml
```

- Test shell summon/hide, reload, disable/re-enable, close while playing, and shell restart. A plugin runs unsandboxed in the long-lived shell process, so every external command and dependency needs careful review.

## 9. Delivery sequence

### Phase 0: baseline and contracts

- Keep the current playback behavior unchanged.
- Add normalized media, stream-format, provider, and download-job schemas.
- Decide and document the progressive-stream policy for online playback versus adaptive merging for downloads.
- Add pure model tests and document dependency checks for `yt-dlp`, `jq`, and `ffmpeg`.

### Phase 1: search usability and component split

- Increase bounded result count.
- Add metadata normalization, filter state, sort state, toolbar controls, retry, and selection preservation.
- Add keyboard navigation through results and controls.
- Split the overlay into Discover, Player, Downloads, and reusable quality/download components while the shared state contract is still small.

### Phase 2: quality selection

- Add format discovery for the selected YouTube video.
- Separate `streamable combined` formats from `download/merge required` adaptive formats.
- Add a quality menu and active-quality state.
- Pass a validated format selection through `PlaybackService`.
- Test combined, adaptive-only, video-only, audio-only, live, unavailable, and format-discovery failure cases.

### Phase 3: downloads

- Replace detached download script with structured events and process-group cleanup.
- Add `DownloadService` and a visible Downloads mode.
- Implement progress, speed, ETA, cancellation, retry, completion path, and persisted history.
- Add custom format selection, adaptive merging through ffmpeg, and default-download preferences.

### Phase 4: provider boundary and torrents

- Move YouTube logic behind the provider contract.
- Add capability-based UI so unsupported actions are hidden or disabled with a reason.
- Select and integrate a lightweight external torrent helper/daemon through the DownloadService contract.
- Implement torrent streaming only after validating the engine’s stream resolution, file selection, lifecycle, and seeding behavior.
- Reuse the player and download queue UI through adapters rather than duplicating screens.

## 10. Release quality checklist

- Search can filter and sort without losing selection unexpectedly.
- Every visible quality label accurately describes video/audio capability.
- Downloads remain observable after the overlay closes.
- Progress is based on machine-readable events, not guessed timers.
- Users can cancel and retry jobs.
- Failures explain whether the issue is missing dependency, unavailable format, network, permissions, or post-processing.
- No external command receives unsanitized shell syntax.
- YouTube playback still works with `Auto` after format discovery fails.
- UI remains usable at smaller panel sizes and with long titles, channel names, paths, and errors.
- `omarchy plugin validate` and `qmllint` pass, and the README documents dependencies, data paths, controls, and privacy/security behavior.

## Recommended first implementation slice

Start with Phase 0, then implement the search model and component split in Phase 1. Before adding visual polish, establish `DownloadService` ownership and the structured helper lifecycle. The most important user-facing improvement is not another card style: it is making the app’s state truthful. Once search state, selected format, and download state are explicit, the quality menu, progress rows, and future torrent provider can be added without rewriting the player again.
