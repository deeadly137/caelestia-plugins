#include "settingmeta.hpp"

#include <qmetatype.h>

#include "settingsobject.hpp"

namespace caelestia::plugins {

Q_LOGGING_CATEGORY(lcPluginSettings, "caelestia.plugins.settings", QtInfoMsg)

namespace {

bool isNumeric(const QMetaType& type) {
    switch (type.id()) {
    case QMetaType::Int:
    case QMetaType::UInt:
    case QMetaType::Long:
    case QMetaType::ULong:
    case QMetaType::LongLong:
    case QMetaType::ULongLong:
    case QMetaType::Short:
    case QMetaType::UShort:
    case QMetaType::Double:
    case QMetaType::Float:
        return true;
    default:
        return false;
    }
}

QString inputTypeName(SettingMeta::InputType type) {
    switch (type) {
    case SettingMeta::Switch:
        return QStringLiteral("switch");
    case SettingMeta::SpinBox:
        return QStringLiteral("spin box");
    case SettingMeta::Slider:
        return QStringLiteral("slider");
    case SettingMeta::TextField:
        return QStringLiteral("text field");
    case SettingMeta::SplitButton:
        return QStringLiteral("split button");
    case SettingMeta::BlobButton:
        return QStringLiteral("blob button");
    case SettingMeta::Default:
        break;
    }

    return QStringLiteral("default");
}

} // namespace

SettingMeta::SettingMeta(QObject* parent)
    : QObject(parent) {}

void SettingMeta::setTarget(const QQmlProperty& property) {
    m_key = property.name();

    if (auto* const settings = qobject_cast<SettingsObject*>(property.object()))
        settings->registerMeta(m_key, this);
    else
        qCWarning(
            lcPluginSettings, "SettingMeta on '%s' must target a property of a SettingsObject", qUtf8Printable(m_key));
}

QString SettingMeta::key() const {
    return m_key;
}

qreal SettingMeta::min() const {
    return m_min;
}

void SettingMeta::setMin(qreal min) {
    if (m_hasMin && m_min == min)
        return;

    m_min = min;
    m_hasMin = true;
    emit changed();
}

qreal SettingMeta::max() const {
    return m_max;
}

void SettingMeta::setMax(qreal max) {
    if (m_hasMax && m_max == max)
        return;

    m_max = max;
    m_hasMax = true;
    emit changed();
}

bool SettingMeta::hasMin() const {
    return m_hasMin;
}

bool SettingMeta::hasMax() const {
    return m_hasMax;
}

QStringList SettingMeta::metaWarnings(const QString& path, const QMetaProperty& property) const {
    QStringList warnings;

    const auto type = property.metaType();
    const bool numeric = isNumeric(type);
    const bool boolean = type.id() == QMetaType::Bool;
    const bool text = type.id() == QMetaType::QString;

    switch (m_inputType) {
    case SpinBox:
    case Slider:
        if (!numeric)
            warnings.append(
                QStringLiteral("%1: %2 input needs a numeric property").arg(path, inputTypeName(m_inputType)));
        break;
    case Switch:
        if (!boolean)
            warnings.append(QStringLiteral("%1: switch input needs a bool property").arg(path));
        break;
    case TextField:
        if (!text)
            warnings.append(QStringLiteral("%1: text field input needs a string property").arg(path));
        break;
    case SplitButton:
    case BlobButton:
        if (m_options.isEmpty())
            warnings.append(QStringLiteral("%1: %2 needs options").arg(path, inputTypeName(m_inputType)));
        if (!m_optionIcons.isEmpty() && m_optionIcons.size() != m_options.size())
            warnings.append(QStringLiteral("%1: %2 optionIcons but %3 options")
                    .arg(path, QString::number(m_optionIcons.size()), QString::number(m_options.size())));
        break;
    case Default:
        break;
    }

    if (m_hasMin && m_hasMax && m_min > m_max)
        warnings.append(QStringLiteral("%1: min (%2) is greater than max (%3)")
                .arg(path, QString::number(m_min), QString::number(m_max)));

    return warnings;
}

} // namespace caelestia::plugins
