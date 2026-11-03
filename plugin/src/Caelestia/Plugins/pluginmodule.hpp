#pragma once

#include <qbytearray.h>
#include <qhash.h>
#include <qlist.h>
#include <qset.h>
#include <qstring.h>
#include <qstringlist.h>

namespace caelestia::plugins {

// What a scan remembers about one file, so an untouched file costs a stat instead of a read,
// a SHA-1 and an import check. Removed by the next scan that does not visit the file.
struct PluginModuleFileStamp {
    qint64 mtimeMs = 0;
    qint64 size = -1;
    QByteArray hash;

    // Parsed out of the content, so a reused stamp still yields the same type metadata.
    bool singleton = false;

    // Everything besides the file's own bytes that changes the import warnings: the module URI,
    // the sibling type names of its directory and the other plugins' root URIs.
    QByteArray context;
    QStringList warnings;
};

using PluginModuleStamps = QHash<QString, PluginModuleFileStamp>;

// How much of a scan was served from the stamps above; feeds the rescan counters.
struct PluginModuleScanStats {
    int filesRead = 0;
    int filesReused = 0;
};

// A single QML type discovered in a plugin's directory tree.
struct PluginModuleType {
    QString uri;  // Module URI of the directory holding the file
    QString name; // QML type name, i.e. the file's base name
    QString path; // Absolute path to the .qml file
    bool singleton = false;
};

// A plugin's QML module: every type under the plugin directory, exposed to QML as the plugin
// id with '/' replaced by '.', plus one submodule per subdirectory that holds types (case
// preserved). A subdirectory with no types gets no module, so importing it fails.
class PluginModule {
public:
    PluginModule() = default;
    PluginModule(QString dir, QString uri);

    // Module URI for a plugin id, i.e. author/name -> author.name
    [[nodiscard]] static QString uriFor(const QString& id);

    // Whether a name may be used as a module URI segment. Anything else is a parse error at
    // the import site rather than at registration, so Qt will not reject it for us.
    [[nodiscard]] static bool isValidUriSegment(const QString& name);

    [[nodiscard]] QString dir() const;
    [[nodiscard]] QString uri() const;

    // Walks the tree collecting its types, the warnings its layout earns and a fingerprint of
    // everything a reload depends on. `otherUris` holds the other plugins' root URIs so cross
    // plugin imports, which per plugin generations cannot keep consistent, can be flagged.
    // `stamps` is the caller's per-file cache: it survives module recreation, so a rescan of a
    // plugin whose files did not move only stats them.
    void scan(const QStringList& otherUris, PluginModuleStamps& stamps, PluginModuleScanStats* stats = nullptr);

    // Registers every discovered type, with `generation` in each URL's query so the engine
    // compiles the file again instead of handing back the unit it cached for the last one. Must
    // happen before anything in the plugin recompiles, or that recompile resolves the previous
    // registration.
    void registerTypes(int generation) const;

    [[nodiscard]] QList<PluginModuleType> types() const;
    [[nodiscard]] QStringList warnings() const;

    // Every directory visited and every .qml file in it, i.e. the paths whose changes have to
    // trigger a reload. Directories catch files appearing and disappearing, files catch edits.
    [[nodiscard]] QStringList watchPaths() const;

    // Changes whenever anything the module exposes changes: a file's contents, the set of
    // files, or a directory's URI. Equal fingerprints mean re-registering would be a no-op.
    [[nodiscard]] QByteArray fingerprint() const;

private:
    void scanDir(const QString& path, const QString& uri, const QStringList& otherUris, QByteArray& data,
        QSet<QString>& visited, int depth, PluginModuleStamps& stamps, QSet<QString>& seenFiles,
        PluginModuleScanStats* stats);

    // Returns the warnings this file earns; they are cached with the file's stamp.
    [[nodiscard]] QStringList checkImports(const QString& path, const QString& uri, const QString& content,
        const QStringList& siblings, const QStringList& otherUris) const;

    QString m_dir;
    QString m_uri;
    QList<PluginModuleType> m_types;
    QStringList m_warnings;
    QStringList m_watchPaths;
    QByteArray m_fingerprint;
};

} // namespace caelestia::plugins
