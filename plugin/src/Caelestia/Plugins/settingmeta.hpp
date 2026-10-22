#pragma once

#include <qloggingcategory.h>
#include <qmetaobject.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qqmlproperty.h>
#include <qqmlpropertyvaluesource.h>
#include <qstringlist.h>

namespace caelestia::plugins {

Q_DECLARE_LOGGING_CATEGORY(lcPluginSettings)

// Metadata for a property of a SettingsObject
class SettingMeta : public QObject, public QQmlPropertyValueSource {
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlPropertyValueSource)

    // The property this metadata is attached to
    Q_PROPERTY(QString key READ key CONSTANT)

    // Generic metadata
    Q_PROPERTY(QString label MEMBER m_label NOTIFY changed)
    Q_PROPERTY(QString description MEMBER m_description NOTIFY changed)
    Q_PROPERTY(QString icon MEMBER m_icon NOTIFY changed)
    Q_PROPERTY(bool disabled MEMBER m_disabled NOTIFY changed)
    Q_PROPERTY(caelestia::plugins::SettingMeta::InputType inputType MEMBER m_inputType NOTIFY changed)

    // Numeric metadata. hasMin/hasMax matter: min: 0 and max: 0 are real bounds, and a missing
    // bound must not be confused with one that happens to be zero.
    Q_PROPERTY(qreal min READ min WRITE setMin NOTIFY changed)
    Q_PROPERTY(qreal max READ max WRITE setMax NOTIFY changed)
    Q_PROPERTY(bool hasMin READ hasMin NOTIFY changed)
    Q_PROPERTY(bool hasMax READ hasMax NOTIFY changed)
    Q_PROPERTY(qreal step MEMBER m_step NOTIFY changed)

    // Multi-select metadata
    Q_PROPERTY(QStringList options MEMBER m_options NOTIFY changed)
    Q_PROPERTY(QStringList optionIcons MEMBER m_optionIcons NOTIFY changed)

public:
    enum InputType {
        Default,

        // Boolean
        Switch,

        // Numeric
        SpinBox,
        Slider,

        // Text
        TextField,

        // Multi select
        SplitButton,
        BlobButton,
    };
    Q_ENUM(InputType)

    explicit SettingMeta(QObject* parent = nullptr);

    void setTarget(const QQmlProperty& property) override;

    [[nodiscard]] QString key() const;

    [[nodiscard]] qreal min() const;
    void setMin(qreal min);
    [[nodiscard]] qreal max() const;
    void setMax(qreal max);
    [[nodiscard]] bool hasMin() const;
    [[nodiscard]] bool hasMax() const;

    // Problems with this metadata given the property it targets. Checked when the settings object
    // is asked for its warnings, because SettingMeta properties are assigned after setTarget().
    [[nodiscard]] QStringList metaWarnings(const QString& path, const QMetaProperty& property) const;

signals:
    void changed();

private:
    QString m_key;
    QString m_label;
    QString m_description;
    QString m_icon;
    bool m_disabled = false;
    InputType m_inputType = Default;
    qreal m_min = 0;
    qreal m_max = 0;
    bool m_hasMin = false;
    bool m_hasMax = false;
    qreal m_step = 1;
    QStringList m_options;
    QStringList m_optionIcons;
};

} // namespace caelestia::plugins
