#pragma once

#include <qbytearray.h>
#include <qhash.h>
#include <qlist.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qstring.h>
#include <qstringlist.h>
#include <qvariant.h>

#include "entrypoint.hpp"

namespace caelestia::plugins {

// Bumped whenever the QML-facing plugin API changes in a way plugins must know about. Manifests
// declare the version they were written against with `api`; a manifest without it is API 1.
inline constexpr int kPluginApiVersion = 1;

class SettingsObject;

class PluginManifest : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("PluginManifest is created by Plugins")
    Q_MOC_INCLUDE("settingsobject.hpp")

    // Generated from author/name, lowercased
    Q_PROPERTY(QString id READ id NOTIFY idChanged)

    // The URI of the QML module holding this plugin's types, i.e. the id with '.' for '/'
    Q_PROPERTY(QString moduleUri READ moduleUri NOTIFY moduleUriChanged)

    // Required metadata
    Q_PROPERTY(QString name READ name NOTIFY nameChanged)
    Q_PROPERTY(QString version READ version NOTIFY versionChanged)

    // The plugin API version the manifest was written against, 1 when it does not say
    Q_PROPERTY(int api READ api NOTIFY apiChanged)

    // Optional metadata
    Q_PROPERTY(QString icon READ icon NOTIFY iconChanged)
    Q_PROPERTY(QString description READ description NOTIFY descriptionChanged)
    Q_PROPERTY(QString author READ author NOTIFY authorChanged)
    Q_PROPERTY(QString requires READ requirement NOTIFY requirementChanged)
    Q_PROPERTY(QStringList tags READ tags NOTIFY tagsChanged)

    // Optional card artwork. The raw values are relative to the manifest directory (or absolute
    // URLs); the Source variants resolve them for use in Image.source and are generation stamped.
    Q_PROPERTY(QString banner READ banner NOTIFY bannerChanged)
    Q_PROPERTY(QString logo READ logo NOTIFY logoChanged)
    Q_PROPERTY(QString bannerSource READ bannerSource NOTIFY bannerSourceChanged)
    Q_PROPERTY(QString logoSource READ logoSource NOTIFY logoSourceChanged)

    // Other props. The directory is the manifest's identity and never changes.
    Q_PROPERTY(QString dir READ dir CONSTANT)

