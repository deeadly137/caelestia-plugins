#include "plugins.hpp"

#include <qcoreapplication.h>
#include <qdir.h>
#include <qelapsedtimer.h>
#include <qfile.h>
#include <qfileinfo.h>
#include <qjsonarray.h>
#include <qjsondocument.h>
#include <qjsonobject.h>
#include <qloggingcategory.h>
#include <qprocess.h>
#include <qregularexpression.h>
#include <qsavefile.h>
#include <qset.h>
#include <qstandardpaths.h>
#include <qurl.h>

#include <QProcessEnvironment>

#include "pluginurlinterceptor.hpp"

#ifndef CAELESTIA_VERSION
#define CAELESTIA_VERSION ""
#endif

Q_LOGGING_CATEGORY(lcPlugins, "caelestia.plugins", QtInfoMsg)
Q_LOGGING_CATEGORY(lcPluginsPerf, "caelestia.plugins.perf", QtDebugMsg)

namespace caelestia::plugins {

namespace {

// git can hang forever on a repository that asks for credentials, so prompt for none at all
constexpr int kInstallTimeoutMs = 120000;
constexpr int kInstallErrorMaxLength = 300;

QString configDir() {
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/caelestia/");
}

QString pluginDataDir() {
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/caelestia/plugins");
}

// Git's failure output is multi-line and mostly progress noise. The last non-empty line is the
// part that says what actually went wrong.
QString summarizeGitOutput(const QString& output) {
    const auto lines = output.split(u'\n', Qt::SkipEmptyParts);
    for (auto it = lines.crbegin(); it != lines.crend(); ++it) {
        const auto line = it->trimmed();
        if (!line.isEmpty())
            return line.left(kInstallErrorMaxLength);
    }
    return {};
}

bool pathInside(const QString& path, const QString& root) {
    const auto cleanPath = QDir::cleanPath(QFileInfo(path).absoluteFilePath());
    auto cleanRoot = QDir::cleanPath(QFileInfo(root).absoluteFilePath());
    if (!cleanRoot.endsWith(QLatin1Char('/')))
        cleanRoot.append(QLatin1Char('/'));
    return cleanPath == cleanRoot.chopped(1) || cleanPath.startsWith(cleanRoot);
}

} // namespace

Plugins::Plugins(QObject* parent)
    : QObject(parent)
    , m_configPath(configDir() + QStringLiteral("plugins.json"))
    , m_watcher(new QFileSystemWatcher(this))
    , m_saveTimer(new QTimer(this))
    , m_reloadTimer(new QTimer(this)) {
    m_saveTimer->setSingleShot(true);
    m_saveTimer->setInterval(300);
    connect(m_saveTimer, &QTimer::timeout, this, &Plugins::saveConfig);

    m_reloadTimer->setSingleShot(true);
    m_reloadTimer->setInterval(200);
    connect(m_reloadTimer, &QTimer::timeout, this, [this] {
        // A burst of events (one save touches the file, its directory and sometimes a temp file)
        // collapses into one pass here. Config changes can flip enabled state or rewrite settings
        // for any plugin, so they still take the full path; a plugin edit only rescans its owner.
        const bool configChanged = m_configDirty;
        const bool discoveryChanged = m_discoveryDirty;
        const auto dirty = m_dirtyDirs;

        m_configDirty = false;
        m_discoveryDirty = false;
        m_dirtyDirs.clear();

        if (configChanged)
            loadConfig();

        if (!configChanged && !discoveryChanged && dirty.isEmpty())
            return;

        const bool full = configChanged || discoveryChanged;
        rescan(false, full ? QSet<QString>() : dirty,
            configChanged      ? QStringLiteral("config")
            : discoveryChanged ? QStringLiteral("discovery")
                               : QStringLiteral("watch"));
    });

    m_installTimeout = new QTimer(this);
    m_installTimeout->setSingleShot(true);
    m_installTimeout->setInterval(kInstallTimeoutMs);
    connect(m_installTimeout, &QTimer::timeout, this, [this] {
        if (!m_installing)
            return;

        m_installProcess->kill();

        if (!m_installTemp.isEmpty())
            QDir(m_installTemp).removeRecursively();

        finishInstall(false, tr("Cloning the plugin repository timed out"));
    });

    // Written to before anything is saved, so a crash cannot leave a truncated config behind
    if (auto* const app = QCoreApplication::instance()) {
        connect(app, &QCoreApplication::aboutToQuit, this, [this] {
            if (m_installing)
                m_installProcess->kill();

            if (m_saveTimer->isActive()) {
                m_saveTimer->stop();
                saveConfig();
            }
        });
    }

    connect(m_watcher, &QFileSystemWatcher::directoryChanged, this, &Plugins::onWatchEvent);
    connect(m_watcher, &QFileSystemWatcher::fileChanged, this, &Plugins::onWatchEvent);

    m_installProcess = new QProcess(this);
    m_installProcess->setProcessChannelMode(QProcess::MergedChannels);

    // Never let git wait for credentials on a socket the shell cannot answer
    auto installEnv = QProcessEnvironment::systemEnvironment();
    installEnv.insert(QStringLiteral("GIT_TERMINAL_PROMPT"), QStringLiteral("0"));
    m_installProcess->setProcessEnvironment(installEnv);

    connect(m_installProcess, &QProcess::finished, this, [this](int exitCode, QProcess::ExitStatus exitStatus) {
        if (!m_installing)
            return;

        const auto output = QString::fromLocal8Bit(m_installProcess->readAll()).trimmed();

        if (exitStatus != QProcess::NormalExit || exitCode != 0) {
            QDir(m_installTemp).removeRecursively();
            const auto reason = summarizeGitOutput(output);
            finishInstall(false, reason.isEmpty() ? tr("Could not clone the plugin repository") : reason);
            return;
        }

        const auto temp = m_installTemp;
        const auto target = m_installTarget;

        if (!m_installSubpath.isEmpty()) {
            const auto source = temp + QLatin1Char('/') + m_installSubpath;
            if (!QFileInfo(source).isDir()) {
                QDir(temp).removeRecursively();
                finishInstall(false, tr("The repository does not contain %1").arg(m_installSubpath));
                return;
            }

            if (!QDir().rename(source, target)) {
                QDir(temp).removeRecursively();
                finishInstall(false, tr("Could not move the plugin into %1").arg(target));
                return;
            }

            QDir(temp).removeRecursively();
        } else if (!QDir().rename(temp, target)) {
            QDir(temp).removeRecursively();
            finishInstall(false, tr("Could not move the plugin into %1").arg(target));
            return;
        }

        // The enabled list, settings and the Nexus pages are all keyed by the manifest id, so a
        // repository that declares a different one than the index entry would install a plugin
        // that can never be found by the id the UI knows. Refuse and say so.
        const PluginManifest probe(target, target + QStringLiteral("/manifest.json"));

        if (probe.hasParseError() || probe.id().isEmpty()) {
            QDir(target).removeRecursively();
            finishInstall(
                false, probe.error().isEmpty() ? tr("The repository has no valid plugin manifest") : probe.error());
            return;
        }

        if (!m_installExpectedId.isEmpty() && probe.id() != m_installExpectedId) {
            QDir(target).removeRecursively();
            finishInstall(
                false, tr("The repository declares %1, but %2 was expected").arg(probe.id(), m_installExpectedId));
            return;
        }

        reload();
        finishInstall(true, {});
    });

    connect(m_installProcess, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart || !m_installing)
            return;

        finishInstall(false, m_installProcess->errorString());
    });
}

