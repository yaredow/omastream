.pragma library

var PROVIDERS = {
    "youtube": {
        id: "youtube",
        name: "YouTube",
        badge: "YouTube",
        icon: "\uf167", // FontAwesome youtube icon or fallback
        canSearch: true,
        canStream: true,
        canDownload: true,
        supportsQualitySelect: true,
        supportsCustomDownload: true
    },
    "torrent": {
        id: "torrent",
        name: "Torrents",
        badge: "Torrents",
        icon: "\uf019",
        canSearch: false,
        canStream: false,
        canDownload: false,
        supportsQualitySelect: false,
        supportsCustomDownload: false,
        available: false
    }
};

function getProvider(id) {
    return PROVIDERS[id] || PROVIDERS["youtube"];
}

function listAvailableProviders() {
    var list = [];
    for (var key in PROVIDERS) {
        if (PROVIDERS[key].canSearch || PROVIDERS[key].available !== false) {
            list.push(PROVIDERS[key]);
        }
    }
    return list;
}
