#pragma once

#include <qhash.h>
#include <qmetaobject.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qqmlparserstatus.h>
#include <qstringlist.h>
#include <qvariant.h>
#include <qvariantmap.h>

namespace caelestia::plugins {

class SettingMeta;

class SettingsObject : public QObject, public QQmlParserStatus {
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)
    Q_MOC_INCLUDE("settingmeta.hpp")

    // Validation problems (bad stored values, contradictory metadata), shown by the Nexus page
    Q_PROPERTY(QStringList warnings READ warnings NOTIFY warningsChanged)

public:
    explicit SettingsObject(QObject* parent = nullptr);

    void classBegin() override;
    void componentComplete() override;

    // Nested map, the shape plugins.json stores and plugins.json is loaded from.
    [[nodiscard]] QVariantMap toMap() const;
    void load(const QVariantMap& values);

    // Snapshots for settings UIs. `values()` mirrors toMap(); `flatValues()` and `keys()` use
    // dotted leaf paths ("appearance.blur"), with groups expanded in declaration order.
    [[nodiscard]] Q_INVOKABLE QVariantMap values() const;
    [[nodiscard]] Q_INVOKABLE QVariantMap flatValues() const;
    [[nodiscard]] Q_INVOKABLE QStringList keys() const;

    // Read or write a leaf by dotted path. Plain keys keep working.
    [[nodiscard]] Q_INVOKABLE QVariant value(const QString& path) const;
    Q_INVOKABLE bool setValue(const QString& path, const QVariant& value);

    // Declared value of a leaf, snapshotted before load() ran.
    [[nodiscard]] Q_INVOKABLE QVariant defaultValue(const QString& path) const;
    [[nodiscard]] Q_INVOKABLE bool isModified(const QString& path) const;
    Q_INVOKABLE bool reset(const QString& path);
    Q_INVOKABLE void resetAll();

    [[nodiscard]] Q_INVOKABLE QStringList warnings() const;

    void registerMeta(const QString& property, SettingMeta* meta);
    [[nodiscard]] Q_INVOKABLE caelestia::plugins::SettingMeta* metaFor(const QString& property) const;

signals:
    void changed();
    void warningsChanged();

private slots:
    void onPropertyChanged();

private:
    [[nodiscard]] static int basePropertyOffset();
    [[nodiscard]] static QStringList splitPath(const QString& path);
    void connectNotifiers();
    void snapshotDefaults();

    [[nodiscard]] SettingsObject* groupFor(const QString& name) const;

    // A parent load collects all warnings so paths stay absolute ("group.leaf") no matter how
    // deep the value lives.
    void loadInternal(const QVariantMap& values, const QString& prefix, QStringList& warnings);
    bool setValueInternal(const QString& path, const QVariant& value, QStringList& warnings);
    bool writeValue(const QString& name, const QMetaProperty& property, const QVariant& value, const QString& path,
        QStringList& warnings);
    [[nodiscard]] bool coercible(const QMetaType& type, const QVariant& value, QString& error) const;
    void collectMetaWarnings(const QString& prefix, QStringList& warnings) const;

    bool m_loading = false;
    QHash<QString, SettingMeta*> m_meta;
    QHash<QString, QVariant> m_defaults;
    QStringList m_warnings;
};

} // namespace caelestia::plugins
