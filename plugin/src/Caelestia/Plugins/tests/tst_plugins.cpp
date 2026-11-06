#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QSignalSpy>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QtTest>
#include <memory>

#include "entrypoint.hpp"
#include "entrypointloader.hpp"
#include "pluginmanifest.hpp"
#include "plugins.hpp"
#include "settingmeta.hpp"
#include "settingsobject.hpp"

using namespace caelestia::plugins;

namespace {

class TestSubSettings : public SettingsObject {
    Q_OBJECT

    Q_PROPERTY(int x READ x WRITE setX NOTIFY xChanged)

public:
    using SettingsObject::SettingsObject;

    [[nodiscard]] int x() const { return m_x; }

    void setX(int x) {
        if (m_x == x)
            return;
        m_x = x;
        emit xChanged();
    }

signals:
    void xChanged();

private:
    int m_x = 1;
};

class TestDeclaresProperties : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString name READ name CONSTANT)

public:
    using QObject::QObject;

    [[nodiscard]] QString name() const { return QStringLiteral("own"); }
};

class TestSettings : public SettingsObject {
    Q_OBJECT

    Q_PROPERTY(int count READ count WRITE setCount NOTIFY countChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(caelestia::plugins::SettingsObject* sub READ sub CONSTANT)

public:
    using SettingsObject::SettingsObject;

    [[nodiscard]] int count() const { return m_count; }

    void setCount(int count) {
        if (m_count == count)
            return;
        m_count = count;
        emit countChanged();
    }

    [[nodiscard]] bool enabled() const { return m_enabled; }

    void setEnabled(bool enabled) {
        if (m_enabled == enabled)
            return;
        m_enabled = enabled;
        emit enabledChanged();
    }

    [[nodiscard]] SettingsObject* sub() { return &m_sub; }

signals:
    void countChanged();
    void enabledChanged();

private:
    int m_count = 3;
    bool m_enabled = true;
    TestSubSettings m_sub{ this };
};

} // namespace

class TestPlugins : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void init();
    void cleanup();

    void manifestParsesMetadata();
    void manifestAcceptsImageAsBanner();
    void manifestRejectsMissingName();
    void manifestRejectsEscapingPaths();
    void manifestRejectsAbsoluteEntryPoint();
    void manifestRejectsDuplicateEntryPointNames();
    void manifestRequiresNameForBarEntry();
    void manifestAcceptsSidebarPage();
    void manifestChecksRequires();
    void manifestReadsApiVersion();
    void manifestRejectsNewerApi();
    void dataDirFollowsId();
    void entryPointErrorsAreTracked();
    void injectedPropertiesOnlyUseOwnProperties();

    void settingsRoundTrip();
    void settingsChangedSignal();
    void settingsNestedPaths();
    void settingsValidatesValues();
    void settingsReportsMetaProblems();

    void configKeepsStateOnNonObjectRoot();
    void configKeepsStateOnBrokenJson();
    void configSavesJsonObject();
    void reloadPluginBumpsGeneration();
    void entryPointsFollowPluginChanges();
    void rescanOnlyTouchesTheEditedPlugin();
    void rewriteWithSameContentKeepsGeneration();
    void watcherRereadsAFileWhoseStatDidNotMove();
    void fiveEntryPointsReloadWithinAFrame();
    void removingATypeIsReportedAsUnfixable();

    void installRejectsIdMismatch();
    void installRejectsMissingRepository();
    void installSucceedsForLocalRepository();

private:
    [[nodiscard]] QString pluginsRoot() const { return m_root->path() + QStringLiteral("/plugins"); }

    [[nodiscard]] QString configPath() const {
        return m_root->path() + QStringLiteral("/config/caelestia/plugins.json");
    }

    [[nodiscard]] QString dataDir() const { return m_root->path() + QStringLiteral("/data/caelestia/plugins"); }

    QString writePlugin(const QString& dirName, const QByteArray& manifest) const;
    QString makeRepo(const QString& dirName, const QString& author, const QString& name) const;

    static void writeFile(const QString& path, const QByteArray& content) {
        QDir().mkpath(QFileInfo(path).absolutePath());
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(content);
    }

    static QByteArray readFile(const QString& path) {
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly))
            return {};
        return file.readAll();
    }

    std::unique_ptr<QTemporaryDir> m_root;
};

void TestPlugins::initTestCase() {
    m_root = std::make_unique<QTemporaryDir>();
    QVERIFY(m_root->isValid());

    // Everything the plugin system derives its paths from has to point into the temp root before
    // the first Plugins instance is constructed.
    qputenv("XDG_CONFIG_HOME", (m_root->path() + QStringLiteral("/config")).toUtf8());
    qputenv("XDG_DATA_HOME", (m_root->path() + QStringLiteral("/data")).toUtf8());
    qputenv("XDG_CACHE_HOME", (m_root->path() + QStringLiteral("/cache")).toUtf8());
    qunsetenv("CAELESTIA_PLUGIN_PATH");

    QDir().mkpath(m_root->path() + QStringLiteral("/config/caelestia"));
    QDir().mkpath(dataDir());
}

void TestPlugins::init() {
    QDir(pluginsRoot()).removeRecursively();
    QDir().mkpath(pluginsRoot());
    QFile::remove(configPath());
    QDir(dataDir()).removeRecursively();
    QDir().mkpath(dataDir());
}

void TestPlugins::cleanup() {
    QFile::remove(configPath());
}

QString TestPlugins::writePlugin(const QString& dirName, const QByteArray& manifest) const {
    const auto dir = pluginsRoot() + QLatin1Char('/') + dirName;
    QDir().mkpath(dir);

    QFile file(dir + QStringLiteral("/manifest.json"));
    if (!file.open(QIODevice::WriteOnly))
        return {};

    file.write(manifest);
    return dir;
}

