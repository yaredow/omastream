# omaStream

An embedded YouTube search, playback, and download plugin for the Omarchy shell.

## Current features

- Search YouTube through `yt-dlp`
- Play video or audio with QtMultimedia inside the plugin
- Shared playback state between the overlay and bar widget
- Play, pause, stop, seek, mute, volume, and fullscreen controls
- Download a selected video to `~/Downloads`

## Dependencies

- Omarchy with the Quattro shell plugin runtime
- `yt-dlp`
- `jq`
- Qt 6 Multimedia with an FFmpeg backend

## Controls

- `Space`: play or pause
- `Left` / `Right`: seek backward or forward 10 seconds
- `Up` / `Down`: change volume
- `M`: mute or unmute
- `F`: enter or leave fullscreen video
- `/`: focus search
- `Escape`: leave fullscreen, clear search focus, or close the overlay

The bar widget uses middle click for play/pause, right click to stop, and the mouse wheel for volume.

## Architecture

`PlaybackService.qml` is the single playback owner. The overlay and bar widget are clients of that service. Media is passed through a provider-neutral item contract so future YouTube downloads, torrent downloads, and torrent stream resolvers can be implemented behind the same playback API.

The current scripts are temporary process adapters. Long-running transfer queues and torrent sessions will move behind a dedicated local backend service rather than running inside the desktop shell.

## Validate

```sh
omarchy plugin validate ~/.config/omarchy/plugins/user.omastream
qmllint -I "$OMARCHY_PATH/shell" \
  ~/.config/omarchy/plugins/user.omastream/PlaybackService.qml \
  ~/.config/omarchy/plugins/user.omastream/OmaStreamOverlay.qml \
  ~/.config/omarchy/plugins/user.omastream/BarWidget.qml
```