Plugins::~Plugins() {
    // The engine keeps a raw pointer to the interceptor, and it may outlive this singleton
    if (m_engine && m_interceptor)
        m_engine->removeUrlInterceptor(m_interceptor);
}

void Plugins::classBegin() {}

void Plugins::componentComplete() {
    m_engine = qmlEngine(this);

    if (m_engine) {
        // Parented here so it dies with this engine generation rather than dangling
        m_interceptor = new PluginUrlInterceptor(this);
        m_engine->addUrlInterceptor(m_interceptor);
    } else {
        qCWarning(lcPlugins)
            << "No QML engine available - unable to seal plugin directories, hot reload may not work as expected";
    }

    loadConfig();
    rescan(false, {}, QStringLiteral("startup"));
}

QString Plugins::shellVersion() const {
    return QStringLiteral(CAELESTIA_VERSION);
}

int Plugins::pluginApi() const {
    return kPluginApiVersion;
}

QVariantList Plugins::plugins() const {
    return QVariant::fromValue(m_plugins).toList();
}

QList<PluginManifest*> Plugins::loadedManifests() const {
    QList<PluginManifest*> result;
    for (auto* const plugin : m_plugins)
        if (plugin->valid() && plugin->enabled())
            result.append(plugin);
    return result;
}

QVariantList Plugins::loadedPlugins() const {
    return QVariant::fromValue(loadedManifests()).toList();
}

QVariantList Plugins::conflictingPlugins() const {
    return QVariant::fromValue(m_conflictingPlugins).toList();
}

QStringList Plugins::enabled() const {
    return m_enabled;
}

void Plugins::setEnabled(const QStringList& enabled) {
    if (m_enabled == enabled)
        return;

    const auto previous = m_enabled;
    m_enabled = enabled;

    // Only the plugins whose enabled state actually flipped need their module re-registered or
    // cleared; everything else keeps its registration and its scan.
    QSet<QString> dirty;
    for (const auto& id : std::as_const(m_enabled)) {
        if (previous.contains(id))
            continue;
        if (auto* const plugin = manifestForId(id))
            dirty.insert(plugin->dir());
    }
    for (const auto& id : std::as_const(previous)) {
        if (m_enabled.contains(id))
            continue;
        if (auto* const plugin = manifestForId(id))
            dirty.insert(plugin->dir());
    }

    // Update modules and watches before notifying QML
    updateModules(false, dirty);
    updateWatches();

    for (auto* const plugin : std::as_const(m_plugins))
        plugin->setEnabled(m_enabled.contains(plugin->id()));

    emit enabledChanged();
    emit loadedPluginsChanged();
    m_saveTimer->start();
}