QString TestPlugins::makeRepo(const QString& dirName, const QString& author, const QString& name) const {
    const auto dir = m_root->path() + QStringLiteral("/repos/") + dirName;
    QDir().mkpath(dir);

    writeFile(dir + QStringLiteral("/manifest.json"),
        QStringLiteral(R"({"name":"%1","author":"%2","version":"1.0.0"})").arg(name, author).toUtf8());

    QProcess::execute(QStringLiteral("git"), { QStringLiteral("init"), QStringLiteral("-q"), dir });
    QProcess::execute(QStringLiteral("git"), { QStringLiteral("-C"), dir, QStringLiteral("add"), QStringLiteral(".") });
    QProcess::execute(QStringLiteral("git"),
        { QStringLiteral("-C"), dir, QStringLiteral("-c"), QStringLiteral("user.email=test@example.com"),
            QStringLiteral("-c"), QStringLiteral("user.name=test"), QStringLiteral("commit"), QStringLiteral("-q"),
            QStringLiteral("-m"), QStringLiteral("test") });

    return dir;
}

void TestPlugins::manifestParsesMetadata() {
    const auto dir = writePlugin(QStringLiteral("meta"),
        R"({
            "name": "Widgets",
            "displayName": "Widgets Deluxe",
            "author": "SomeAuthor",
            "version": "1.2.3",
            "icon": "widgets",
            "description": "Does things",
            "tags": ["a", "a", "b", ""],
            "banner": "banner.png",
            "settings": "settings.qml",
            "entryPoints": [{"type": "desktop-widget", "source": "Widget.qml"}]
        })");

    const PluginManifest manifest(dir, dir + QStringLiteral("/manifest.json"));

    QVERIFY2(manifest.valid(), qUtf8Printable(manifest.error()));
    QCOMPARE(manifest.id(), QStringLiteral("someauthor/widgets"));
    QCOMPARE(manifest.moduleUri(), QStringLiteral("someauthor.widgets"));
    QCOMPARE(manifest.displayName(), QStringLiteral("Widgets Deluxe"));
    QCOMPARE(manifest.version(), QStringLiteral("1.2.3"));
    QCOMPARE(manifest.tags(), (QStringList{ QStringLiteral("a"), QStringLiteral("b") }));
    QCOMPARE(manifest.banner(), QStringLiteral("banner.png"));
    QCOMPARE(manifest.entryPoints().size(), 1);
    QCOMPARE(manifest.entryPoints().first().type(), EntryPointType::DesktopWidget);
}

void TestPlugins::manifestAcceptsImageAsBanner() {
    const auto dir = writePlugin(QStringLiteral("legacy"),
        R"({"name":"Legacy","author":"a","image":"preview.png","entryPoints":[{"type":"desktop-widget","source":"W.qml"}]})");

    const PluginManifest manifest(dir, dir + QStringLiteral("/manifest.json"));

    QVERIFY2(manifest.valid(), qUtf8Printable(manifest.error()));
    QCOMPARE(manifest.banner(), QStringLiteral("preview.png"));
    QCOMPARE(manifest.displayName(), QStringLiteral("Legacy"));
}

void TestPlugins::manifestRejectsMissingName() {
    const auto dir = writePlugin(QStringLiteral("noname"), R"({"author":"a"})");
    const PluginManifest manifest(dir, dir + QStringLiteral("/manifest.json"));

    QVERIFY(!manifest.valid());
    QVERIFY(manifest.hasParseError());
    QVERIFY(manifest.error().contains(QStringLiteral("name")));
}

void TestPlugins::manifestRejectsEscapingPaths() {
    const auto escapeSource = writePlugin(QStringLiteral("escape-source"),
        R"({"name":"Escape","author":"a","entryPoints":[{"type":"desktop-widget","source":"../Other/W.qml"}]})");
    const PluginManifest sourceManifest(escapeSource, escapeSource + QStringLiteral("/manifest.json"));
    QVERIFY(!sourceManifest.valid());
    QVERIFY(sourceManifest.error().contains(QStringLiteral("outside")));

    const auto escapeSettings = writePlugin(QStringLiteral("escape-settings"),
        R"({"name":"Escape","author":"a","settings":"../../settings.qml","entryPoints":[{"type":"desktop-widget","source":"W.qml"}]})");
    const PluginManifest settingsManifest(escapeSettings, escapeSettings + QStringLiteral("/manifest.json"));
    QVERIFY(!settingsManifest.valid());
    QVERIFY(settingsManifest.error().contains(QStringLiteral("settings")));
}

void TestPlugins::manifestRejectsAbsoluteEntryPoint() {
    const auto dir = writePlugin(QStringLiteral("absolute"),
        R"({"name":"Absolute","author":"a","entryPoints":[{"type":"desktop-widget","source":"/usr/share/x.qml"}]})");
    const PluginManifest manifest(dir, dir + QStringLiteral("/manifest.json"));

    QVERIFY(!manifest.valid());
    QVERIFY(manifest.error().contains(QStringLiteral("relative")));
}

void TestPlugins::manifestRejectsDuplicateEntryPointNames() {
    const auto dir = writePlugin(QStringLiteral("duplicates"),
        R"({
            "name": "Dup",
            "author": "a",
            "entryPoints": [
                {"type": "bar-entry", "source": "A.qml", "properties": {"name": "thing"}},
                {"type": "bar-entry", "source": "B.qml", "properties": {"name": "thing"}}
            ]
        })");
    const PluginManifest manifest(dir, dir + QStringLiteral("/manifest.json"));

    QVERIFY(!manifest.valid());
    QVERIFY(manifest.error().contains(QStringLiteral("Duplicate")));
}

