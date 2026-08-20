.pragma library

function normalizeFormats(rawFormats) {
    if (!Array.isArray(rawFormats)) return { playback: [], downloadVideo: [], downloadAudio: [] };

    var playback = [
        {
            id: "auto",
            label: "Auto",
            detail: "Best direct stream",
            resolution: "Auto",
            height: 0,
            hasVideo: true,
            hasAudio: true,
            isDirectStreamable: true
        }
    ];

    var downloadResolutions = {};
    var adaptivePlayback = {};
    var audioMap = {};

    for (var i = 0; i < rawFormats.length; i++) {
        var f = rawFormats[i];
        if (!f || !f.format_id) continue;

        var vcodec = f.vcodec || "none";
        var acodec = f.acodec || "none";
        var hasVideo = vcodec !== "none";
        var hasAudio = acodec !== "none";
        var height = Number(f.height) || 0;
        var width = Number(f.width) || 0;
        var ext = f.ext || "mp4";
        var proto = f.protocol || "";
        var fps = f.fps || 30;
        var filesize = f.filesize || f.filesize_approx || 0;

        // Progressive playback (both video and audio natively interleaved)
        // This is safe for simple Qt MediaPlayer without a local relay.
        if (hasVideo && hasAudio && height > 0 && proto !== "m3u8_native" && proto.indexOf("m3u8") === -1) {
            var resLabel = (f.format_note && f.format_note.indexOf("p") !== -1) ? f.format_note : height + "p";
            playback.push({
                id: String(f.format_id),
                label: resLabel,
                detail: "Progressive",
                resolution: resLabel,
                height: height,
                fps: fps,
                ext: ext,
                hasVideo: true,
                hasAudio: true,
                isDirectStreamable: true,
                transport: "direct",
                filesize: filesize
            });
        } else if (hasVideo && height > 0) {
            // HLS or DASH Video streams requiring proxy multiplexing for stability
            // MUST be H.264 (avc) because ffmpeg -c copy -f mpegts does not support VP9/AV1
            if (vcodec.indexOf("avc") !== -1 || vcodec.indexOf("h264") !== -1) {
                var resLabel = (f.format_note && f.format_note.indexOf("p") !== -1) ? f.format_note : height + "p";
                // Only overwrite if we don't have one, or if this one has higher framerate
                if (!adaptivePlayback[height] || (f.tbr || 0) > adaptivePlayback[height].tbr) {
                    adaptivePlayback[height] = {
                        id: String(f.format_id),
                        height: height,
                        label: resLabel,
                        detail: "High Quality (Relay)",
                        resolution: resLabel,
                        hasVideo: true,
                        hasAudio: true,
                        isDirectStreamable: false,
                        transport: "relay",
                        tbr: f.tbr || 0,
                        playbackSelector: f.format_id + "+bestaudio[ext=m4a]/bestaudio[ext=m4a]"
                    };
                }
            }
        }

        // Available video resolutions for downloading (even if video-only stream that ffmpeg will merge)
        if (hasVideo && height >= 144) {
            var resKey = (f.format_note && f.format_note.indexOf("p") !== -1) ? f.format_note : height + "p";
            var key = resKey;
            var qualityTag = "";
            if (resKey.indexOf("2160p") !== -1 || height >= 2160) qualityTag = " (4K)";
            else if (resKey.indexOf("1440p") !== -1 || height >= 1440) qualityTag = " (2K)";
            else if (resKey.indexOf("1080p") !== -1 || height >= 1080) qualityTag = " (Full HD)";
            else if (resKey.indexOf("720p") !== -1 || height >= 720) qualityTag = " (HD)";

            if (!downloadResolutions[key] || (height >= (downloadResolutions[key].height || 0) && (f.tbr || 0) > (downloadResolutions[key].tbr || 0))) {
                downloadResolutions[key] = {
                    id: String(f.format_id),
                    height: height,
                    width: width,
                    fps: fps,
                    resolution: key,
                    label: key + qualityTag,
                    detail: (f.vcodec ? f.vcodec.split(".")[0] : ext.toUpperCase()) + " \u00B7 High Definition",
                    filesize: filesize,
                    tbr: f.tbr || 0,
                    downloadSelector: hasAudio ? String(f.format_id) : String(f.format_id) + "+bestaudio",
                    hasAudio: hasAudio
                };
            }
        }

        // Audio-only formats
        if (!hasVideo && hasAudio) {
            var abr = Math.round(Number(f.abr) || Number(f.tbr) || 0);
            var akey = ext + "_" + (abr > 0 ? abr : "best");
            if (!audioMap[akey]) {
                audioMap[akey] = {
                    id: String(f.format_id),
                    ext: ext,
                    abr: abr,
                    label: ext.toUpperCase() + (abr > 0 ? " (" + abr + " kbps)" : ""),
                    detail: acodec !== "none" ? acodec.split(".")[0] : "Audio",
                    filesize: filesize
                };
            }
        }
    }

    for (var adaptiveHeight in adaptivePlayback) {
        var adaptive = adaptivePlayback[adaptiveHeight];
        playback.push({
            id: "relay-" + adaptive.id,
            label: adaptive.height + "p",
            detail: "High Quality (Relay)",
            resolution: adaptive.height + "p",
            height: adaptive.height,
            hasVideo: true,
            hasAudio: true,
            isDirectStreamable: false,
            transport: "relay",
            playbackSelector: adaptive.id + "+bestaudio/best"
        });
    }

    // Sort playback by height descending (keep auto first)
    var sortedPlayback = [playback[0]].concat(
        playback.slice(1).sort(function(a, b) { return b.height - a.height; })
    );

    // Filter unique playback heights
    var uniquePlayback = [];
    var seenHeights = {};
    for (var j = 0; j < sortedPlayback.length; j++) {
        var sItem = sortedPlayback[j];
        if (sItem.id === "auto" || !seenHeights[sItem.height]) {
            uniquePlayback.push(sItem);
            if (sItem.height) seenHeights[sItem.height] = true;
        }
    }

    // Sort download resolutions descending
    var downloadVideo = [];
    for (var rKey in downloadResolutions) {
        downloadVideo.push(downloadResolutions[rKey]);
    }
    downloadVideo.sort(function(a, b) { return b.height - a.height; });

    // Download audio list
    var downloadAudio = [];
    for (var aKey in audioMap) {
        downloadAudio.push(audioMap[aKey]);
    }
    downloadAudio.sort(function(a, b) { return b.abr - a.abr; });

    return {
        playback: uniquePlayback,
        downloadVideo: downloadVideo,
        downloadAudio: downloadAudio
    };
}