void Plugins::setPluginEnabled(const QString& pluginId, bool enabled) {
    QStringList next = m_enabled;
    if (enabled) {
        if (!next.contains(pluginId))
            next.append(pluginId);
    } else {
        next.removeAll(pluginId);
    }
    setEnabled(next);
}

void Plugins::rebuildEntryPointCache() const {
    m_entryPointsByType.clear();

    for (const auto* plugin : std::as_const(m_plugins)) {
        if (!plugin->valid() || !plugin->enabled())
            continue;

        for (const auto& entryPoint : plugin->entryPoints())
            m_entryPointsByType[int(entryPoint.type())].append(entryPoint);
    }

    m_entryPointCacheRevision = m_entryPointsRevision;
}

QList<EntryPoint> Plugins::__entryPoints(EntryPointType::Type type) const {
    // Anything that can change the flattened set bumps the revision, so comparing it is enough to
    // know the cached lists are still the answer.
    if (m_entryPointCacheRevision != m_entryPointsRevision)
        rebuildEntryPointCache();

    return m_entryPointsByType.value(int(type));
}

void Plugins::reload() {
    loadConfig();
    rescan(true, {}, QStringLiteral("reload"));
}

void Plugins::reloadPlugin(const QString& pluginId) {
    auto* const plugin = manifestForId(pluginId);
    if (!plugin) {
        qCWarning(lcPlugins) << "Cannot reload unknown plugin" << pluginId;
        return;
    }

    // The fingerprint normally decides whether a generation is needed. A caller asking for a
    // reload wants one regardless, so clear it and let the pass re-register the module. The
    // stamps go too: an explicit reload is what a user reaches for when an edit did not show up,
    // so it must not trust the stat that said the file had not moved. Only this plugin is
    // rescanned, since an explicit reload says nothing about the others.
    QSet<QString> dirty;
    if (auto it = m_records.find(plugin->dir()); it != m_records.end()) {
        it->fingerprint.clear();
        it->stamps.clear();
        dirty.insert(plugin->dir());
    }

    // Through the normal pass rather than straight into updateModules, so the manifest is
    // reparsed, the counters are filled in and the perf log has a line for the reload.
    rescan(false, dirty, QStringLiteral("reload-plugin"));
}

PluginManifest* Plugins::manifestForId(const QString& pluginId) const {
    const auto id = pluginId.trimmed().toLower();
    for (auto* const plugin : m_plugins)
        if (plugin->id() == id)
            return plugin;

    return nullptr;
}

void Plugins::loadConfig() {
    QFile file(m_configPath);

    // No file at all is not a failure, it just means defaults
    if (!file.exists()) {
        m_configOnDisk.clear();
        m_enabled.clear();
        m_extraPaths.clear();
        m_settings.clear();
        emit enabledChanged();
        return;
    }

    // Every failure below leaves the last good config in place. Clearing first and bailing would
    // disable every plugin, and the next save would write that empty state over the real one.
    if (!file.open(QIODevice::ReadOnly)) {
        qCWarning(lcPlugins) << "Failed to open" << m_configPath << file.errorString();
        return;
    }

    const auto data = file.readAll();
    file.close();

    // Recorded even when it does not parse: re-reading an unchanged broken file achieves nothing,
    // and the next save overwrites it anyway.
    m_configOnDisk = data;

    QJsonParseError error{};
    const auto doc = QJsonDocument::fromJson(data, &error);

    if (error.error != QJsonParseError::NoError) {
        qCWarning(lcPlugins) << "Failed to parse" << m_configPath << error.errorString();
        return;
    }

    // A syntactically valid document that is not an object (e.g. a bare `[]`) carries none of the
    // keys we read. Committing it would silently disable every plugin and clear their settings in
    // memory, and the next save would write that over the real config.
    if (!doc.isObject()) {
        qCWarning(lcPlugins) << "Ignoring" << m_configPath << "because its root is not a JSON object";
        return;
    }

    const auto obj = doc.object();

    QStringList enabled;
    const auto enabledArray = obj.value(QStringLiteral("enabled")).toArray();
    for (const auto& entry : enabledArray)
        enabled.append(entry.toString());

    QStringList extraPaths;
    const auto pathArray = obj.value(QStringLiteral("path")).toArray();
    for (const auto& entry : pathArray)
        extraPaths.append(entry.toString());

    // Committed only once the whole file has parsed, so a half read or malformed config never
    // becomes the in memory state, and therefore never reaches disk on the next save.
    m_enabled = std::move(enabled);
    m_extraPaths = std::move(extraPaths);
    m_settings = obj.value(QStringLiteral("settings")).toObject().toVariantMap();

    emit enabledChanged();
}