    // Writable directory owned by this plugin, outside its checkout so reinstalling keeps state
    Q_PROPERTY(QString dataDir READ dataDir NOTIFY dataDirChanged)
    Q_PROPERTY(QList<caelestia::plugins::EntryPoint> entryPoints READ entryPoints NOTIFY entryPointsChanged)
    Q_PROPERTY(bool valid READ valid NOTIFY validChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(bool enabled READ enabled NOTIFY enabledChanged)

    // Non fatal complaints about the plugin's layout, recomputed on every scan. Unlike `error`
    // these do not stop it loading, they just tell the author something will not work.
    Q_PROPERTY(QStringList warnings READ warnings NOTIFY warningsChanged)

    // Failures reported by live entry-point loaders (component errors, uninitialised required
    // properties). One entry per failing loader, deduplicated and cleared on reload.
    Q_PROPERTY(QStringList entryPointErrors READ entryPointErrors NOTIFY entryPointErrorsChanged)

    // The plugin's current hot reload generation, allocated and bumped by Plugins. Everything
    // loaded from a plugin stamps this onto its URL, so a bump makes Qt compile fresh units
    // instead of returning the ones it cached by URL.
    Q_PROPERTY(int generation READ generation NOTIFY generationChanged)

    // Settings
    Q_PROPERTY(QString settingsSource READ settingsSource NOTIFY settingsSourceChanged)
    Q_PROPERTY(QString settingsUiSource READ settingsUiSource NOTIFY settingsUiSourceChanged)
    Q_PROPERTY(caelestia::plugins::SettingsObject* settings READ settings NOTIFY settingsChanged)

public:
    PluginManifest(const QString& dir, const QString& path, QObject* parent = nullptr);

    [[nodiscard]] QString id() const;
    [[nodiscard]] QString moduleUri() const;

    [[nodiscard]] QString name() const;
    [[nodiscard]] QString version() const;
    [[nodiscard]] int api() const;

    [[nodiscard]] QString icon() const;
    [[nodiscard]] QString description() const;
    [[nodiscard]] QString author() const;
    [[nodiscard]] QString requirement() const;
    [[nodiscard]] QStringList tags() const;
    [[nodiscard]] QString banner() const;
    [[nodiscard]] QString logo() const;
    [[nodiscard]] QString bannerSource() const;
    [[nodiscard]] QString logoSource() const;

    [[nodiscard]] QString dir() const;

    // `<XDG_DATA>/caelestia/plugin-data/<author>/<name>`, created on demand. Kept out of the
    // install directory so a reinstall or update does not wipe the plugin's state.
    [[nodiscard]] QString dataDir() const;
    [[nodiscard]] Q_INVOKABLE QString ensureDataDir() const;

    [[nodiscard]] QList<EntryPoint> entryPoints() const;
    [[nodiscard]] bool valid() const;
    [[nodiscard]] QString error() const;

    [[nodiscard]] bool enabled() const;
    void setEnabled(bool enabled);

    [[nodiscard]] QStringList warnings() const;
    void setWarnings(const QStringList& warnings);

    [[nodiscard]] QStringList entryPointErrors() const;

    // Reports a failure for one loader instance. An empty message clears it. Keyed by loader so a
    // plugin with several live copies (one desktop widget per screen) does not lose failures.
    void setEntryPointError(quintptr loaderId, const QString& message);
    void clearEntryPointError(quintptr loaderId);
    void clearEntryPointErrors();

    [[nodiscard]] int generation() const;

    // Adopts a new generation: rebuilds the settings object from the newly stamped source, then
    // notifies. Everything reading a plugin URL derives it at that point from the new value, so
    // one synchronous fan-out repoints every live loader onto the same generation.
    void setGeneration(int generation);

    // Absolute, generation stamped URL for a path declared in the manifest relative to dir().
    // Never stored anywhere: a cached copy would outlive its generation.
    [[nodiscard]] Q_INVOKABLE QString sourceUrl(const QString& source) const;

    // The raw `settings`/`settingsUi` paths as declared, i.e. relative and without a generation
    [[nodiscard]] QString declaredSettings() const;
    [[nodiscard]] QString declaredSettingsUi() const;

    [[nodiscard]] QString settingsSource() const;
    [[nodiscard]] QString settingsUiSource() const;

    // Lazily instantiates the plugin's SettingsObject on first access (null if it declares none)
    [[nodiscard]] SettingsObject* settings();

    void loadSettings(const QVariantMap& settings);
    [[nodiscard]] QVariantMap settingsValues() const;

    // True between a change to this plugin's SettingsObject and the write that persists it.
    // While set, the live object is newer than plugins.json and must not be reloaded from it.
    [[nodiscard]] bool hasUnsavedSettings() const;
    void markSettingsSaved();

    // Re-reads manifest.json in place, emitting a change signal for each field that moved.
    // Keeps the object (and therefore its SettingsObject) alive across a rescan.
    void reparse();

    // True when the manifest itself failed to parse or validate, independent of any id clash.
    [[nodiscard]] bool hasParseError() const;

    // The directories of the other plugins declaring this plugin's id. A contested id invalidates
    // every claimant, so this is set on all of them, not just the ones found later. Reversible:
    // recomputed on every scan, since removing a claimant revalidates the rest.
    void setConflicts(const QStringList& dirs);

signals:
    void idChanged();
    void moduleUriChanged();
    void dataDirChanged();
    void nameChanged();
    void versionChanged();
    void apiChanged();
    void iconChanged();
    void descriptionChanged();
    void authorChanged();
    void requirementChanged();
    void tagsChanged();
    void bannerChanged();
    void logoChanged();
    void bannerSourceChanged();
    void logoSourceChanged();
    void entryPointsChanged();
    void validChanged();
    void errorChanged();
    void enabledChanged();
    void warningsChanged();
    void entryPointErrorsChanged();
    void generationChanged();
    void settingsSourceChanged();
    void settingsUiSourceChanged();

    void settingsChanged();       // Emitted when the settings object itself (m_settings) changed
    void settingsValuesChanged(); // Emitted when a value inside the settings object changed

private:
    void parse();

    // Drops the settings object so the next access rebuilds it from the current generation,
    // keeping the live values so a reload does not discard unsaved edits.
    void rebuildSettings();

    // Absolute URL for a manifest-relative asset. Absolute URLs are passed through unchanged.
    [[nodiscard]] QString assetUrl(const QString& source) const;

    // Content hash of the declared settings source; empty if it cannot be read.
    [[nodiscard]] QByteArray settingsHash() const;

    QString m_id;

    QString m_name;
    QString m_version;
    int m_api = kPluginApiVersion;

    QString m_icon;
    QString m_description;
    QString m_author;
    QString m_requires;
    QStringList m_tags;
    QString m_banner;
    QString m_logo;

    QString m_dir;
    QString m_path;
    QList<EntryPoint> m_entryPoints;
    QString m_parseError;
    QStringList m_warnings;
    QHash<quintptr, QString> m_entryPointErrors;
    QStringList m_conflicts;
    bool m_enabled = false;
    int m_generation = 0;

    // Raw relative paths; the URLs are derived per access so they always carry the current
    // generation. See sourceUrl().
    QString m_settingsSource;
    QString m_settingsUiSource;
    SettingsObject* m_settings = nullptr;
    QByteArray m_settingsHash;
    QVariantMap m_storedSettings;
    bool m_settingsDirty = false;
};

} // namespace caelestia::plugins
