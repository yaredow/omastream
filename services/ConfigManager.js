.pragma library

// ConfigManager module handling local settings persistence (~/.config/omastream/config.json)

var defaultInstances = [
    "https://inv.tux.pizza",
    "https://invidious.nerdvpn.de",
    "https://invidious.privacydev.net"
];

function getDefaultConfig() {
    return {
        activeInstanceUrl: "https://inv.tux.pizza",
        customInstances: [],
        defaultInstances: defaultInstances
    };
}
