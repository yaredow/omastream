.pragma library

function normalizeFormats(rawFormats) {
    if (!Array.isArray(rawFormats)) return { streamable: [], downloadVideo: [], downloadAudio: [] };

    var streamable = [
        {
            id: "auto",
            label: "Auto (Recommended)",
            detail: "Best direct stream",
            resolution: "Auto",
            height: 0,
            hasVideo: true,
            hasAudio: true,
            isDirectStreamable: true
        }
    ];

    var downloadResolutions = {};
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

        // Progressive streamable (both video and audio, direct HTTP or m3u8)
        if (hasVideo && hasAudio && height > 0) {
            var resLabel = height + "p";
            streamable.push({
                id: String(f.format_id),
                label: resLabel + " (" + ext.toUpperCase() + ")",
                detail: (f.vcodec ? f.vcodec.split(".")[0] : "") + " · " + (fps > 30 ? fps + "fps" : "Standard"),
                resolution: resLabel,
                height: height,
                fps: fps,
                ext: ext,
                hasVideo: true,
                hasAudio: true,
                isDirectStreamable: true,
                filesize: filesize
            });
        }

        // Available video resolutions for downloading (even if video-only stream that ffmpeg will merge)
        if (hasVideo && height >= 144) {
            var key = height + "p";
            if (!downloadResolutions[key] || (height >= (downloadResolutions[key].height || 0) && (f.tbr || 0) > (downloadResolutions[key].tbr || 0))) {
                downloadResolutions[key] = {
                    id: String(f.format_id),
                    height: height,
                    width: width,
                    fps: fps,
                    resolution: key,
                    label: key + (fps > 30 ? " (" + fps + "fps)" : ""),
                    detail: (f.vcodec ? f.vcodec.split(".")[0] : ext.toUpperCase()),
                    filesize: filesize,
                    tbr: f.tbr || 0,
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
                    label: ext.toUpperCase() + (abr > 0 ? " ~" + abr + " kbps" : " High Quality"),
                    detail: acodec !== "none" ? acodec.split(".")[0] : "Audio",
                    filesize: filesize
                };
            }
        }
    }

    // Sort streamable by height descending (keep auto first)
    var sortedStreamable = [streamable[0]].concat(
        streamable.slice(1).sort(function(a, b) { return b.height - a.height; })
    );

    // Filter unique streamable heights
    var uniqueStreamable = [];
    var seenHeights = {};
    for (var j = 0; j < sortedStreamable.length; j++) {
        var sItem = sortedStreamable[j];
        if (sItem.id === "auto" || !seenHeights[sItem.height]) {
            uniqueStreamable.push(sItem);
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
        streamable: uniqueStreamable,
        downloadVideo: downloadVideo,
        downloadAudio: downloadAudio
    };
}
