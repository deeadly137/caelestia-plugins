pragma Singleton

import QtQuick
import Quickshell

// Fetches the public plugin index. The index lives in the shell repository (`plugins/index.json`)
// and only names repositories and subdirectories; the manifest in each plugin directory supplies
// the display metadata, so adding or changing a plugin does not require a shell release.
Singleton {
    id: root

    readonly property string indexUrl: "https://raw.githubusercontent.com/deeadly137/caelestia-plugins/main/plugins/index.json"

    property bool loading: false
    property string error
    property var plugins: []
    property int _pending: 0
    property int _generation: 0

    function reload(): void {
        _generation++;
        const generation = _generation;

        loading = true;
        error = "";
        _pending = 0;
        plugins = [];

        const xhr = new XMLHttpRequest();
        xhr.timeout = 15000;

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (generation !== root._generation)
                return;

            if (xhr.status !== 200) {
                loading = false;
                error = xhr.statusText || qsTr("HTTP %1").arg(xhr.status);
                return;
            }

            let entries;
            try {
                const payload = JSON.parse(xhr.responseText);
                if (!payload || !Array.isArray(payload.plugins))
                    throw new Error(qsTr("Invalid plugin index"));

                entries = payload.plugins
                    .filter(plugin => plugin && typeof plugin.id === "string" && plugin.id.trim().length > 0 && typeof plugin.repo === "string" && plugin.repo.trim().length > 0)
                    .map(plugin => fallbackEntry(plugin));
            } catch (e) {
                loading = false;
                error = e.message || qsTr("Invalid plugin index");
                console.warn("[PluginList]", error);
                return;
            }

            plugins = entries;
            _pending = entries.length;

            if (entries.length === 0) {
                loading = false;
                return;
            }

            for (const entry of entries)
                fetchManifest(entry, generation);
        };

        xhr.ontimeout = function () {
            if (generation !== root._generation)
                return;
            loading = false;
            error = qsTr("Request timed out");
        };

        xhr.onerror = function () {
            if (generation !== root._generation)
                return;
            loading = false;
            error = qsTr("Network error");
        };

        xhr.open("GET", indexUrl + "?t=" + Date.now());
        xhr.send();
    }

    function fallbackEntry(plugin): var {
        const id = String(plugin.id).trim().toLowerCase();
        const slash = id.indexOf("/");

        return {
            id: id,
            listedId: id,
            repo: String(plugin.repo).trim(),
            path: typeof plugin.path === "string" ? plugin.path : "",
            name: slash >= 0 ? id.slice(slash + 1) : id,
            author: slash >= 0 ? id.slice(0, slash) : "",
            version: "",
            description: "",
            tags: [],
            icon: "extension",
            banner: "",
            logo: "",
            image: "",
            metadataLoading: true,
            metadataError: ""
        };
    }

    function fetchManifest(entry, generation): void {
        const urls = manifestUrls(entry.repo, entry.path);
        if (urls.length === 0) {
            entry.metadataLoading = false;
            entry.metadataError = qsTr("Only GitHub repositories can be previewed");
            refresh();
            finishFetch();
            return;
        }

        fetchManifestCandidate(entry, generation, urls, 0);
    }

    function fetchManifestCandidate(entry, generation, urls, index): void {
        if (generation !== root._generation)
            return;

        if (index >= urls.length) {
            entry.metadataLoading = false;
            entry.metadataError = qsTr("Could not load manifest");
            refresh();
            finishFetch();
            return;
        }

        const url = urls[index];
        const xhr = new XMLHttpRequest();
        xhr.timeout = 15000;
        let settled = false;

        const finish = function (message) {
            if (settled)
                return;
            settled = true;
            if (generation !== root._generation)
                return;

            entry.metadataLoading = false;
            entry.metadataError = message || "";
            refresh();
            finishFetch();
        };

        const retry = function () {
            if (settled)
                return;
            settled = true;
            if (generation !== root._generation)
                return;
            fetchManifestCandidate(entry, generation, urls, index + 1);
        };

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (generation !== root._generation)
                return;

            // Branches are tried in order because the index does not carry a branch name.
            if (xhr.status === 404 || xhr.status === 0) {
                retry();
                return;
            }

            if (xhr.status !== 200) {
                finish(xhr.statusText || qsTr("HTTP %1").arg(xhr.status));
                return;
            }

            try {
                applyManifest(entry, JSON.parse(xhr.responseText), url);
                finish("");
            } catch (e) {
                finish(e.message || qsTr("Invalid manifest"));
                console.warn("[PluginList]", entry.repo, e.message || e);
            }
        };

        xhr.ontimeout = function () {
            finish(qsTr("Request timed out"));
        };

        xhr.onerror = function () {
            finish(qsTr("Network error"));
        };

        xhr.open("GET", url + "?t=" + Date.now());
        xhr.send();
    }

    function applyManifest(entry, manifest, manifestUrl): void {
        if (!manifest || typeof manifest !== "object" || Array.isArray(manifest))
            throw new Error(qsTr("Invalid manifest"));

        const actualId = manifestId(manifest);
        if (actualId.length > 0) {
            if (actualId !== entry.listedId) {
                console.warn("[PluginList]", "Repository", entry.repo, "declares", actualId,
                    "but the index lists", entry.listedId, "- treating it as a different plugin");
            }
            entry.id = actualId;
        }

        if (manifest.displayName || manifest.name)
            entry.name = String(manifest.displayName || manifest.name);
        if (manifest.author)
            entry.author = String(manifest.author);
        if (manifest.version)
            entry.version = String(manifest.version);
        if (manifest.description)
            entry.description = String(manifest.description);
        if (manifest.icon)
            entry.icon = String(manifest.icon);

        if (Array.isArray(manifest.tags)) {
            entry.tags = manifest.tags
                .map(tag => String(tag).trim())
                .filter(tag => tag.length > 0);
        }

        entry.banner = resolveAsset(manifestUrl, manifest.banner || manifest.image || "");
        entry.logo = resolveAsset(manifestUrl, manifest.logo || "");
        entry.image = entry.banner;
        entry.metadataLoading = false;
        entry.metadataError = "";
    }

    function manifestId(manifest): string {
        const name = String(manifest.name || "").trim();
        const author = String(manifest.author || "unknown").trim() || "unknown";
        return name.length > 0 ? (author + "/" + name).toLowerCase() : "";
    }

    function manifestUrls(repo, path): var {
        const parts = githubParts(repo);
        if (!parts)
            return [];

        let subpath = String(path || "").trim().replace(/^\/+|\/+$/g, "");
        if (subpath.length > 0 && subpath.split("/").includes(".."))
            return [];
        if (subpath.length > 0 && subpath !== ".")
            subpath += "/";
        else
            subpath = "";

        const base = "https://raw.githubusercontent.com/" + parts.owner + "/" + parts.repo + "/";
        return [
            base + "main/" + subpath + "manifest.json",
            base + "master/" + subpath + "manifest.json",
            base + "HEAD/" + subpath + "manifest.json"
        ];
    }

    function githubParts(repo): var {
        const value = String(repo || "").trim();
        let match = value.match(/^https?:\/\/github\.com\/([^/]+)\/([^/?#]+)\/?$/i);
        if (!match)
            match = value.match(/^git@github\.com:([^/]+)\/([^/?#]+)$/i);
        if (!match)
            match = value.match(/^ssh:\/\/git@github\.com\/([^/]+)\/([^/?#]+)$/i);
        if (!match)
            return null;

        return {
            owner: match[1],
            repo: match[2].replace(/\.git$/i, "")
        };
    }

    function resolveAsset(manifestUrl, value): string {
        const source = String(value || "").trim();
        if (source.length === 0)
            return "";
        if (/^[a-z][a-z0-9+.-]*:/i.test(source) || source.startsWith("//"))
            return source;

        if (source.startsWith("/")) {
            const origin = manifestUrl.match(/^https?:\/\/[^/]+/i);
            return origin ? origin[0] + source : source;
        }

        const base = manifestUrl.slice(0, manifestUrl.lastIndexOf("/") + 1);
        return base + source.replace(/^\.\//, "");
    }

    function refresh(): void {
        plugins = Array.from(plugins);
    }

    function finishFetch(): void {
        _pending = Math.max(0, _pending - 1);
        if (_pending === 0)
            loading = false;
    }

    Component.onCompleted: reload()
}