void TestPlugins::manifestRequiresNameForBarEntry() {
    const auto dir = writePlugin(QStringLiteral("noname-entry"),
        R"({"name":"NoName","author":"a","entryPoints":[{"type":"quick-toggle","source":"T.qml"}]})");
    const PluginManifest manifest(dir, dir + QStringLiteral("/manifest.json"));

    QVERIFY(!manifest.valid());
    QVERIFY(manifest.error().contains(QStringLiteral("properties.name")));
}

void TestPlugins::manifestAcceptsSidebarPage() {
    const auto dir = writePlugin(QStringLiteral("sidebar-page"),
        R"({"name":"Pages","author":"a","entryPoints":[
            {"type":"sidebar-page","source":"Page.qml","properties":{"name":"page","title":"Page"}}
        ]})");
    const PluginManifest manifest(dir, dir + QStringLiteral("/manifest.json"));

    QVERIFY2(manifest.valid(), qUtf8Printable(manifest.error()));
    QCOMPARE(manifest.entryPoints().size(), 1);
    QCOMPARE(manifest.entryPoints().first().type(), EntryPointType::SidebarPage);
    QCOMPARE(manifest.entryPoints().first().properties().value(QStringLiteral("name")).toString(),
        QStringLiteral("page"));
}

void TestPlugins::manifestChecksRequires() {
    const auto satisfied = writePlugin(QStringLiteral("req-ok"),
        R"({"name":"Ok","author":"a","requires":">=2.5.0","entryPoints":[{"type":"desktop-widget","source":"W.qml"}]})");
    const PluginManifest ok(satisfied, satisfied + QStringLiteral("/manifest.json"));
    QVERIFY2(ok.valid(), qUtf8Printable(ok.error()));

    const auto unsatisfied = writePlugin(QStringLiteral("req-fail"),
        R"({"name":"Fail","author":"a","requires":">99.0.0","entryPoints":[{"type":"desktop-widget","source":"W.qml"}]})");
    const PluginManifest fail(unsatisfied, unsatisfied + QStringLiteral("/manifest.json"));
    QVERIFY(!fail.valid());
    QVERIFY(fail.error().contains(QStringLiteral("Requires")));
}

void TestPlugins::manifestReadsApiVersion() {
    const auto implicit = writePlugin(QStringLiteral("api-implicit"),
        R"({"name":"Implicit","author":"a","entryPoints":[{"type":"desktop-widget","source":"W.qml"}]})");
    const PluginManifest implicitManifest(implicit, implicit + QStringLiteral("/manifest.json"));
    QVERIFY2(implicitManifest.valid(), qUtf8Printable(implicitManifest.error()));
    QCOMPARE(implicitManifest.api(), 1);

    const auto explicitOne = writePlugin(QStringLiteral("api-one"),
        R"({"name":"One","author":"a","api":1,"entryPoints":[{"type":"desktop-widget","source":"W.qml"}]})");
    const PluginManifest one(explicitOne, explicitOne + QStringLiteral("/manifest.json"));
    QVERIFY2(one.valid(), qUtf8Printable(one.error()));
    QCOMPARE(one.api(), 1);

    // A string is accepted too, so `"api": "1"` does not silently mean unset
    const auto stringApi = writePlugin(QStringLiteral("api-string"),
        R"({"name":"String","author":"a","api":"1","entryPoints":[{"type":"desktop-widget","source":"W.qml"}]})");
    const PluginManifest stringManifest(stringApi, stringApi + QStringLiteral("/manifest.json"));
    QVERIFY2(stringManifest.valid(), qUtf8Printable(stringManifest.error()));
    QCOMPARE(stringManifest.api(), 1);
}

void TestPlugins::manifestRejectsNewerApi() {
    const auto dir = writePlugin(QStringLiteral("api-new"),
        R"({"name":"New","author":"a","api":2,"entryPoints":[{"type":"desktop-widget","source":"W.qml"}]})");
    const PluginManifest manifest(dir, dir + QStringLiteral("/manifest.json"));

    QVERIFY(!manifest.valid());
    QVERIFY(manifest.error().contains(QStringLiteral("plugin API 2")));

    const auto zero = writePlugin(QStringLiteral("api-zero"),
        R"({"name":"Zero","author":"a","api":0,"entryPoints":[{"type":"desktop-widget","source":"W.qml"}]})");
    const PluginManifest zeroManifest(zero, zero + QStringLiteral("/manifest.json"));
    QVERIFY(!zeroManifest.valid());
}

void TestPlugins::dataDirFollowsId() {
    const auto dir = writePlugin(QStringLiteral("datadir"),
        R"({"name":"DataDir","author":"SomeAuthor","entryPoints":[{"type":"desktop-widget","source":"W.qml"}]})");
    const PluginManifest manifest(dir, dir + QStringLiteral("/manifest.json"));
    QVERIFY2(manifest.valid(), qUtf8Printable(manifest.error()));

    const auto expected = m_root->path() + QStringLiteral("/data/caelestia/plugin-data/someauthor/datadir");
    QCOMPARE(manifest.dataDir(), expected);

    // Only created when the plugin asks for it
    QVERIFY(!QFileInfo::exists(expected));
    QCOMPARE(manifest.ensureDataDir(), expected);
    QVERIFY(QFileInfo(expected).isDir());
}