void Plugins::saveConfig() {
    // Merge settings into settings from file so confs for removed plugins are preserved
    for (const auto* plugin : std::as_const(m_plugins))
        if (!plugin->id().isEmpty())
            m_settings.insert(plugin->id(), plugin->settingsValues());

    QJsonObject obj;
    obj.insert(QStringLiteral("enabled"), QJsonArray::fromStringList(m_enabled));
    obj.insert(QStringLiteral("path"), QJsonArray::fromStringList(m_extraPaths));
    obj.insert(QStringLiteral("settings"), QJsonObject::fromVariantMap(m_settings));

    const auto json = QJsonDocument(obj).toJson(QJsonDocument::Indented);

    // Nothing moved, so no write, no watcher event to recognise and nothing new to watch. Falls
    // through to the dirty flags below: identical content means memory already matches the file.
    if (json != m_configOnDisk) {
        QDir().mkpath(QFileInfo(m_configPath).absolutePath());

        // Written through a temp file and renamed into place, so a crash or full disk leaves the
        // previous config intact instead of a truncated one.
        QSaveFile file(m_configPath);
        if (!file.open(QIODevice::WriteOnly)) {
            qCWarning(lcPlugins) << "Failed to write" << m_configPath << file.errorString();
            return;
        }

        file.write(json);

        if (!file.commit()) {
            qCWarning(lcPlugins) << "Failed to write" << m_configPath << file.errorString();
            return;
        }

        m_configOnDisk = json;

        updateWatches();
    }

    // Everything in memory is now on disk, so a rescan may safely reload settings again. Skipped
    // on a failed write, so the values stay dirty and a rescan does not reload over them.
    for (auto* const plugin : std::as_const(m_plugins))
        plugin->markSettingsSaved();
}

QStringList Plugins::discoverPluginDirs() const {
    QStringList dirs;

    const auto roots = searchRoots();
    for (const auto& root : roots) {
        QDir dir(root);
        if (!dir.exists())
            continue;

        const auto subdirs = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
        for (const auto& subdir : subdirs) {
            const QString pluginDir = dir.absoluteFilePath(subdir);
            if (QFile::exists(pluginDir + QStringLiteral("/manifest.json")))
                dirs.append(pluginDir);
        }
    }

    return dirs;
}

