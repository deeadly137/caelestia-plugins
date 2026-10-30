import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Plugins
import qs.services
import qs.utils

// Wallhaven search and download. Owned by the page so its lifetime matches the page; results and
// filters come from the plugin's `settings.filters` group. An Item so it can host its Processes.
Item {
    id: root

    visible: false
    width: 0
    height: 0

    required property SettingsObject settings

    readonly property string apiBase: "https://wallhaven.cc/api/v1"

    readonly property bool hasApiKey: String(settings.apiKey ?? "").trim() !== ""
    readonly property bool wantsApiKey: (settings.filters.sketchy || settings.filters.nsfw) && !root.hasApiKey

    readonly property string categories: (settings.filters.general ? "1" : "0") + (settings.filters.anime ? "1" : "0") + (settings.filters.people ? "1" : "0")
    readonly property string purity: (settings.filters.sfw ? "1" : "0") + (settings.filters.sketchy && root.hasApiKey ? "1" : "0") + (settings.filters.nsfw && root.hasApiKey ? "1" : "0")
    readonly property string sorting: String(settings.filters.sorting ?? "relevance")
    readonly property string atleast: String(settings.filters.minimumResolution ?? "any")

    // Search state
    property bool loading: false
    property string error: ""
    property var results: []
    property int page: 0
    property int lastPage: 0
    property string seed: ""
    property string query: ""
    property bool randomSort: false
    property int requestSerial: 0

    // Download state
    property string downloadId: ""
    property string downloadError: ""
    readonly property bool downloading: root.downloadId !== ""

    property string sourceUrl: ""
    property string tmpPath: ""
    property string dstPath: ""

    signal downloaded(string path)
    signal downloadFailed(string message)

    function buildUrl(path, params): string {
        const parts = [];
        for (const key in params) {
            const value = params[key];
            if (value === undefined || value === null || value === "")
                continue;
            parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
        }
        return `${root.apiBase}${path}?${parts.join("&")}`;
    }

    function search(text, options): void {
        const q = String(text ?? "").trim();
        if (q === "")
            return;

        const opts = options ?? {};
        const append = opts.append === true && root.page > 0 && root.page < root.lastPage;
        const random = opts.random === true;
        const nextPage = append ? root.page + 1 : 1;

        const params = {
            "q": q,
            "categories": root.categories,
            "purity": root.purity,
            "sorting": random ? "random" : root.sorting,
            "page": nextPage > 1 ? String(nextPage) : ""
        };
        if (!random)
            params.order = "desc";
        if (random && append && root.seed !== "")
            params.seed = root.seed;
        if (root.atleast !== "any")
            params.atleast = root.atleast;
        if (root.hasApiKey)
            params.apikey = String(root.settings.apiKey).trim();

        const url = root.buildUrl("/search", params);
        root.query = q;
        root.randomSort = random;
        root.loading = true;
        root.error = "";

        const serial = ++root.requestSerial;
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || serial !== root.requestSerial)
                return;

            root.loading = false;
            if (xhr.status !== 200) {
                if (xhr.status === 401)
                    root.error = "Wallhaven rejected the API key";
                else if (xhr.status === 429)
                    root.error = "Wallhaven rate limit reached, try again later";
                else if (xhr.status === 0)
                    root.error = "Could not reach Wallhaven";
                else
                    root.error = `Wallhaven returned HTTP ${xhr.status}`;
                return;
            }

            let payload;
            try {
                payload = JSON.parse(xhr.responseText);
            } catch (e) {
                root.error = "Could not parse the Wallhaven response";
                return;
            }

            const items = Array.isArray(payload.data) ? payload.data : [];
            root.results = append ? root.results.concat(items) : items;
            root.page = Number(payload.meta?.current_page ?? nextPage);
            root.lastPage = Number(payload.meta?.last_page ?? 1);
            root.seed = String(payload.meta?.seed ?? "");
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function searchNext(): void {
        if (root.loading || root.page >= root.lastPage || root.query === "")
            return;
        root.search(root.query, {
            "append": true,
            "random": root.randomSort
        });
    }

    function fileExtension(wallpaper): string {
        const match = String(wallpaper?.path ?? "").match(/\.([a-zA-Z]{3,4})(?:\?|$)/);
        let ext = match ? match[1].toLowerCase() : "jpg";
        if (ext === "jpeg")
            ext = "jpg";
        return ext;
    }

    function download(wallpaper): void {
        if (!wallpaper || !wallpaper.path || root.downloading)
            return;

        const id = String(wallpaper.id ?? "");
        if (id === "") {
            root.downloadError = "This wallpaper has no id";
            root.downloadFailed(root.downloadError);
            return;
        }

        root.downloadId = id;
        root.downloadError = "";
        root.sourceUrl = String(wallpaper.path);
        root.tmpPath = `${Paths.cache}/wallhaven-${id}.part`;
        root.dstPath = `${Paths.wallsdir}/wallhaven-${id}.${root.fileExtension(wallpaper)}`;

        mkdirProc.command = ["mkdir", "-p", Paths.wallsdir];
        mkdirProc.running = true;
    }

    function failDownload(message): void {
        root.downloadId = "";
        root.downloadError = message;
        root.downloadFailed(message);
    }

    Process {
        id: mkdirProc

        onExited: code => {
            if (code !== 0) {
                root.failDownload("Could not create the wallpaper folder");
                return;
            }
            curlProc.command = ["curl", "-fsSL", "--max-time", "300", "-o", root.tmpPath, root.sourceUrl];
            curlProc.running = true;
        }
    }

    Process {
        id: curlProc

        onExited: code => {
            if (code !== 0) {
                root.failDownload("Download failed (curl exit " + code + ")");
                return;
            }
            moveProc.command = ["mv", root.tmpPath, root.dstPath];
            moveProc.running = true;
        }
    }

    Process {
        id: moveProc

        onExited: code => {
            if (code !== 0) {
                root.failDownload("Could not move the downloaded file");
                return;
            }
            const path = root.dstPath;
            root.downloadId = "";
            Wallpapers.setWallpaper(path);
            root.downloaded(path);
        }
    }
}