void TestPlugins::settingsRoundTrip() {
    TestSettings settings;
    settings.componentComplete();

    QCOMPARE(settings.toMap().value(QStringLiteral("count")).toInt(), 3);
    QCOMPARE(settings.toMap().value(QStringLiteral("enabled")).toBool(), true);

    settings.load({ { QStringLiteral("count"), 7 }, { QStringLiteral("enabled"), false },
        { QStringLiteral("sub"), QVariantMap{ { QStringLiteral("x"), 42 } } } });

    QCOMPARE(settings.count(), 7);
    QVERIFY(!settings.enabled());
    QCOMPARE(settings.toMap().value(QStringLiteral("sub")).toMap().value(QStringLiteral("x")).toInt(), 42);
    QVERIFY(settings.keys().contains(QStringLiteral("count")));
    QVERIFY(settings.keys().contains(QStringLiteral("enabled")));
    // Groups are flattened to dotted leaf paths so the default settings UI can render their rows
    QVERIFY(settings.keys().contains(QStringLiteral("sub.x")));
    QVERIFY(!settings.keys().contains(QStringLiteral("sub")));
    QCOMPARE(settings.flatValues().value(QStringLiteral("sub.x")).toInt(), 42);
    QCOMPARE(settings.values().value(QStringLiteral("sub")).toMap().value(QStringLiteral("x")).toInt(), 42);
}

void TestPlugins::settingsNestedPaths() {
    TestSettings settings;
    settings.sub()->componentComplete();
    settings.componentComplete();

    auto* const sub = qobject_cast<TestSubSettings*>(settings.sub());
    QVERIFY(sub);

    const QStringList expectedKeys{ QStringLiteral("count"), QStringLiteral("enabled"), QStringLiteral("sub.x") };
    QCOMPARE(settings.keys(), expectedKeys);
    QCOMPARE(settings.value(QStringLiteral("sub.x")).toInt(), 1);
    QVERIFY(settings.defaultValue(QStringLiteral("sub.x")).isValid());
    QCOMPARE(settings.defaultValue(QStringLiteral("sub.x")).toInt(), 1);
    QVERIFY(!settings.isModified(QStringLiteral("sub.x")));

    QVERIFY(settings.setValue(QStringLiteral("sub.x"), 9));
    QCOMPARE(sub->x(), 9);
    QVERIFY(settings.isModified(QStringLiteral("sub.x")));
    QCOMPARE(settings.flatValues().value(QStringLiteral("sub.x")).toInt(), 9);

    QVERIFY(settings.reset(QStringLiteral("sub.x")));
    QCOMPARE(sub->x(), 1);
    QVERIFY(!settings.isModified(QStringLiteral("sub.x")));

    QVERIFY(settings.setValue(QStringLiteral("count"), 8));
    QVERIFY(settings.isModified(QStringLiteral("count")));
    settings.resetAll();
    QCOMPARE(settings.count(), 3);
    QVERIFY(!settings.isModified(QStringLiteral("count")));
}

void TestPlugins::settingsValidatesValues() {
    TestSettings settings;
    settings.sub()->componentComplete();
    settings.componentComplete();

    auto* const sub = qobject_cast<TestSubSettings*>(settings.sub());
    QVERIFY(sub);

    SettingMeta countMeta;
    settings.registerMeta(QStringLiteral("count"), &countMeta);
    countMeta.setMin(1);
    countMeta.setMax(5);

    settings.load({ { QStringLiteral("count"), 99 }, { QStringLiteral("enabled"), QStringLiteral("nope") },
        { QStringLiteral("sub"), QVariantMap{ { QStringLiteral("x"), QStringLiteral("nope") } } } });

    // Out of range values are clamped; wrong types keep the declared default
    QCOMPARE(settings.count(), 5);
    QCOMPARE(settings.enabled(), true);
    QCOMPARE(sub->x(), 1);

    const auto warnings = settings.warnings().join(QLatin1Char('\n'));
    QVERIFY2(warnings.contains(QStringLiteral("count: 99 is outside [1, 5], using 5")), qPrintable(warnings));
    QVERIFY2(warnings.contains(QStringLiteral("enabled: expected a boolean")), qPrintable(warnings));
    QVERIFY2(warnings.contains(QStringLiteral("sub.x: expected an integer")), qPrintable(warnings));

    // A valid load replaces the warnings and accepts negative ranges and a max of zero
    SettingMeta offsetMeta;
    settings.registerMeta(QStringLiteral("count"), &offsetMeta);
    offsetMeta.setMin(-10);
    offsetMeta.setMax(0);

    settings.load({ { QStringLiteral("count"), -4 } });
    QCOMPARE(settings.count(), -4);
    QVERIFY(settings.warnings().isEmpty());

    settings.load({ { QStringLiteral("count"), -20 } });
    QCOMPARE(settings.count(), -10);
    QVERIFY(settings.warnings().join(QLatin1Char('\n')).contains(QStringLiteral("using -10")));
}

void TestPlugins::settingsReportsMetaProblems() {
    TestSettings settings;
    settings.sub()->componentComplete();
    settings.componentComplete();

    SettingMeta meta;
    settings.registerMeta(QStringLiteral("enabled"), &meta);
    meta.setProperty("inputType", QVariant::fromValue(static_cast<int>(SettingMeta::Slider)));
    meta.setMin(10);
    meta.setMax(1);

    const auto warnings = settings.warnings().join(QLatin1Char('\n'));
    QVERIFY2(warnings.contains(QStringLiteral("enabled: slider input needs a numeric property")), qPrintable(warnings));
    QVERIFY2(warnings.contains(QStringLiteral("enabled: min (10) is greater than max (1)")), qPrintable(warnings));

    QVERIFY(meta.hasMin());
    QVERIFY(meta.hasMax());

    // A dropdown is an option list too, so it reports the same problem when it has none
    SettingMeta dropdown;
    dropdown.setProperty("inputType", QVariant::fromValue(static_cast<int>(SettingMeta::Dropdown)));
    settings.registerMeta(QStringLiteral("sub"), &dropdown);
    QVERIFY2(settings.warnings().join(QLatin1Char('\n')).contains(QStringLiteral("sub: dropdown needs options")),
        qPrintable(settings.warnings().join(QLatin1Char('\n'))));

    SettingMeta unset;
    QVERIFY(!unset.hasMin());
    QVERIFY(!unset.hasMax());
    unset.setMax(0);
    QVERIFY(unset.hasMax());
    QCOMPARE(unset.max(), 0);
}