void Plugins::rescan(bool force, const QSet<QString>& dirty, const QString& trigger) {
    QElapsedTimer elapsed;
    elapsed.start();

    const auto previousPlugins = m_plugins;
    const auto previousConflicting = m_conflictingPlugins;
    const auto previousLoaded = loadedManifests();
    const bool partial = !force && !dirty.isEmpty();

    ScanCounters counters;

    const auto dirs = discoverPluginDirs();

    // Sealed before anything in a newly discovered plugin can compile, since a directory that
    // resolves its types by filename once keeps doing so for the rest of the process. Every plugin
    // found, enabled or not, is sealed otherwise the first compile after an enable would beat the seal to it.
    if (m_interceptor)
        m_interceptor->setRoots(dirs);

    // Reuse manifests instead of remaking all on rescan
    QList<PluginManifest*> result;
    for (const auto& pluginDir : dirs) {
        auto& record = m_records[pluginDir];
        auto* manifest = record.manifest;

        // A partial pass only touches the plugins the watcher pointed at. Everything else keeps
        // the manifest it already parsed: reparsing identical JSON cannot change anything.
        const bool touched = !partial || dirty.contains(pluginDir) || manifest == nullptr;

        if (manifest) {
            if (touched) {
                manifest->reparse();
                ++counters.manifestsReparsed;
            }
        } else {
            manifest = new PluginManifest(pluginDir, pluginDir + QStringLiteral("/manifest.json"), this);
            ++counters.manifestsReparsed;

            connect(manifest, &PluginManifest::settingsValuesChanged, this, [this] {
                m_saveTimer->start();
            });
            connect(manifest, &PluginManifest::entryPointsChanged, this, &Plugins::bumpEntryPointsRevision);
            connect(manifest, &PluginManifest::validChanged, this, &Plugins::bumpEntryPointsRevision);
            connect(manifest, &PluginManifest::enabledChanged, this, &Plugins::bumpEntryPointsRevision);

            // The plugin list is a snapshot in QML, so metadata edits would otherwise not refresh
            // the Nexus cards until the list's membership changed.
            for (const auto signal : {
                     &PluginManifest::nameChanged,
                     &PluginManifest::versionChanged,
                     &PluginManifest::iconChanged,
                     &PluginManifest::descriptionChanged,
                     &PluginManifest::authorChanged,
                     &PluginManifest::tagsChanged,
                     &PluginManifest::bannerChanged,
                     &PluginManifest::logoChanged,
                     &PluginManifest::requirementChanged,
                 })
                connect(manifest, signal, this, &Plugins::notifyMetadataChanged);

            record.manifest = manifest;
        }

        manifest->setEnabled(m_enabled.contains(manifest->id()));

        // Don't load from file if there are unsaved settings. Only a pass that reparsed the
        // manifest can have new values to apply; an untouched plugin already holds them.
        if (touched && !manifest->hasUnsavedSettings())
            manifest->loadSettings(m_settings.value(manifest->id()).toMap());

        if (manifest->hasParseError())
            qCWarning(lcPlugins) << "Ignoring plugin" << manifest->id() << "-" << manifest->error();

        result.append(manifest);
    }

    // Drop records whose directory no longer holds a manifest.json. This leaks, but Qt does not have a
    // public unregister API so we have to deal with it.
    for (auto it = m_records.begin(); it != m_records.end();) {
        if (dirs.contains(it.key())) {
            ++it;
            continue;
        }

        it.value().manifest->deleteLater();
        it = m_records.erase(it);
    }

    // Conflicting ids will disable all plugins with the contested id
    QHash<QString, QList<PluginManifest*>> byId;
    for (auto* const plugin : result)
        if (!plugin->hasParseError())
            byId[plugin->id()].append(plugin);

    // Recomputed from scratch every pass, since removing a claimant revalidates the rest.
    QList<PluginManifest*> conflicting;
    for (auto* const plugin : result) {
        const auto claimants = plugin->hasParseError() ? QList<PluginManifest*>() : byId.value(plugin->id());
        if (claimants.size() < 2) {
            plugin->setConflicts({});
            continue;
        }

        QStringList others;
        for (const auto* claimant : claimants)
            if (claimant != plugin)
                others.append(claimant->dir());

        qCWarning(lcPlugins) << "Duplicate plugin id" << plugin->id() << "in" << plugin->dir() << "- also declared by"
                             << others.join(QStringLiteral(", "));

        plugin->setConflicts(others);
        conflicting.append(plugin);
    }

    m_plugins = result;
    m_conflictingPlugins = conflicting;

    // After the id grouping, so a plugin caught in a clash registers nothing
    updateModules(force, dirty, &counters, m_changedFiles);
    m_changedFiles.clear();

    if (m_plugins != previousPlugins) {
        emit pluginsChanged();
        bumpEntryPointsRevision();
    }
    if (m_conflictingPlugins != previousConflicting)
        emit conflictingPluginsChanged();
    if (loadedManifests() != previousLoaded)
        emit loadedPluginsChanged();

    emit loaded();

    updateWatches();

    const QVariantMap stats{
        { QStringLiteral("trigger"), trigger },
        { QStringLiteral("durationMs"), elapsed.elapsed() },
        { QStringLiteral("partial"), partial },
        { QStringLiteral("discovered"), int(dirs.size()) },
        { QStringLiteral("manifestsReparsed"), counters.manifestsReparsed },
        { QStringLiteral("modulesScanned"), counters.modulesScanned },
        { QStringLiteral("filesRead"), counters.filesRead },
        { QStringLiteral("filesReused"), counters.filesReused },
        { QStringLiteral("generationsBumped"), counters.generationsBumped },
        { QStringLiteral("scanned"), counters.scanned },
        { QStringLiteral("reloaded"), counters.reloaded },
        { QStringLiteral("details"), counters.details },
    };

    m_scanStats = stats;
    emit scanStatsChanged();

    // The perf log is the machine readable check for the "an edit only rescans its own plugin"
    // rule: one line per pass, with the file counters that rule is stated in.
    qCDebug(lcPluginsPerf).nospace() << "rescan trigger=" << (trigger.isEmpty() ? QStringLiteral("manual") : trigger)
                                     << " partial=" << partial << " discovered=" << dirs.size()
                                     << " reparsed=" << counters.manifestsReparsed
                                     << " scanned=" << counters.scanned.size() << " read=" << counters.filesRead
                                     << " reused=" << counters.filesReused << " reloaded=" << counters.generationsBumped
                                     << " ms=" << elapsed.elapsed();
}

