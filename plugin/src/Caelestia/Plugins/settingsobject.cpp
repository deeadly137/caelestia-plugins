#include "settingsobject.hpp"

#include <qjsvalue.h>
#include <qmath.h>
#include <qmetatype.h>

#include <algorithm>

#include "settingmeta.hpp"

namespace caelestia::plugins {

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

bool isInteger(const QMetaType& type) {
    return isNumeric(type) && type.id() != QMetaType::Double && type.id() != QMetaType::Float;
}

bool isNumericVariant(const QVariant& value) {
    return isNumeric(value.metaType());
}

bool sameValue(const QVariant& a, const QVariant& b) {
    if (!a.isValid() || !b.isValid())
        return a.isValid() == b.isValid();

    if (isNumeric(a.metaType()) && isNumeric(b.metaType()))
        return qFuzzyCompare(a.toDouble() + 1.0, b.toDouble() + 1.0);

    return a == b;
}

QVariant normalise(QVariant value) {
    if (value.metaType() == QMetaType::fromType<QJSValue>())
        value = value.value<QJSValue>().toVariant();
    return value;
}

} // namespace

SettingsObject::SettingsObject(QObject* parent)
    : QObject(parent) {}

void SettingsObject::classBegin() {}

void SettingsObject::componentComplete() {
    snapshotDefaults();
    connectNotifiers();
}

QVariantMap SettingsObject::toMap() const {
    QVariantMap map;

    const auto* meta = metaObject();
    for (int i = basePropertyOffset(); i < meta->propertyCount(); ++i) {
        const auto prop = meta->property(i);
        if (!prop.isReadable())
            continue;

        const auto key = QString::fromUtf8(prop.name());
        auto value = prop.read(this);

        // Nested groups are usually declared CONSTANT, so they have no notify signal. They still
        // have to be written out, or everything under them would be lost on save.
        if (value.canView<SettingsObject*>()) {
            auto* const sub = value.view<SettingsObject*>();
            map.insert(key, sub ? sub->toMap() : QVariantMap());
            continue;
        }

        if (!prop.hasNotifySignal())
            continue;

        map.insert(key, normalise(value));
    }

    return map;
}

void SettingsObject::load(const QVariantMap& values) {
    QStringList warnings;
    loadInternal(values, QString(), warnings);

    m_warnings = warnings;
    emit warningsChanged();
}

void SettingsObject::loadInternal(const QVariantMap& values, const QString& prefix, QStringList& warnings) {
    m_loading = true;

    const auto* meta = metaObject();
    for (int i = basePropertyOffset(); i < meta->propertyCount(); ++i) {
        const auto prop = meta->property(i);
        const auto name = QString::fromUtf8(prop.name());
        const auto path = prefix.isEmpty() ? name : prefix + QLatin1Char('.') + name;
        auto current = prop.read(this);

        if (current.canView<SettingsObject*>()) {
            if (auto* const sub = current.view<SettingsObject*>()) {
                if (values.contains(name) && !values.value(name).canConvert<QVariantMap>())
                    warnings.append(QStringLiteral("%1: expected an object, ignoring").arg(path));
                sub->loadInternal(values.value(name).toMap(), path, warnings);
            }
            continue;
        }

        if (!prop.isWritable() || !values.contains(name))
            continue;

        writeValue(name, prop, values.value(name), path, warnings);
    }

    m_loading = false;
}

QVariantMap SettingsObject::values() const {
    return toMap();
}

QVariantMap SettingsObject::flatValues() const {
    QVariantMap map;

    const auto keys = this->keys();
    for (const auto& key : keys)
        map.insert(key, value(key));

    return map;
}

QStringList SettingsObject::keys() const {
    QStringList keys;

    const auto* meta = metaObject();
    for (int i = basePropertyOffset(); i < meta->propertyCount(); ++i) {
        const auto prop = meta->property(i);
        if (!prop.isReadable())
            continue;

        const auto name = QString::fromUtf8(prop.name());
        auto current = prop.read(this);

        if (current.canView<SettingsObject*>()) {
            if (auto* const sub = current.view<SettingsObject*>()) {
                const auto nested = sub->keys();
                for (const auto& key : nested)
                    keys.append(name + QLatin1Char('.') + key);
            }
            continue;
        }

        if (prop.hasNotifySignal())
            keys.append(name);
    }

    return keys;
}

QVariant SettingsObject::value(const QString& path) const {
    const auto parts = splitPath(path);
    if (parts.isEmpty())
        return {};

    const auto name = parts.first();
    if (parts.size() > 1) {
        auto* const sub = groupFor(name);
        return sub ? sub->value(parts.mid(1).join(QLatin1Char('.'))) : QVariant();
    }

    const auto* const meta = metaObject();
    const int index = meta->indexOfProperty(name.toUtf8().constData());
    if (index < basePropertyOffset())
        return {};

    return normalise(meta->property(index).read(this));
}

