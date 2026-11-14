// Shared clipboard history for the launcher providers. One `cliphist list` fills it and both the
// copy and the favourite provider read the same cached array, so opening the launcher twice does
// not spawn two listing processes. Favourites live next to the plugin's other state rather than in
// `plugins.json`, because an array would show up as a text row on the generated settings page.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils

QtObject {
    id: root

    readonly property string owner: "deeadly137/clipboard"
    readonly property string stateDir: `${Paths.state}/clipboard`
    readonly property string favouritesPath: `${root.stateDir}/favourites.json`

    // Bumped when a listing lands, so provider bindings that read `items` re-evaluate.
    property int revision: 0
    property var items: []
    property bool loaded: false
    property bool loading: false

    property var favouriteClips: []
    property bool favouritesLoaded: false

    readonly property Process lister: Process {
        running: false
        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.items = root.parse(text);
                root.loaded = true;
                root.loading = false;
                root.revision++;
            }
        }

        // A missing `cliphist` never produces stdout. Mark the attempt finished so the providers
        // do not retry on every keystroke.
        onExited: {
            if (!root.loading)
                return;
            root.loaded = true;
            root.loading = false;
            root.revision++;
        }
    }

    readonly property FileView favouritesFile: FileView {
        path: root.favouritesPath
        printErrors: false

        onLoaded: root.applyFavourites(text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                console.warn("[clipboard] failed to load", root.favouritesPath, error);
            root.favouritesLoaded = true;
        }
    }

    function refresh(force: bool): void {
        if (root.loading)
            return;
        if (root.loaded && !force)
            return;
        root.loading = true;
        root.lister.running = true;
    }

    // `cliphist list` writes `<id>\t<preview>` per line. Binary entries keep their
    // `[[ binary data ... ]]` placeholder, which is what the row shows instead of decoding.
    function parse(output: string): var {
        const result = [];
        const lines = String(output ?? "").split("\n");

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (!line)
                continue;

            const tab = line.indexOf("\t");
            if (tab <= 0)
                continue;

            const id = parseInt(line.slice(0, tab), 10);
            const preview = line.slice(tab + 1).trim();
            if (!Number.isFinite(id) || preview.length === 0)
                continue;

            result.push({
                id: id,
                preview: preview,
                isImage: preview.startsWith("[[ binary data ")
            });
        }

        return result;
    }

    function applyFavourites(raw: string): void {
        try {
            const data = JSON.parse(raw);
            root.favouriteClips = Array.isArray(data) ? data.map(String) : [];
        } catch (e) {
            root.favouriteClips = [];
        }
        root.favouritesLoaded = true;
    }

    function toggleFavourite(id: var): void {
        // Do not overwrite a list that has not been read yet; the store loads at shell start.
        if (!root.favouritesLoaded)
            return;

        const key = String(id);
        const list = [...root.favouriteClips];
        const index = list.indexOf(key);
        if (index >= 0)
            list.splice(index, 1);
        else
            list.push(key);
        root.favouriteClips = list;
        root.favouritesFile.setText(JSON.stringify(list));
    }

    function onUnload(): void {
        Hooks.clearValue("clipboard.store", "deeadly137/clipboard");
    }

    Component.onCompleted: {
        Hooks.setValue("clipboard.store", root.owner, root);
        Quickshell.execDetached(["mkdir", "-p", root.stateDir]);
    }
}