void Plugins::updateModules(
    bool force, const QSet<QString>& dirty, ScanCounters* counters, const QSet<QString>& changed) {
    // Every plugin's root URI, so a file importing another plugin's module can be flagged
    QStringList uris;
    for (const auto* plugin : std::as_const(m_plugins))
        if (plugin->valid())
            uris.append(plugin->moduleUri());

    // A partial pass is limited to the plugins the caller flagged. Everything else keeps the
    // module, the registration and the stamps it already has; there is nothing to recompute.
    const bool partial = !force && !dirty.isEmpty();

    QList<PluginManifest*> bumped;

    for (auto* const plugin : std::as_const(m_plugins)) {
        const bool touched = !partial || dirty.contains(plugin->dir());
        if (!touched)
            continue;

        auto& record = m_records[plugin->dir()];

        const auto valid = plugin->valid();
        const auto previousUri = record.module.uri();
        const auto previousWarnings = plugin->warnings();

        QStringList warnings;

        // Renaming the plugin renames its module, but the author's own imports can still name the old
        // one and keep resolving to it until the QML engine dies. We can't do anything about that, so send
        // a warning instead.
        if (valid && !previousUri.isEmpty() && previousUri != plugin->moduleUri())
            warnings.append(QStringLiteral(
                "Plugin was renamed from '%1' to '%2'. Imports may not work as expected until next restart.")
                    .arg(previousUri, plugin->moduleUri()));

        // Don't register plugins which are not enabled. Use the enabled map instead of the manifest
        // as this is called before the manifest is flipped.
        const auto active = valid && m_enabled.contains(plugin->id());

        bool reload = false;

        if (active) {
            auto others = uris;
            others.removeAll(plugin->moduleUri());

            PluginModuleScanStats moduleStats;

            record.module = PluginModule(plugin->dir(), plugin->moduleUri());
            record.module.scan(others, record.stamps, &moduleStats, changed);
            warnings.append(record.module.warnings());

            // Qt has no unregister API, so a type that disappeared from the plugin keeps its old
            // registration (and its old file URL) until the process ends. Imports of it still
            // resolve, then fail to compile because the file is gone, and no reload can undo that.
            // Only a fresh shell start can, so say so when the set actually shrinks.
            QSet<QString> types;
            for (const auto& type : record.module.types())
                types.insert(type.name);

            auto& registered = m_registeredTypes[plugin->moduleUri()];
            auto removedTypes = registered - types;
            if (!removedTypes.isEmpty()) {
                QStringList names = removedTypes.values();
                names.sort();
                warnings.append(QStringLiteral(
                    "Registered QML types are gone: %1. Qt cannot unregister them, so anything still importing "
                    "them keeps resolving to the old files and fails; restart the shell to clean this up.")
                        .arg(names.join(QStringLiteral(", "))));
            }

            registered = types;

            if (counters) {
                ++counters->modulesScanned;
                counters->filesRead += moduleStats.filesRead;
                counters->filesReused += moduleStats.filesReused;
                counters->scanned.append(plugin->id());
                counters->details.append(QStringLiteral("%1: %2 read, %3 reused")
                        .arg(plugin->id())
                        .arg(moduleStats.filesRead)
                        .arg(moduleStats.filesReused));
            }

            // Manifest fields that pick files to load which may not necessarily be valid QML components (and are
            // therefore skipped in the tree walk)
            // e.g. a lowercase named QML file
            auto fingerprint = record.module.fingerprint();
            fingerprint.append(plugin->declaredSettings().toUtf8());
            fingerprint.append('\0');
            fingerprint.append(plugin->declaredSettingsUi().toUtf8());

            reload = fingerprint != record.fingerprint || force;
            if (reload)
                record.fingerprint = std::move(fingerprint);
        } else {
            record.module = PluginModule();
            record.fingerprint.clear();

            // The stamps describe files that are still on disk, so they stay: re-enabling the
            // plugin then costs a stat per file instead of a read.
        }

        plugin->setWarnings(warnings);

        // Re-logged on every reload, since a warning describes a standing problem with the plugin
        // rather than something that just happened. Also logged when only the warnings moved,
        // which is how another plugin appearing can make a cross plugin import visible.
        if (reload || warnings != previousWarnings)
            for (const auto& warning : std::as_const(warnings))
                qCWarning(lcPlugins, "[%s] %s", qUtf8Printable(plugin->id()), qUtf8Printable(warning));

        if (!reload)
            continue;

        record.generation = ++m_generationCounter;

        if (counters) {
            ++counters->generationsBumped;
            counters->reloaded.append(plugin->id());
        }

        // Before any fan-out, or an import resolves the previous registration
        record.module.registerTypes(record.generation);

        bumped.append(plugin);
    }

    // Fanned out only once every module is registered, and synchronously, so no live loader sees
    // a half updated set of registrations and no loader created mid-pass joins the wrong cohort.
    for (auto* const plugin : std::as_const(bumped))
        plugin->setGeneration(m_records[plugin->dir()].generation);
}

void Plugins::bumpEntryPointsRevision() {
    m_entryPointsRevision++;
    emit entryPointsRevisionChanged();
}

int Plugins::entryPointsRevision() const {
    return m_entryPointsRevision;
}

QVariantMap Plugins::scanStats() const {
    return m_scanStats;
}

bool Plugins::installing() const {
    return m_installing;
}

QString Plugins::installingPlugin() const {
    return m_installingPlugin;
}

QString Plugins::installError() const {
    return m_installError;
}

QString Plugins::removeError() const {
    return m_removeError;
}

bool Plugins::isManagedDir(const QString& dir) const {
    return pathInside(dir, pluginDataDir()) || pathInside(dir, configDir() + QStringLiteral("plugins"));
}

bool Plugins::isManaged(const QString& pluginId) const {
    const auto* plugin = manifestForId(pluginId);
    return plugin && isManagedDir(plugin->dir());
}