bool SettingsObject::setValue(const QString& path, const QVariant& value) {
    QStringList warnings;
    const bool ok = setValueInternal(path, value, warnings);

    if (!warnings.isEmpty()) {
        m_warnings.append(warnings);
        emit warningsChanged();
    }

    return ok;
}

bool SettingsObject::setValueInternal(const QString& path, const QVariant& value, QStringList& warnings) {
    const auto parts = splitPath(path);
    if (parts.isEmpty())
        return false;

    const auto name = parts.first();
    if (parts.size() > 1) {
        auto* const sub = groupFor(name);
        return sub && sub->setValueInternal(parts.mid(1).join(QLatin1Char('.')), value, warnings);
    }

    const auto* const meta = metaObject();
    const int index = meta->indexOfProperty(name.toUtf8().constData());
    if (index < basePropertyOffset())
        return false;

    const auto prop = meta->property(index);
    if (!prop.isWritable())
        return false;

    return writeValue(name, prop, value, path, warnings);
}

QVariant SettingsObject::defaultValue(const QString& path) const {
    const auto parts = splitPath(path);
    if (parts.isEmpty())
        return {};

    const auto name = parts.first();
    if (parts.size() > 1) {
        auto* const sub = groupFor(name);
        return sub ? sub->defaultValue(parts.mid(1).join(QLatin1Char('.'))) : QVariant();
    }

    return m_defaults.value(name);
}

bool SettingsObject::isModified(const QString& path) const {
    const auto def = defaultValue(path);
    if (!def.isValid())
        return false;

    return !sameValue(value(path), def);
}

bool SettingsObject::reset(const QString& path) {
    const auto def = defaultValue(path);
    if (!def.isValid())
        return false;

    return setValue(path, def);
}

void SettingsObject::resetAll() {
    const auto keys = this->keys();
    for (const auto& key : keys)
        reset(key);
}

QStringList SettingsObject::warnings() const {
    QStringList warnings = m_warnings;
    collectMetaWarnings(QString(), warnings);
    return warnings;
}

void SettingsObject::registerMeta(const QString& property, SettingMeta* meta) {
    m_meta.insert(property, meta);
    connect(meta, &SettingMeta::changed, this, &SettingsObject::warningsChanged, Qt::UniqueConnection);
}

SettingMeta* SettingsObject::metaFor(const QString& property) const {
    const auto parts = splitPath(property);
    if (parts.isEmpty())
        return nullptr;

    const auto name = parts.first();
    if (parts.size() > 1) {
        auto* const sub = groupFor(name);
        return sub ? sub->metaFor(parts.mid(1).join(QLatin1Char('.'))) : nullptr;
    }

    return m_meta.value(name);
}

void SettingsObject::onPropertyChanged() {
    if (m_loading)
        return;

    connectNotifiers();
    emit changed();
}

int SettingsObject::basePropertyOffset() {
    return SettingsObject::staticMetaObject.propertyCount();
}

QStringList SettingsObject::splitPath(const QString& path) {
    QStringList parts;

    const auto trimmed = path.trimmed();
    if (trimmed.isEmpty())
        return parts;

    return trimmed.split(QLatin1Char('.'), Qt::SkipEmptyParts);
}

SettingsObject* SettingsObject::groupFor(const QString& name) const {
    const auto* const meta = metaObject();
    const int index = meta->indexOfProperty(name.toUtf8().constData());
    if (index < basePropertyOffset())
        return nullptr;

    auto current = meta->property(index).read(this);
    return current.canView<SettingsObject*>() ? current.view<SettingsObject*>() : nullptr;
}

void SettingsObject::connectNotifiers() {
    const auto slot = staticMetaObject.method(staticMetaObject.indexOfSlot("onPropertyChanged()"));

    const auto* meta = metaObject();
    for (int i = basePropertyOffset(); i < meta->propertyCount(); ++i) {
        const auto prop = meta->property(i);
        auto current = prop.read(this);

        // Bubble changes from nested objects
        if (current.canView<SettingsObject*>()) {
            if (auto* sub = current.view<SettingsObject*>()) {
                connect(sub, &SettingsObject::changed, this, &SettingsObject::onPropertyChanged, Qt::UniqueConnection);
                connect(sub, &SettingsObject::warningsChanged, this, &SettingsObject::warningsChanged,
                    Qt::UniqueConnection);
            }
            continue;
        }

        if (prop.isReadable() && prop.hasNotifySignal())
            connect(this, prop.notifySignal(), this, slot, Qt::UniqueConnection);
    }
}

