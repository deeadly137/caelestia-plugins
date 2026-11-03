#include "pluginmodule.hpp"

#include <qcryptographichash.h>
#include <qdir.h>
#include <qfile.h>
#include <qfileinfo.h>
#include <qqml.h>
#include <qregularexpression.h>
#include <qurl.h>

namespace caelestia::plugins {

namespace {

// The max recursion depth to scan for QML files. Plugins should not ever go this deep.
constexpr int kMaxDepth = 16;

// Qt resolves module names to the most recently registered type no matter its version, so
// we simply re-register types at the same version to reload.
constexpr int kModuleMajor = 1;
constexpr int kModuleMinor = 0;

// qmlRegisterSingletonType refuses a file without the pragma, so the pragma is what decides,
// not anything the manifest could declare.
bool hasSingletonPragma(const QString& content) {
    static const QRegularExpression re(
        QStringLiteral("^[ \t]*pragma[ \t]+Singleton[ \t]*;?[ \t]*$"), QRegularExpression::MultilineOption);
    return re.match(content).hasMatch();
}

// Matches `import <uri>` at the start of a line, whether or not the author wrote a version after
// it. Refuses to match a longer URI that merely starts with the same characters; `withSubmodules`
// widens it to the URI's own submodules, i.e. `<uri>.Anything`.
QRegularExpression importPattern(const QString& uri, bool withSubmodules = false) {
    const auto tail = withSubmodules ? QStringLiteral("(?:\\.\\w+)*(?!\\w)") : QStringLiteral("(?![\\w.])");
    return QRegularExpression(QStringLiteral("^[ \t]*import[ \t]+%1%2").arg(QRegularExpression::escape(uri), tail),
        QRegularExpression::MultilineOption);
}

// The inputs of checkImports that are not the file's own bytes. When this signature matches the
// one a stamp was made with, the cached warnings are still valid and the file need not be read.
QByteArray importContext(const QString& uri, const QStringList& siblings, const QStringList& otherUris) {
    auto others = otherUris;
    others.sort();

    QByteArray context = uri.toUtf8();
    context.append('\n');
    context.append(siblings.join(u'\n').toUtf8());
    context.append('\n');
    context.append(others.join(u'\n').toUtf8());
    return context;
}

} // namespace

PluginModule::PluginModule(QString dir, QString uri)
    : m_dir(std::move(dir))
    , m_uri(std::move(uri)) {}

QString PluginModule::uriFor(const QString& id) {
    QString uri = id;
    uri.replace(u'/', u'.');
    return uri;
}

bool PluginModule::isValidUriSegment(const QString& name) {
    static const QRegularExpression re(QStringLiteral("^[A-Za-z_][A-Za-z0-9_]*$"));
    return re.match(name).hasMatch();
}

QString PluginModule::dir() const {
    return m_dir;
}

QString PluginModule::uri() const {
    return m_uri;
}

QList<PluginModuleType> PluginModule::types() const {
    return m_types;
}

QStringList PluginModule::warnings() const {
    return m_warnings;
}

QStringList PluginModule::watchPaths() const {
    return m_watchPaths;
}

QByteArray PluginModule::fingerprint() const {
    return m_fingerprint;
}

void PluginModule::scan(const QStringList& otherUris, PluginModuleStamps& stamps, PluginModuleScanStats* stats) {
    m_types.clear();
    m_warnings.clear();
    m_watchPaths.clear();

    QByteArray data;
    QSet<QString> visited;
    QSet<QString> seenFiles;
    scanDir(m_dir, m_uri, otherUris, data, visited, 0, stamps, seenFiles, stats);

    // Files that left the tree must not keep a stamp: a file that comes back with the same mtime
    // and size after being replaced would otherwise be served stale.
    for (auto it = stamps.begin(); it != stamps.end();) {
        if (it.key().startsWith(m_dir + u'/') && !seenFiles.contains(it.key()))
            it = stamps.erase(it);
        else
            ++it;
    }

    m_fingerprint = QCryptographicHash::hash(data, QCryptographicHash::Sha1);
}

void PluginModule::scanDir(const QString& path, const QString& uri, const QStringList& otherUris, QByteArray& data,
    QSet<QString>& visited, int depth, PluginModuleStamps& stamps, QSet<QString>& seenFiles,
    PluginModuleScanStats* stats) {
    const QDir dir(path);
    const auto relativeDir = path == m_dir ? QStringLiteral(".") : QDir(m_dir).relativeFilePath(path);

    // Resolving to nothing means a broken or unreadable link, which has no contents to contribute
    const auto canonical = QFileInfo(path).canonicalFilePath();
    if (canonical.isEmpty()) {
        m_warnings.append(QStringLiteral("%1: cannot be resolved; likely a broken symlink or unreadable file, skipped.")
                .arg(relativeDir));
        return;
    }

    // Checked before anything is recorded, so a directory skipped for depth is not also claimed
    if (depth > kMaxDepth) {
        m_warnings.append(
            QStringLiteral("%1: nested more than %2 directories deep; skipped.").arg(relativeDir).arg(kMaxDepth));
        return;
    }

    // Stop walking if we find a visited directory (e.g. due to looped symlinks)
    if (visited.contains(canonical)) {
        // The canonical path rather than a relative one, since a link out of the tree has no
        // sensible relative form and the absolute target is what points at the culprit anyway.
        m_warnings.append(
            QStringLiteral("%1: already scanned as '%2'; likely a symlink loop, skipped.").arg(relativeDir, canonical));
        return;
    }

    visited.insert(canonical);

    m_watchPaths.append(path);
    data.append(uri.toUtf8());
    data.append('\n');

    // Sorted so the fingerprint only reflects the tree, not the order the filesystem hands it over
    const auto files = dir.entryList(QDir::Files, QDir::Name);

    // Collected first so a file can be checked against the types it could have referenced
    QStringList siblings;
    for (const auto& file : files)
        if (file.endsWith(QStringLiteral(".qml")) && !file.startsWith(u'.'))
            siblings.append(QFileInfo(file).completeBaseName());

    for (const auto& file : files) {
        if (file.startsWith(u'.')) // Skip hidden files
            continue;

        const auto filePath = dir.absoluteFilePath(file);
        const auto relative = QDir(m_dir).relativeFilePath(filePath);

        if (file == QStringLiteral("qmldir")) {
            m_warnings.append(
                QStringLiteral("%1: qmldirs are generated; manually specified ones are ignored.").arg(relative));
            continue;
        }

        if (file.endsWith(QStringLiteral(".js"))) {
            m_warnings.append(QStringLiteral(
                "%1: hot reloading is not supported for JavaScript files; put the logic in a QML singleton instead.")
                    .arg(relative));
            continue;
        }

        if (!file.endsWith(QStringLiteral(".qml"))) // Only QML files are tracked
            continue;

        const QFileInfo info(filePath);
        const auto mtimeMs = info.lastModified().toMSecsSinceEpoch();
        const auto size = info.size();
        const auto context = importContext(uri, siblings, otherUris);

        auto stamp = stamps.constFind(filePath);
        QByteArray hash;
        bool singleton = false;
        QStringList fileWarnings;

        if (stamp != stamps.cend() && stamp->mtimeMs == mtimeMs && stamp->size == size && stamp->context == context) {
            hash = stamp->hash;
            singleton = stamp->singleton;
            fileWarnings = stamp->warnings;

            if (stats)
                ++stats->filesReused;
        } else {
            QFile qml(filePath);
            if (!qml.open(QIODevice::ReadOnly)) {
                m_warnings.append(QStringLiteral("%1: failed to read file; %2").arg(relative, qml.errorString()));
                continue;
            }

            const auto bytes = qml.readAll();
            qml.close();

            hash = QCryptographicHash::hash(bytes, QCryptographicHash::Sha1);

            const auto content = QString::fromUtf8(bytes);
            singleton = hasSingletonPragma(content);
            fileWarnings = checkImports(filePath, uri, content, siblings, otherUris);

            stamps.insert(filePath, PluginModuleFileStamp{ mtimeMs, size, hash, singleton, context, fileWarnings });

            if (stats)
                ++stats->filesRead;
        }

        // Entry points are loaded by URL, so even a file that is not a type has to reload
        m_watchPaths.append(filePath);
        seenFiles.insert(filePath);

        data.append(relative.toUtf8());
        data.append('\0');
        data.append(hash);
        data.append('\0');

        m_warnings.append(fileWarnings);

        const auto name = QFileInfo(file).completeBaseName();

        // Qt only treats an uppercase base name as a type name; everything else can still be an
        // entry point or a Qt.createComponent target, but it cannot be registered.
        if (name.isEmpty() || !name.front().isUpper())
            continue;

        m_types.append({ uri, name, filePath, singleton });
    }

    const auto subdirs = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const auto& subdir : subdirs) {
        // Skips .git and friends, which would otherwise dominate the watch set
        if (subdir.startsWith(u'.'))
            continue;

        if (!isValidUriSegment(subdir)) {
            m_warnings.append(QStringLiteral(
                "%1: invalid subdirectory name; use only letters, digits and '_', and do not start with a digit. "
                "Nothing inside will be importable.")
                    .arg(subdir));
            continue;
        }

        scanDir(dir.absoluteFilePath(subdir), uri + u'.' + subdir, otherUris, data, visited, depth + 1, stamps,
            seenFiles, stats);
    }
}