void Plugins::installPlugin(const QString& repo, const QString& path, const QString& pluginId) {
    if (m_installing)
        return;

    m_installError.clear();
    emit installErrorChanged();

    if (repo.trimmed().isEmpty()) {
        m_installError = tr("No repository was provided");
        emit installErrorChanged();
        emit installFinished(pluginId, false, m_installError);
        return;
    }

    if (QStandardPaths::findExecutable(QStringLiteral("git")).isEmpty()) {
        m_installError = tr("git is not installed");
        emit installErrorChanged();
        emit installFinished(pluginId, false, m_installError);
        return;
    }

    auto targetName = pluginId.trimmed();
    if (targetName.isEmpty())
        targetName = QFileInfo(QUrl(repo).path()).completeBaseName();
    targetName.replace(QLatin1Char('/'), QLatin1Char('-'));
    targetName.remove(QRegularExpression(QStringLiteral("[^A-Za-z0-9._-]")));

    if (targetName.isEmpty() || targetName == QLatin1String(".") || targetName == QLatin1String("..")) {
        m_installError = tr("Could not derive a plugin directory name");
        emit installErrorChanged();
        emit installFinished(pluginId, false, m_installError);
        return;
    }

    auto subpath = QDir::cleanPath(path.trimmed());
    if (subpath == QLatin1String("."))
        subpath.clear();
    if (subpath.startsWith(QLatin1Char('/')) || subpath == QLatin1String("..") ||
        subpath.startsWith(QLatin1String("../"))) {
        m_installError = tr("Invalid plugin subdirectory");
        emit installErrorChanged();
        emit installFinished(pluginId, false, m_installError);
        return;
    }

    const auto dataDir = pluginDataDir();
    const auto target = dataDir + QLatin1Char('/') + targetName;
    const auto temp = dataDir + QLatin1Char('/') + QLatin1Char('.') + targetName + QStringLiteral(".install");

    if (QFileInfo::exists(target)) {
        m_installError = tr("A plugin directory named %1 already exists").arg(targetName);
        emit installErrorChanged();
        emit installFinished(pluginId, false, m_installError);
        return;
    }

    QDir().mkpath(dataDir);
    QDir(temp).removeRecursively();

    m_installing = true;
    m_installingPlugin = pluginId.isEmpty() ? targetName : pluginId;
    m_installTemp = temp;
    m_installTarget = target;
    m_installSubpath = subpath;
    m_installExpectedId = pluginId.trimmed().toLower();

    emit installingChanged();
    emit installingPluginChanged();

    m_installTimeout->start();

    m_installProcess->setProgram(QStringLiteral("git"));
    m_installProcess->setArguments({
        QStringLiteral("clone"),
        QStringLiteral("--depth"),
        QStringLiteral("1"),
        QStringLiteral("--"),
        repo,
        temp,
    });
    m_installProcess->start();
}

bool Plugins::removePlugin(const QString& pluginId) {
    m_removeError.clear();
    emit removeErrorChanged();

    auto* const plugin = manifestForId(pluginId);
    if (!plugin) {
        m_removeError = tr("Plugin not found");
        emit removeErrorChanged();
        emit pluginRemoved(pluginId, false, m_removeError);
        return false;
    }

    if (!isManagedDir(plugin->dir())) {
        m_removeError = tr("This plugin is not in a managed plugin directory");
        emit removeErrorChanged();
        emit pluginRemoved(pluginId, false, m_removeError);
        return false;
    }

    const auto dir = plugin->dir();

    // Disable and persist before deleting, otherwise reload() would read the old enabled entry
    // back from disk and leave a stale id behind.
    setPluginEnabled(pluginId, false);
    saveConfig();

    if (!QDir(dir).removeRecursively()) {
        m_removeError = tr("Could not delete %1").arg(dir);
        emit removeErrorChanged();
        emit pluginRemoved(pluginId, false, m_removeError);
        return false;
    }

    reload();
    emit pluginRemoved(pluginId, true, {});
    return true;
}

void Plugins::cancelInstall() {
    if (!m_installing)
        return;

    m_installProcess->kill();

    if (!m_installTemp.isEmpty())
        QDir(m_installTemp).removeRecursively();

    finishInstall(false, tr("Installation cancelled"));
}

void Plugins::finishInstall(bool success, const QString& message) {
    const auto pluginId = m_installingPlugin;

    m_installTimeout->stop();

    if (!success) {
        m_installError = message;
        emit installErrorChanged();
    }

    m_installing = false;
    m_installingPlugin.clear();
    m_installTemp.clear();
    m_installTarget.clear();
    m_installSubpath.clear();
    m_installExpectedId.clear();

    emit installingChanged();
    emit installingPluginChanged();
    emit installFinished(pluginId, success, message);
}

QStringList Plugins::searchRoots() const {
    QStringList roots;
    roots.append(pluginDataDir());
    roots.append(configDir() + QStringLiteral("plugins"));

    const auto envPath = qEnvironmentVariable("CAELESTIA_PLUGIN_PATH");
    if (!envPath.isEmpty())
        roots.append(envPath.split(QLatin1Char(':'), Qt::SkipEmptyParts));

    roots.append(m_extraPaths);
    roots.removeDuplicates();
    return roots;
}