void SettingsObject::snapshotDefaults() {
    m_defaults.clear();

    const auto* meta = metaObject();
    for (int i = basePropertyOffset(); i < meta->propertyCount(); ++i) {
        const auto prop = meta->property(i);
        const auto name = QString::fromUtf8(prop.name());
        auto current = prop.read(this);

        // Children snapshot their own leaves; componentComplete runs bottom-up before load().
        if (current.canView<SettingsObject*>() || !prop.isReadable() || !prop.hasNotifySignal())
            continue;

        m_defaults.insert(name, normalise(current));
    }
}

bool SettingsObject::coercible(const QMetaType& type, const QVariant& value, QString& error) const {
    const auto id = type.id();

    if (id == QMetaType::Bool) {
        if (value.typeId() == QMetaType::Bool)
            return true;
        if (isNumericVariant(value) && (value.toDouble() == 0 || value.toDouble() == 1))
            return true;
        if (value.typeId() == QMetaType::QString &&
            (value.toString() == QStringLiteral("true") || value.toString() == QStringLiteral("false")))
            return true;

        error = QStringLiteral("expected a boolean");
        return false;
    }

    if (isNumeric(type)) {
        if (!isNumericVariant(value)) {
            error = isInteger(type) ? QStringLiteral("expected an integer") : QStringLiteral("expected a number");
            return false;
        }
        return true;
    }

    if (id == QMetaType::QString) {
        if (value.typeId() == QMetaType::QString)
            return true;

        error = QStringLiteral("expected a string");
        return false;
    }

    if (id == QMetaType::QStringList) {
        if (value.typeId() == QMetaType::QStringList)
            return true;

        if (value.typeId() == QMetaType::QVariantList) {
            const auto list = value.toList();
            const bool strings = std::all_of(list.cbegin(), list.cend(), [](const QVariant& item) {
                return item.typeId() == QMetaType::QString;
            });
            if (strings)
                return true;
        }

        error = QStringLiteral("expected a list of strings");
        return false;
    }

    if (id == QMetaType::QVariant || type == QMetaType::fromType<QJSValue>() || QVariant(value).canConvert(type))
        return true;

    error = QStringLiteral("expected %1").arg(QString::fromUtf8(type.name()));
    return false;
}

bool SettingsObject::writeValue(const QString& name, const QMetaProperty& property, const QVariant& value,
    const QString& path, QStringList& warnings) {
    auto type = property.metaType();

    QString error;
    if (!coercible(type, value, error)) {
        warnings.append(QStringLiteral("%1: %2, keeping the default").arg(path, error));
        return false;
    }

    auto coerced = value;

    if (type.id() == QMetaType::Bool)
        coerced = value.toBool();
    else if (type.id() == QMetaType::QString)
        coerced = value.toString();
    else if (type.id() == QMetaType::QStringList && value.typeId() == QMetaType::QVariantList) {
        QStringList list;
        const auto variants = value.toList();
        for (const auto& item : variants)
            list.append(item.toString());
        coerced = list;
    } else if (isNumeric(type)) {
        auto number = value.toDouble();
        bool clamped = false;

        // An explicit min/max is a real bound, including zero and negative ranges.
        if (auto* const meta = m_meta.value(name)) {
            if (meta->hasMin() && number < meta->min()) {
                number = meta->min();
                clamped = true;
            }
            if (meta->hasMax() && number > meta->max()) {
                number = meta->max();
                clamped = true;
            }

            if (clamped) {
                const auto range =
                    meta->hasMin() && meta->hasMax()
                        ? QStringLiteral("[%1, %2]").arg(QString::number(meta->min()), QString::number(meta->max()))
                    : meta->hasMin() ? QStringLiteral("the minimum %1").arg(QString::number(meta->min()))
                                     : QStringLiteral("the maximum %1").arg(QString::number(meta->max()));
                warnings.append(QStringLiteral("%1: %2 is outside %3, using %4")
                        .arg(path, QString::number(value.toDouble()), range, QString::number(number)));
            }
        }

        coerced = isInteger(type) ? QVariant::fromValue(static_cast<qlonglong>(qRound64(number))) : QVariant(number);
    }

    return property.write(this, coerced);
}

void SettingsObject::collectMetaWarnings(const QString& prefix, QStringList& warnings) const {
    const auto* meta = metaObject();
    for (int i = basePropertyOffset(); i < meta->propertyCount(); ++i) {
        const auto prop = meta->property(i);
        const auto name = QString::fromUtf8(prop.name());
        const auto path = prefix.isEmpty() ? name : prefix + QLatin1Char('.') + name;

        if (auto* const settingMeta = m_meta.value(name))
            warnings.append(settingMeta->metaWarnings(path, prop));

        if (auto current = prop.read(this); current.canView<SettingsObject*>()) {
            if (auto* const sub = current.view<SettingsObject*>())
                sub->collectMetaWarnings(path, warnings);
        }
    }
}

} // namespace caelestia::plugins