QStringList PluginModule::checkImports(const QString& path, const QString& uri, const QString& content,
    const QStringList& siblings, const QStringList& otherUris) const {
    const auto relative = QDir(m_dir).relativeFilePath(path);
    QStringList warnings;

    for (const auto& other : otherUris) {
        if (!importPattern(other, true).match(content).hasMatch())
            continue;

        warnings.append(
            QStringLiteral("%1: cross-plugin imports are not supported; they will be available in a future update.")
                .arg(relative));
    }

    const auto hasSelfImport = importPattern(uri).match(content).hasMatch();
    if (hasSelfImport || siblings.size() < 2)
        return warnings;

    QStringList used;
    for (const auto& sibling : siblings) {
        if (sibling == QFileInfo(path).completeBaseName() || sibling.isEmpty() || !sibling.front().isUpper())
            continue;

        static const QString pattern = QStringLiteral("\\b%1\\b");
        if (QRegularExpression(pattern.arg(QRegularExpression::escape(sibling))).match(content).hasMatch())
            used.append(sibling);
    }

    if (!used.isEmpty())
        warnings.append(QStringLiteral("%1: implicit imports are disabled. To use %2, import '%3' explicitly.")
                .arg(relative, used.join(u'/'), uri));

    return warnings;
}

void PluginModule::registerTypes(int generation) const {
    for (const auto& type : m_types) {
        auto url = QUrl::fromLocalFile(type.path);
        url.setQuery(QStringLiteral("gen=%1").arg(generation));

        const auto uri = type.uri.toUtf8();
        const auto name = type.name.toUtf8();

        if (type.singleton)
            qmlRegisterSingletonType(url, uri.constData(), kModuleMajor, kModuleMinor, name.constData());
        else
            qmlRegisterType(url, uri.constData(), kModuleMajor, kModuleMinor, name.constData());
    }
}

} // namespace caelestia::plugins
