pragma Singleton

import QtQuick
import Quickshell

// Fetches the public plugin index from CLST-plugin-list. The browser is read-only; installing a
// plugin is a separate operation.
Singleton {
    id: root

    readonly property string indexUrl: "https://raw.githubusercontent.com/deeadly137/CLST-plugin-list/main/plugins.json"

    property bool loading: false
    property string error
    property list<var> plugins: []

    function reload(): void {
        loading = true;
        error = "";

        const xhr = new XMLHttpRequest();
        xhr.timeout = 15000;

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;

            loading = false;

            if (xhr.status !== 200) {
                error = xhr.statusText || qsTr("HTTP %1").arg(xhr.status);
                return;
            }

            try {
                const payload = JSON.parse(xhr.responseText);
                if (!payload || !Array.isArray(payload.plugins))
                    throw new Error("Invalid plugin index");

                plugins = payload.plugins.filter(plugin => plugin && plugin.id && plugin.name && plugin.author);
            } catch (e) {
                error = e.message || qsTr("Invalid plugin index");
                console.warn("[PluginList]", error);
            }
        };

        xhr.ontimeout = function () {
            loading = false;
            error = qsTr("Request timed out");
        };

        xhr.onerror = function () {
            loading = false;
            error = qsTr("Network error");
        };

        xhr.open("GET", indexUrl + "?t=" + Date.now());
        xhr.send();
    }

    Component.onCompleted: reload()
}
