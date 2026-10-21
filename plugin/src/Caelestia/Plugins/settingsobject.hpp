#pragma once

#include <qhash.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qqmlparserstatus.h>
#include <qvariant.h>
#include <qvariantmap.h>

namespace caelestia::plugins {

class SettingMeta;

class SettingsObject : public QObject, public QQmlParserStatus {
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)
    Q_MOC_INCLUDE("settingmeta.hpp")

public:
    explicit SettingsObject(QObject* parent = nullptr);

    void classBegin() override;
    void componentComplete() override;

    [[nodiscard]] QVariantMap toMap() const;

    void load(const QVariantMap& values);

    // Snapshot of the current values, for settings UIs that do not want to rely on dynamic
    // property access.
    [[nodiscard]] Q_INVOKABLE QVariantMap values() const;

    // Read or write a single user defined property by name.
    [[nodiscard]] Q_INVOKABLE QVariant value(const QString& key) const;
    Q_INVOKABLE bool setValue(const QString& key, const QVariant& value);

    // All user defined properties
    [[nodiscard]] Q_INVOKABLE QStringList keys() const;

    void registerMeta(const QString& property, SettingMeta* meta);
    [[nodiscard]] Q_INVOKABLE caelestia::plugins::SettingMeta* metaFor(const QString& property) const;

signals:
    void changed();

private slots:
    void onPropertyChanged();

private:
    [[nodiscard]] static int basePropertyOffset();
    void connectNotifiers();

    bool m_loading = false;
    QHash<QString, SettingMeta*> m_meta;
};

} // namespace caelestia::plugins
