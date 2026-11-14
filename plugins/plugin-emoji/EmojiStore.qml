// Shared emoji list, usage counts and favourites for the launcher providers. The list comes from
// the Caelestia CLI (`caelestia emoji`), with a file fallback so an older install still works.
// Favourites and frequencies live in the plugin's state directory rather than `plugins.json`,
// because an array or map setting would render as an editable text row on the settings page.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils

QtObject {
    id: root

    readonly property string owner: "deeadly137/emoji"
    readonly property string stateDir: `${Paths.state}/emoji`
    readonly property string statePath: `${root.stateDir}/state.json`

    property int revision: 0
    property var items: []
    property bool loaded: false

    property var favourites: []
    property var frequencies: ({})
    property bool stateLoaded: false

    // Favourites first, then most used, then the order of the source file.
    readonly property var sortedItems: {
        void root.revision;

        const favSet = new Set(root.favourites);
        const freq = root.frequencies;
        return [...root.items].sort((a, b) => {
            const aFav = favSet.has(a.char);
            const bFav = favSet.has(b.char);
            if (aFav !== bFav)
                return aFav ? -1 : 1;

            const aFreq = freq[a.char] || 0;
            const bFreq = freq[b.char] || 0;
            if (aFreq !== bFreq)
                return bFreq - aFreq;

            return a.index - b.index;
        });
    }

    readonly property Process reader: Process {
        running: false
        command: ["sh", "-c", "caelestia emoji 2>/dev/null || cat /usr/lib/caelestia/data/emojis.txt 2>/dev/null || cat /usr/lib/python3*/site-packages/caelestia/data/emojis.txt 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.items = root.parse(text);
                root.loaded = true;
                root.revision++;
            }
        }
    }

    readonly property FileView stateFile: FileView {
        path: root.statePath
        printErrors: false

        onLoaded: root.applyState(text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                console.warn("[emoji] failed to load", root.statePath, error);
            root.stateLoaded = true;
        }
    }

    // `<char> <label and tags>` per line. The char is the first whitespace-delimited token, which
    // is how the CLI's own picker reads the file too.
    function parse(output: string): var {
        const result = [];
        const lines = String(output ?? "").split("\n");

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (!line)
                continue;

            const space = line.indexOf(" ");
            if (space <= 0)
                continue;

            const char = line.slice(0, space);
            const name = line.slice(space + 1).trim();
            if (char.length === 0 || name.length === 0)
                continue;

            result.push({
                char: char,
                name: name,
                index: result.length
            });
        }

        return result;
    }

    function applyState(raw: string): void {
        try {
            const data = JSON.parse(raw);
            root.favourites = Array.isArray(data.favourites) ? data.favourites.map(String) : [];
            root.frequencies = data.frequencies && typeof data.frequencies === "object" ? data.frequencies : ({});
        } catch (e) {
            root.favourites = [];
            root.frequencies = ({});
        }
        root.stateLoaded = true;
        root.revision++;
    }

    function saveState(): void {
        root.stateFile.setText(JSON.stringify({
            favourites: root.favourites,
            frequencies: root.frequencies
        }));
    }

    function recordUsage(char: string): void {
        if (!root.stateLoaded)
            return;

        const next = Object.assign({}, root.frequencies);
        next[char] = (next[char] || 0) + 1;
        root.frequencies = next;
        root.revision++;
        root.saveState();
    }

    function toggleFavourite(char: string): void {
        if (!root.stateLoaded)
            return;

        const list = [...root.favourites];
        const index = list.indexOf(char);
        if (index >= 0)
            list.splice(index, 1);
        else
            list.push(char);
        root.favourites = list;
        root.revision++;
        root.saveState();
    }

    function onUnload(): void {
        Hooks.clearValue("emoji.store", "deeadly137/emoji");
    }

    Component.onCompleted: {
        Hooks.setValue("emoji.store", root.owner, root);
        Quickshell.execDetached(["mkdir", "-p", root.stateDir]);
        root.reader.running = true;
    }
}