void TestPlugins::settingsChangedSignal() {
    TestSettings settings;
    settings.componentComplete();

    QSignalSpy spy(&settings, &SettingsObject::changed);
    settings.setCount(8);
    QCOMPARE(spy.count(), 1);

    settings.setCount(8);
    QCOMPARE(spy.count(), 1);
}

void TestPlugins::configKeepsStateOnNonObjectRoot() {
    writeFile(configPath(), R"({"enabled":["a/b"],"path":[],"settings":{"a/b":{"x":1}}})");

    Plugins plugins;
    plugins.componentComplete();

    QVERIFY(plugins.enabled().contains(QStringLiteral("a/b")));

    writeFile(configPath(), "[]");
    plugins.reload();

    QVERIFY(plugins.enabled().contains(QStringLiteral("a/b")));
    QCOMPARE(readFile(configPath()).trimmed(), QByteArray("[]"));
}

void TestPlugins::configKeepsStateOnBrokenJson() {
    writeFile(configPath(), R"({"enabled":["a/b"]})");

    Plugins plugins;
    plugins.componentComplete();
    QVERIFY(plugins.enabled().contains(QStringLiteral("a/b")));

    writeFile(configPath(), "{not json");
    plugins.reload();
    QVERIFY(plugins.enabled().contains(QStringLiteral("a/b")));
}

void TestPlugins::configSavesJsonObject() {
    Plugins plugins;
    plugins.componentComplete();

    plugins.setEnabled({ QStringLiteral("author/plugin") });

    QTRY_VERIFY_WITH_TIMEOUT(QFile::exists(configPath()), 3000);

    const auto doc = QJsonDocument::fromJson(readFile(configPath()));
    QVERIFY(doc.isObject());
    QCOMPARE(
        doc.object().value(QStringLiteral("enabled")).toArray().first().toString(), QStringLiteral("author/plugin"));
    QVERIFY(doc.object().value(QStringLiteral("settings")).isObject());
}

void TestPlugins::reloadPluginBumpsGeneration() {
    const auto id = QStringLiteral("author/reload");
    const auto dir = dataDir() + QStringLiteral("/reload");
    QDir().mkpath(dir);
    writeFile(dir + QStringLiteral("/manifest.json"),
        R"({"name":"reload","author":"author","entryPoints":[{"type":"desktop-widget","source":"W.qml"}]})");
    writeFile(dir + QStringLiteral("/W.qml"), "import QtQuick\n\nItem {}\n");
    writeFile(configPath(), R"({"enabled":["author/reload"]})");

    Plugins plugins;
    plugins.componentComplete();

    PluginManifest* manifest = nullptr;
    for (const auto& entry : plugins.plugins()) {
        auto* const candidate = entry.value<PluginManifest*>();
        if (candidate && candidate->id() == id)
            manifest = candidate;
    }

    QVERIFY(manifest);
    QVERIFY(manifest->valid());
    QVERIFY(manifest->enabled());

    // Enabled plugins are registered on the first scan, so they already have a generation
    QVERIFY(manifest->generation() > 0);
    const int before = manifest->generation();

    plugins.reloadPlugin(id);
    QVERIFY(manifest->generation() > before);

    // Unknown ids warn instead of crashing
    plugins.reloadPlugin(QStringLiteral("nobody/nothing"));
}

void TestPlugins::entryPointsFollowPluginChanges() {
    const auto id = QStringLiteral("author/points");
    const auto dir = dataDir() + QStringLiteral("/points");
    QDir().mkpath(dir);
    writeFile(dir + QStringLiteral("/manifest.json"),
        R"({"name":"points","author":"author","entryPoints":[
            {"type":"bar-entry","source":"B.qml","properties":{"name":"bar"}},
            {"type":"status-icon","source":"S.qml","properties":{"name":"status"}}
        ]})");
    writeFile(dir + QStringLiteral("/B.qml"), "import QtQuick\n\nItem {}\n");
    writeFile(dir + QStringLiteral("/S.qml"), "import QtQuick\n\nItem {}\n");
    writeFile(configPath(), R"({"enabled":["author/points"]})");

    Plugins plugins;
    plugins.componentComplete();

    QCOMPARE(plugins.__entryPoints(EntryPointType::BarEntry).size(), 1);
    QCOMPARE(
        plugins.__entryPoints(EntryPointType::BarEntry).first().properties().value(QStringLiteral("name")).toString(),
        QStringLiteral("bar"));
    QCOMPARE(plugins.__entryPoints(EntryPointType::StatusIcon).size(), 1);

    // The lists are cached per revision, so an edited manifest has to be visible to the next call
    writeFile(dir + QStringLiteral("/manifest.json"),
        R"({"name":"points","author":"author","entryPoints":[
            {"type":"status-icon","source":"S.qml","properties":{"name":"status"}},
            {"type":"status-icon","source":"B.qml","properties":{"name":"status2"}}
        ]})");
    plugins.reloadPlugin(id);

    QCOMPARE(plugins.__entryPoints(EntryPointType::BarEntry).size(), 0);
    QCOMPARE(plugins.__entryPoints(EntryPointType::StatusIcon).size(), 2);

    // Disabling drops them without touching the files
    plugins.setPluginEnabled(id, false);
    QCOMPARE(plugins.__entryPoints(EntryPointType::StatusIcon).size(), 0);
}

