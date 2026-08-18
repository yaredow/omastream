.pragma library

function formatBytes(bytes) {
    if (bytes === undefined || bytes === null || isNaN(bytes) || bytes <= 0) return "0 B";
    var b = Number(bytes);
    var units = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    while (b >= 1024 && i < units.length - 1) {
        b /= 1024;
        i++;
    }
    return (i === 0 ? b.toFixed(0) : b.toFixed(1)) + " " + units[i];
}

function formatSpeed(speedBytes) {
    if (!speedBytes || isNaN(speedBytes) || speedBytes <= 0) return "0 KB/s";
    return formatBytes(speedBytes) + "/s";
}

function formatEta(seconds) {
    if (seconds === undefined || seconds === null || isNaN(seconds) || seconds < 0 || seconds === Infinity) return "--:--";
    var s = Math.round(Number(seconds));
    var hrs = Math.floor(s / 3600);
    var mins = Math.floor((s % 3600) / 60);
    var secs = s % 60;
    var secText = secs < 10 ? "0" + secs : "" + secs;
    if (hrs > 0) {
        return hrs + "h " + (mins < 10 ? "0" + mins : mins) + "m";
    }
    return mins + ":" + secText;
}

function getStatusBadge(state) {
    switch (state) {
        case "downloading":
            return { label: "Downloading", color: "#38bdf8", isProgress: true };
        case "merging":
            return { label: "Processing", color: "#f59e0b", isProgress: true };
        case "preparing":
            return { label: "Preparing", color: "#a855f7", isProgress: true };
        case "queued":
            return { label: "Queued", color: "#94a3b8", isProgress: false };
        case "completed":
            return { label: "Completed", color: "#10b981", isProgress: false };
        case "paused":
            return { label: "Paused", color: "#eab308", isProgress: false };
        case "cancelled":
            return { label: "Cancelled", color: "#64748b", isProgress: false };
        case "failed":
            return { label: "Failed", color: "#ef4444", isProgress: false };
        default:
            return { label: state || "Unknown", color: "#94a3b8", isProgress: false };
    }
}

function createJob(item, options) {
    options = options || {};
    var now = Date.now();
    var jobId = "job_" + now + "_" + Math.floor(Math.random() * 10000);
    var formatMode = options.formatMode || "video_audio"; // "video_audio", "video_only", "audio_only"
    var container = options.container || (formatMode === "audio_only" ? "mp3" : "mp4");
    var qualityLabel = options.qualityLabel || "Best";
    var destination = options.destination || "~/Downloads";

    return {
        jobId: jobId,
        sourceType: (item && item.sourceType) || "youtube",
        videoId: (item && (item.videoId || item.id)) || "",
        title: (item && item.title) || "Untitled Download",
        author: (item && item.author) || "",
        thumbnailUrl: (item && item.thumbnailUrl) || "",
        destination: destination,
        formatSummary: qualityLabel + " · " + container.toUpperCase() + (formatMode === "audio_only" ? " · Audio" : ""),
        formatMode: formatMode,
        formatId: options.formatId || "best",
        container: container,
        state: "queued", // queued, preparing, downloading, merging, completed, cancelled, failed
        percent: 0.0,
        downloadedBytes: 0,
        totalBytes: 0,
        speed: 0,
        eta: 0,
        error: "",
        outputPath: "",
        createdAt: now,
        completedAt: 0
    };
}