void Plugins::updateWatches() {
    // Desired watch set plus the plugin each path belongs to. Config and search roots have no
    // owner: a change under them is a discovery event, not a plugin edit.
    QStringList paths;
    QHash<QString, QString> owners;

    paths.append(QFileInfo(m_configPath).absolutePath());
    paths.append(m_configPath);
    paths.append(searchRoots());

    // Directories report files appearing and disappearing; the files themselves report edits,
    // which a directory watch does not. The module's own walk decides what is worth watching, so
    // dotfiles and .git stay out of it.
    for (auto it = m_records.cbegin(); it != m_records.cend(); ++it) {
        const auto& dir = it.key();
        paths.append(dir);
        paths.append(dir + QStringLiteral("/manifest.json"));
        owners.insert(dir, dir);
        owners.insert(dir + QStringLiteral("/manifest.json"), dir);

        for (const auto& watch : it.value().module.watchPaths()) {
            paths.append(watch);
            owners.insert(watch, dir);
        }
    }

    paths.removeDuplicates();

    // Diffed rather than removed and re-added wholesale: a readd makes Qt drop and recreate the
    // OS level watch for every path on every pass, which costs exactly what the reload is trying
    // to avoid, and loses events raised while the path was unwatched.
    const auto current = m_watcher->files() + m_watcher->directories();

    QStringList removed;
    for (const auto& path : current)
        if (!paths.contains(path))
            removed.append(path);
    if (!removed.isEmpty())
        m_watcher->removePaths(removed);

    QStringList added;
    for (const auto& path : std::as_const(paths))
        if (!current.contains(path) && QFile::exists(path))
            added.append(path);
    if (!added.isEmpty()) {
        const auto failed = m_watcher->addPaths(added);
        for (const auto& path : failed)
            qCDebug(lcPluginsPerf) << "Cannot watch" << path;
    }

    m_watchOwners = owners;
}

QString Plugins::ownerForWatchPath(const QString& path) const {
    if (const auto it = m_watchOwners.constFind(path); it != m_watchOwners.cend())
        return *it;

    // A path the map has not learned yet, e.g. a file created since the last pass. Attribute it to
    // the longest plugin directory containing it. The loop is over plugin directories only, so
    // this stays cheap.
    QString owner;
    for (auto it = m_records.cbegin(); it != m_records.cend(); ++it) {
        if (path.startsWith(it.key() + u'/') && path.size() > owner.size())
            owner = it.key();
    }

    return owner;
}

std::optional<QByteArray> Plugins::readConfig() const {
    QFile file(m_configPath);

    // Missing and unreadable are different from empty: the caller uses this to decide whether a
    // watcher event was one of our own writes, and an unreadable file is never that.
    if (!file.exists() || !file.open(QIODevice::ReadOnly))
        return std::nullopt;

    return file.readAll();
}

void Plugins::onWatchEvent(const QString& path) {
    // Attributed before the watch set is diffed: a deleted or replaced file has already been
    // dropped by the watcher, so the rebuilt map would no longer know which plugin it belonged to.
    const auto owner = ownerForWatchPath(path);

    // The watch set is diffed first, because a file that appeared or vanished changes it whether
    // or not the event turns into work below, and an edit to a re-created file has to be watched
    // again before the next save, not after the pass that reacts to this one.
    updateWatches();

    if (path == m_configPath) {
        // Only ignore writes to the config file, checked by content
        const auto config = readConfig();

        if (config && *config == m_configOnDisk)
            return;

        // The file is gone and there is no in-memory config to clear
        if (!config && m_enabled.isEmpty() && m_extraPaths.isEmpty() && m_settings.isEmpty())
            return;

        m_configDirty = true;
    } else if (!owner.isEmpty()) {
        // The common case: one plugin's file moved. Only that plugin is scanned, and only its
        // generation is bumped if its fingerprint actually changed. The path is remembered so the
        // scan reads it even if its stat still matches the stamp.
        m_dirtyDirs.insert(owner);
        m_changedFiles.insert(path);
    } else if (path == QFileInfo(m_configPath).absolutePath()) {
        // A save of our own config rewrites the config file and touches the directory holding it.
        // Nothing to do when the bytes on disk are the ones this instance wrote.
        const auto config = readConfig();
        if (config && *config == m_configOnDisk)
            return;

        m_configDirty = true;
    } else {
        // A search root: a plugin directory may have appeared or disappeared, which only a full
        // discovery pass can see.
        m_discoveryDirty = true;
    }

    qCDebug(lcPluginsPerf).nospace() << "watch event " << path << " owner="
                                     << (owner.isEmpty() ? QStringLiteral("-") : QFileInfo(owner).fileName());

    m_reloadTimer->start();
}

void Plugins::notifyMetadataChanged() {
    if (m_metadataNotifyQueued)
        return;

    m_metadataNotifyQueued = true;

    // Coalesced: a reparse that moves name, icon and description emits all three before the
    // list is rebuilt once.
    QTimer::singleShot(0, this, [this] {
        m_metadataNotifyQueued = false;
        emit pluginsChanged();
    });
}

} // namespace caelestia::plugins
