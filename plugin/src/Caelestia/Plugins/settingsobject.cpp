#include "settingsobject.hpp"

#include <qjsvalue.h>
#include <qmetaobject.h>

#include "settingmeta.hpp"

namespace caelestia::plugins {

SettingsObject::SettingsObject(QObject* parent)
    : QObject(parent) {}

void SettingsObject::classBegin() {}

void SettingsObject::componentComplete() {
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

        if (value.canConvert<QJSValue>())
            value = value.value<QJSValue>().toVariant();

        map.insert(key, value);
    }

    return map;
}

void SettingsObject::load(const QVariantMap& values) {
    m_loading = true;

    const auto* meta = metaObject();
    for (int i = basePropertyOffset(); i < meta->propertyCount(); ++i) {
        const auto prop = meta->property(i);
        const auto key = QString::fromUtf8(prop.name());
        auto current = prop.read(this);

        if (current.canView<SettingsObject*>()) {
            if (auto* sub = current.view<SettingsObject*>())
                sub->load(values.value(key).toMap());
            continue;
        }

        if (!prop.isWritable() || !values.contains(key))
            continue;

        prop.write(this, values.value(key));
    }

    m_loading = false;
}

QVariantMap SettingsObject::values() const {
    return toMap();
}

QVariant SettingsObject::value(const QString& key) const {
    const auto* const meta = metaObject();
    const int index = meta->indexOfProperty(key.toUtf8().constData());
    if (index < basePropertyOffset())
        return {};

    return meta->property(index).read(this);
}

bool SettingsObject::setValue(const QString& key, const QVariant& value) {
    const auto* const meta = metaObject();
    const int index = meta->indexOfProperty(key.toUtf8().constData());
    if (index < basePropertyOffset())
        return false;

    const auto prop = meta->property(index);
    if (!prop.isWritable())
        return false;

    return prop.write(this, value);
}

QStringList SettingsObject::keys() const {
    QStringList keys;

    const auto* meta = metaObject();
    for (int i = basePropertyOffset(); i < meta->propertyCount(); ++i) {
        const auto prop = meta->property(i);
        if (prop.isReadable() && prop.hasNotifySignal())
            keys.append(QString::fromUtf8(prop.name()));
    }

    return keys;
}

void SettingsObject::registerMeta(const QString& property, SettingMeta* meta) {
    m_meta.insert(property, meta);
}

SettingMeta* SettingsObject::metaFor(const QString& property) const {
    return m_meta.value(property);
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

void SettingsObject::connectNotifiers() {
    const auto slot = staticMetaObject.method(staticMetaObject.indexOfSlot("onPropertyChanged()"));

    const auto* meta = metaObject();
    for (int i = basePropertyOffset(); i < meta->propertyCount(); ++i) {
        const auto prop = meta->property(i);
        auto current = prop.read(this);

        // Bubble changes from nested objects
        if (current.canView<SettingsObject*>()) {
            if (auto* sub = current.view<SettingsObject*>())
                connect(sub, &SettingsObject::changed, this, &SettingsObject::onPropertyChanged, Qt::UniqueConnection);
            continue;
        }

        if (prop.isReadable() && prop.hasNotifySignal())
            connect(this, prop.notifySignal(), this, slot, Qt::UniqueConnection);
    }
}

} // namespace caelestia::plugins