namespace {

// Generation and counters of the first pass the watcher triggers after a file edit. Watches are
// collected rather than read from the property, since the burst that follows one save can produce
// a second pass whose counters would hide the one the test is about.
struct WatcherPass {
    QList<QVariantMap> passes;

    explicit WatcherPass(Plugins& plugins) {
        QObject::connect(&plugins, &Plugins::scanStatsChanged, &plugins, [this, &plugins] {
            if (plugins.scanStats().value(QStringLiteral("trigger")).toString() == QStringLiteral("watch"))
                passes.append(plugins.scanStats());
        });
    }

    [[nodiscard]] QVariantMap first() const { return passes.value(0); }
};

} // namespace

void TestPlugins::rescanOnlyTouchesTheEditedPlugin() {
    const auto aId = QStringLiteral("author/alpha");
    const auto bId = QStringLiteral("author/beta");

    for (const auto& name : { QStringLiteral("alpha"), QStringLiteral("beta") }) {
        const auto dir = dataDir() + QLatin1Char('/') + name;
        QDir().mkpath(dir);
        writeFile(dir + QStringLiteral("/manifest.json"),
            QStringLiteral(
                R"({"name":"%1","author":"author","entryPoints":[{"type":"desktop-widget","source":"W.qml"}]})")
                .arg(name)
                .toUtf8());
        writeFile(dir + QStringLiteral("/W.qml"), "import QtQuick\n\nItem {}\n");
        writeFile(dir + QStringLiteral("/Extra.qml"), "import QtQuick\n\nItem {}\n");
    }

    writeFile(configPath(), R"({"enabled":["author/alpha","author/beta"]})");

    Plugins plugins;
    plugins.componentComplete();

    PluginManifest* alpha = nullptr;
    PluginManifest* beta = nullptr;
    for (const auto& entry : plugins.plugins()) {
        auto* const candidate = entry.value<PluginManifest*>();
        if (!candidate)
            continue;
        if (candidate->id() == aId)
            alpha = candidate;
        else if (candidate->id() == bId)
            beta = candidate;
    }

    QVERIFY(alpha);
    QVERIFY(beta);

    const int alphaBefore = alpha->generation();
    const int betaBefore = beta->generation();
    QVERIFY(alphaBefore > 0);
    QVERIFY(betaBefore > 0);

    WatcherPass pass(plugins);

    // One plugin's file moves; the other must not be scanned at all
    writeFile(dataDir() + QStringLiteral("/beta/W.qml"), "import QtQuick\n\nItem {\n    property int x: 1\n}\n");

    QTRY_VERIFY_WITH_TIMEOUT(!pass.passes.isEmpty(), 5000);

    const auto first = pass.first();
    QCOMPARE(first.value(QStringLiteral("modulesScanned")).toInt(), 1);
    QCOMPARE(first.value(QStringLiteral("scanned")).toStringList(), QStringList{ bId });
    QCOMPARE(first.value(QStringLiteral("filesRead")).toInt(), 1);
    QCOMPARE(first.value(QStringLiteral("filesReused")).toInt(), 1);

    QVERIFY(beta->generation() > betaBefore);
    QCOMPARE(alpha->generation(), alphaBefore);
}

void TestPlugins::rewriteWithSameContentKeepsGeneration() {
    const auto id = QStringLiteral("author/touch");
    const auto dir = dataDir() + QStringLiteral("/touch");
    QDir().mkpath(dir);
    writeFile(dir + QStringLiteral("/manifest.json"),
        R"({"name":"touch","author":"author","entryPoints":[{"type":"desktop-widget","source":"W.qml"}]})");
    writeFile(dir + QStringLiteral("/W.qml"), "import QtQuick\n\nItem {}\n");
    writeFile(configPath(), R"({"enabled":["author/touch"]})");

    Plugins plugins;
    plugins.componentComplete();

    PluginManifest* manifest = nullptr;
    for (const auto& entry : plugins.plugins()) {
        auto* const candidate = entry.value<PluginManifest*>();
        if (candidate && candidate->id() == id)
            manifest = candidate;
    }

    QVERIFY(manifest);
    const int before = manifest->generation();
    QVERIFY(before > 0);

    WatcherPass pass(plugins);

    // Same bytes, newer mtime. The stamp misses, so the file is read again, but the hash matches
    // the one in the fingerprint and re-registering would be a no-op.
    const auto path = dir + QStringLiteral("/W.qml");
    writeFile(path, "import QtQuick\n\nItem {}\n");

    QFile file(path);
    QVERIFY(file.open(QIODevice::ReadWrite));
    QVERIFY(file.setFileTime(QDateTime::currentDateTime().addSecs(2), QFileDevice::FileModificationTime));
    file.close();

    QTRY_VERIFY_WITH_TIMEOUT(!pass.passes.isEmpty(), 5000);

    const auto first = pass.first();
    QCOMPARE(first.value(QStringLiteral("scanned")).toStringList(), QStringList{ id });
    QCOMPARE(first.value(QStringLiteral("filesRead")).toInt(), 1);
    QCOMPARE(first.value(QStringLiteral("filesReused")).toInt(), 0);

    QCOMPARE(manifest->generation(), before);
}

void TestPlugins::watcherRereadsAFileWhoseStatDidNotMove() {
    const auto id = QStringLiteral("author/samestat");
    const auto dir = dataDir() + QStringLiteral("/samestat");
    QDir().mkpath(dir);

    const auto path = dir + QStringLiteral("/W.qml");
    const QByteArray first = "import QtQuick\n\nItem { property int a: 1 }\n";
    const QByteArray second = "import QtQuick\n\nItem { property int a: 2 }\n";
    QCOMPARE(first.size(), second.size());

    writeFile(dir + QStringLiteral("/manifest.json"),
        R"({"name":"samestat","author":"author","entryPoints":[{"type":"desktop-widget","source":"W.qml"}]})");
    writeFile(path, first);
    writeFile(configPath(), R"({"enabled":["author/samestat"]})");

    Plugins plugins;
    plugins.componentComplete();

    PluginManifest* manifest = nullptr;
    for (const auto& entry : plugins.plugins()) {
        auto* const candidate = entry.value<PluginManifest*>();
        if (candidate && candidate->id() == id)
            manifest = candidate;
    }

    QVERIFY(manifest);
    const int before = manifest->generation();
    QVERIFY(before > 0);

    WatcherPass pass(plugins);

    // Same length, and the mtime is put back to what it was, so the stamp matches on both fields
    // while the content differs. Only the watcher knows the file changed.
    QFileInfo info(path);
    const auto mtime = info.lastModified();
    writeFile(path, second);

    QFile file(path);
    QVERIFY(file.open(QIODevice::ReadWrite));
    QVERIFY(file.setFileTime(mtime, QFileDevice::FileModificationTime));
    file.close();

    QTRY_VERIFY_WITH_TIMEOUT(!pass.passes.isEmpty(), 5000);

    const auto firstPass = pass.first();
    QCOMPARE(firstPass.value(QStringLiteral("scanned")).toStringList(), QStringList{ id });
    QCOMPARE(firstPass.value(QStringLiteral("filesRead")).toInt(), 1);
    QVERIFY(manifest->generation() > before);
}

void TestPlugins::fiveEntryPointsReloadWithinAFrame() {
    // Synthetic fixture for the "a reload must not drop a frame" rule: five entry points, each
    // with its own source, and repeated reloads. What blocks the GUI thread is the synchronous
    // part of the pass (discovery, the plugin's scan, re-registering its types) - compiling the
    // entry points themselves is asynchronous and does not show up here.
    const auto id = QStringLiteral("author/five");
    const auto dir = dataDir() + QStringLiteral("/five");
    QDir().mkpath(dir);

    QStringList entryPoints;
    for (int i = 0; i < 5; ++i) {
        entryPoints.append(
            QStringLiteral(R"({"type":"bar-entry","source":"E%1.qml","properties":{"name":"e%1"}})").arg(i));
        writeFile(dir + QStringLiteral("/E%1.qml").arg(i), "import QtQuick\n\nItem {}\n");
    }

    writeFile(dir + QStringLiteral("/manifest.json"),
        QStringLiteral(R"({"name":"five","author":"author","entryPoints":[%1]})").arg(entryPoints.join(u',')).toUtf8());
    writeFile(configPath(), R"({"enabled":["author/five"]})");

    Plugins plugins;
    plugins.componentComplete();

    PluginManifest* manifest = nullptr;
    for (const auto& entry : plugins.plugins()) {
        auto* const candidate = entry.value<PluginManifest*>();
        if (candidate && candidate->id() == id)
            manifest = candidate;
    }

    QVERIFY(manifest);
    QCOMPARE(plugins.__entryPoints(EntryPointType::BarEntry).size(), 5);

    const int before = manifest->generation();
    int worst = 0;

    for (int i = 0; i < 10; ++i) {
        writeFile(dir + QStringLiteral("/E1.qml"),
            QStringLiteral("import QtQuick\n\nItem {\n    property int round: %1\n}\n").arg(i).toUtf8());

        // reloadPlugin is the explicit path: it must not trust a stamp, so all five are read.
        // The stamp fast path is what rescanOnlyTouchesTheEditedPlugin covers.
        plugins.reloadPlugin(id);

        const auto stats = plugins.scanStats();
        QCOMPARE(stats.value(QStringLiteral("trigger")).toString(), QStringLiteral("reload-plugin"));
        QCOMPARE(stats.value(QStringLiteral("partial")).toBool(), true);
        QCOMPARE(stats.value(QStringLiteral("modulesScanned")).toInt(), 1);
        QCOMPARE(stats.value(QStringLiteral("scanned")).toStringList(), QStringList{ id });
        QCOMPARE(stats.value(QStringLiteral("filesRead")).toInt(), 5);

        worst = qMax(worst, stats.value(QStringLiteral("durationMs")).toInt());
    }

    // 16 ms is one frame at 60 Hz; a five file scan against a temp dir is a fraction of that
    QVERIFY2(worst < 16, qPrintable(QStringLiteral("worst reload took %1 ms").arg(worst)));
    QCOMPARE(manifest->generation(), before + 10);
}

void TestPlugins::removingATypeIsReportedAsUnfixable() {
    const auto id = QStringLiteral("author/leak");
    const auto dir = dataDir() + QStringLiteral("/leak");
    QDir().mkpath(dir);

    writeFile(dir + QStringLiteral("/manifest.json"),
        R"({"name":"leak","author":"author","entryPoints":[{"type":"desktop-widget","source":"A.qml"}]})");
    writeFile(dir + QStringLiteral("/A.qml"), "import QtQuick\n\nItem {}\n");
    writeFile(dir + QStringLiteral("/B.qml"), "import QtQuick\n\nItem {}\n");
    writeFile(configPath(), R"({"enabled":["author/leak"]})");

    Plugins plugins;
    plugins.componentComplete();

    PluginManifest* manifest = nullptr;
    for (const auto& entry : plugins.plugins()) {
        auto* const candidate = entry.value<PluginManifest*>();
        if (candidate && candidate->id() == id)
            manifest = candidate;
    }

    QVERIFY(manifest);
    QVERIFY(manifest->warnings().isEmpty());

    // Qt keeps the registration, so the type stays resolvable against a file that is gone. The
    // plugin has to say so instead of silently leaving broken imports behind.
    QVERIFY(QFile::remove(dir + QStringLiteral("/B.qml")));
    plugins.reloadPlugin(id);

    const auto warnings = manifest->warnings().join(u' ');
    QVERIFY2(warnings.contains(QStringLiteral("Registered QML types are gone: B")), qPrintable(warnings));
    QVERIFY(warnings.contains(QStringLiteral("restart")));
}

void TestPlugins::entryPointErrorsAreTracked() {
    const auto dir = writePlugin(QStringLiteral("errors"),
        R"({"name":"Errors","author":"a","entryPoints":[{"type":"desktop-widget","source":"W.qml"}]})");
    PluginManifest manifest(dir, dir + QStringLiteral("/manifest.json"));
    QSignalSpy spy(&manifest, &PluginManifest::entryPointErrorsChanged);

    manifest.setEntryPointError(1, QStringLiteral("first failure"));
    manifest.setEntryPointError(2, QStringLiteral("second failure"));
    QCOMPARE(spy.count(), 2);
    QCOMPARE(manifest.entryPointErrors(),
        (QStringList{ QStringLiteral("first failure"), QStringLiteral("second failure") }));

    // Re-reporting the same message for the same loader is not a change
    manifest.setEntryPointError(1, QStringLiteral("first failure"));
    QCOMPARE(spy.count(), 2);

    // Several live copies of one entry point with the same problem collapse into one row
    manifest.setEntryPointError(3, QStringLiteral("first failure"));
    QCOMPARE(manifest.entryPointErrors(),
        (QStringList{ QStringLiteral("first failure"), QStringLiteral("second failure") }));

    manifest.clearEntryPointError(1);
    manifest.clearEntryPointError(3);
    QCOMPARE(manifest.entryPointErrors(), (QStringList{ QStringLiteral("second failure") }));

    // A new generation recreates every loader, so old failures must not linger
    manifest.setGeneration(manifest.generation() + 1);
    QVERIFY(manifest.entryPointErrors().isEmpty());
}

void TestPlugins::injectedPropertiesOnlyUseOwnProperties() {
    TestDeclaresProperties object;

    // Declared by the object itself: manifest properties may be injected.
    QVERIFY(EntryPointLoader::declaresProperty(&object, QStringLiteral("name")));
    // Inherited from QObject: `properties.layer`-style host metadata must not overwrite base
    // properties (the real bug: Item.layer silently swallowed the desktop-widget layer value).
    QVERIFY(!EntryPointLoader::declaresProperty(&object, QStringLiteral("objectName")));
    // Not a property at all.
    QVERIFY(!EntryPointLoader::declaresProperty(&object, QStringLiteral("layer")));
    QVERIFY(!EntryPointLoader::declaresProperty(nullptr, QStringLiteral("name")));
}

void TestPlugins::installRejectsIdMismatch() {
    if (QStandardPaths::findExecutable(QStringLiteral("git")).isEmpty())
        QSKIP("git is not installed");

    const auto repo = makeRepo(QStringLiteral("mismatch"), QStringLiteral("actual"), QStringLiteral("plugin"));

    Plugins plugins;
    plugins.componentComplete();

    QSignalSpy spy(&plugins, &Plugins::installFinished);
    plugins.installPlugin(repo, {}, QStringLiteral("expected/plugin"));

    QTRY_COMPARE_WITH_TIMEOUT(spy.count(), 1, 20000);
    QCOMPARE(spy.first().at(1).toBool(), false);
    QVERIFY(spy.first().at(2).toString().contains(QStringLiteral("expected/plugin")));
    QVERIFY(!QFileInfo::exists(dataDir() + QStringLiteral("/expected-plugin")));
    QVERIFY(!plugins.installing());
}

void TestPlugins::installRejectsMissingRepository() {
    Plugins plugins;
    plugins.componentComplete();

    QSignalSpy spy(&plugins, &Plugins::installFinished);
    plugins.installPlugin(m_root->path() + QStringLiteral("/does-not-exist"), {}, QStringLiteral("a/b"));

    QTRY_COMPARE_WITH_TIMEOUT(spy.count(), 1, 20000);
    QCOMPARE(spy.first().at(1).toBool(), false);
    QVERIFY(!spy.first().at(2).toString().isEmpty());
    QVERIFY(!plugins.installing());
}

void TestPlugins::installSucceedsForLocalRepository() {
    if (QStandardPaths::findExecutable(QStringLiteral("git")).isEmpty())
        QSKIP("git is not installed");

    const auto repo = makeRepo(QStringLiteral("good"), QStringLiteral("author"), QStringLiteral("plugin"));

    Plugins plugins;
    plugins.componentComplete();

    QSignalSpy spy(&plugins, &Plugins::installFinished);
    plugins.installPlugin(repo, {}, QStringLiteral("author/plugin"));

    QTRY_COMPARE_WITH_TIMEOUT(spy.count(), 1, 20000);
    QVERIFY2(spy.first().at(1).toBool(), qUtf8Printable(spy.first().at(2).toString()));
    QVERIFY(QFile::exists(dataDir() + QStringLiteral("/author-plugin/manifest.json")));

    bool found = false;
    for (const auto& entry : plugins.plugins()) {
        auto* const plugin = entry.value<PluginManifest*>();
        QVERIFY(plugin);

        if (plugin->id() != QStringLiteral("author/plugin"))
            continue;

        found = true;

        // Installing never enables: plugins run arbitrary QML, so enabling stays a deliberate act
        QVERIFY(!plugin->enabled());
    }

    QVERIFY(found);
    QVERIFY(!plugins.enabled().contains(QStringLiteral("author/plugin")));
}

QTEST_GUILESS_MAIN(TestPlugins)

#include "tst_plugins.moc"
