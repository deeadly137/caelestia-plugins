#include "entrypointloader.hpp"

#include <qloggingcategory.h>
#include <qmetaobject.h>
#include <qqmlcontext.h>
#include <qqmlengine.h>
#include <qurl.h>
#include <qurlquery.h>

#include "pluginmanifest.hpp"
#include "settingsobject.hpp"

Q_LOGGING_CATEGORY(lcEntryPointLoader, "caelestia.plugins.loader", QtInfoMsg)

namespace caelestia::plugins {

EntryPointLoader::EntryPointLoader(QQuickItem* parent)
    : QQuickItem(parent) {
    QObject::connect(this, &QQuickItem::widthChanged, this, &EntryPointLoader::updateSize);
    QObject::connect(this, &QQuickItem::heightChanged, this, &EntryPointLoader::updateSize);
}

EntryPointLoader::~EntryPointLoader() {
    // The object is parented here and dies with us, so it never goes through clear(). Let a
    // service entry point still run its teardown hook on shell shutdown.
    invokeUnload();
    clearFailure();
}

void EntryPointLoader::componentComplete() {
    QQuickItem::componentComplete();

    m_complete = true;
    reload(Handover::DropFirst);
}

EntryPoint EntryPointLoader::entryPoint() const {
    return m_entryPoint;
}

void EntryPointLoader::setEntryPoint(const EntryPoint& entryPoint) {
    if (m_entryPoint == entryPoint)
        return;

    const auto oldSource = source();

    m_entryPoint = entryPoint;
    trackPlugin();
    emit entryPointChanged();

    if (source() != oldSource)
        emit sourceChanged();

    // A different entry point (or one whose properties moved) is not a reload of this one, so the
    // loaded object has to go before the new one is compiled.
    reload(Handover::DropFirst);
}

void EntryPointLoader::resetEntryPoint() {
    setEntryPoint(EntryPoint());
}

void EntryPointLoader::trackPlugin() {
    auto* const plugin = m_entryPoint.plugin();
    if (m_plugin == plugin)
        return;

    if (m_plugin)
        QObject::disconnect(m_plugin, &PluginManifest::generationChanged, this, &EntryPointLoader::onGenerationChanged);

    m_plugin = plugin;

    if (m_plugin)
        QObject::connect(m_plugin, &PluginManifest::generationChanged, this, &EntryPointLoader::onGenerationChanged);
}

void EntryPointLoader::onGenerationChanged() {
    emit sourceChanged();

    // A plugin edit reloads in place. Visual entry points keep showing the previous version until
    // the replacement exists; a custom service is stopped first, since its timers, hooks and IPC
    // targets must not run twice.
    reload(canSwap() ? Handover::SwapWhenReady : Handover::DropFirst);
}

bool EntryPointLoader::canSwap() const {
    return m_object && m_entryPoint.type() != EntryPointType::Custom;
}

QString EntryPointLoader::source() const {
    if (!m_source.isEmpty())
        return m_source;
    return m_plugin ? m_plugin->sourceUrl(m_entryPoint.source()) : QString();
}

void EntryPointLoader::setSource(const QString& source) {
    if (m_source == source)
        return;

    m_source = source;
    emit sourceChanged();

    reload(Handover::DropFirst);
}

QObject* EntryPointLoader::item() const {
    return m_object;
}

EntryPointLoader::Status EntryPointLoader::status() const {
    return m_status;
}

void EntryPointLoader::onComponentStatusChanged(QQmlComponent::Status status) {
    if (status == QQmlComponent::Loading)
        return;

    if (status == QQmlComponent::Ready)
        create();
    else if (status == QQmlComponent::Error) {
        warnComponentErrors();
        discardComponent();

        // A failed swap leaves the previous version on screen: it is still the last thing that
        // worked, and the failure is already recorded on the plugin for the Problems list.
        if (!m_object)
            setStatus(Error);
    } else {
        discardComponent();

        if (!m_object)
            setStatus(Null);
    }
}

void EntryPointLoader::updateSize() {
    if (m_item)
        m_item->setSize(size());
}

void EntryPointLoader::updateImplicitSize() {
    setImplicitWidth(m_item ? m_item->implicitWidth() : 0);
    setImplicitHeight(m_item ? m_item->implicitHeight() : 0);
}

void EntryPointLoader::discardComponent() {
    if (!m_component)
        return;

    // The connection is cut first: the component stays alive until the event loop gets to the
    // deferred deletion, and a compile that finishes in the meantime must not create an object
    // that belongs to a reload this loader has already abandoned.
    QObject::disconnect(m_component, nullptr, this, nullptr);
    m_component->deleteLater();
    m_component = nullptr;
}

void EntryPointLoader::retireObject(bool notify) {
    if (!m_object)
        return;

    invokeUnload();

    if (m_item) {
        QObject::disconnect(m_item, nullptr, this, nullptr);
        m_item->setParentItem(nullptr);
        m_item = nullptr;
        updateImplicitSize();
    }

    // Deferred, so an onUnload() implementation can finish its own stack before the object goes
    m_object->deleteLater();
    m_object = nullptr;

    if (notify)
        emit itemChanged();
}

void EntryPointLoader::reload(Handover handover) {
    if (!m_complete)
        return;

    if (handover == Handover::DropFirst)
        retireObject(true);

    // Whatever compile was in flight belongs to the previous request
    discardComponent();

    const auto error = m_entryPoint.error();
    if (!error.isEmpty()) {
        qCWarning(lcEntryPointLoader) << "Refusing to load invalid entry point:" << error;
        reportFailure(error);
        setStatus(Error);
        return;
    }

    const auto src = source();
    if (src.isEmpty()) {
        setStatus(Null);
        return;
    }

    auto* const context = qmlContext(this);
    if (!context) {
        qCWarning(lcEntryPointLoader) << "Cannot load" << src << "without a QML context";
        reportFailure(QStringLiteral("Cannot load %1 without a QML context").arg(src));
        setStatus(Error);
        return;
    }

    // An entry point's URL is already absolute and carries its plugin's generation; only an
    // explicitly set source is a path that has to be resolved against this loader's own file.
    const QUrl url(src);
    m_component = new QQmlComponent(
        context->engine(), url.isRelative() ? context->resolvedUrl(url) : url, QQmlComponent::Asynchronous, this);

    // Creation stays on this thread and synchronous once the compile lands, so a plugin never has
    // half of its objects on one registration set and half on the next one.
    if (m_component->isLoading()) {
        // A live object already is valid content; announcing Loading would claim otherwise
        if (!m_object)
            setStatus(Loading);
        QObject::connect(m_component, &QQmlComponent::statusChanged, this, &EntryPointLoader::onComponentStatusChanged);
    } else
        onComponentStatusChanged(m_component->status());
}

void EntryPointLoader::create() {
    // The revision barrier. A compile takes long enough that the plugin can be edited again before
    // it lands, and type registrations are global: the imports this unit just resolved may belong
    // to a newer generation than the URL it is filed under. Recompiling is the only way to get a
    // unit that is consistent with its URL.
    if (m_source.isEmpty() && m_plugin) {
        const auto gen = QUrlQuery(m_component->url()).queryItemValue(QStringLiteral("gen")).toInt();
        if (gen != m_plugin->generation()) {
            qCDebug(lcEntryPointLoader) << "Discarding" << m_component->url() << "compiled at generation" << gen
                                        << "but" << m_plugin->id() << "is now at generation" << m_plugin->generation();
            reload(canSwap() ? Handover::SwapWhenReady : Handover::DropFirst);
            return;
        }
    }

    auto* const object = m_component->beginCreate(qmlContext(this));
    if (!object) {
        warnComponentErrors();
        discardComponent();

        if (!m_object)
            setStatus(Error);
        return;
    }

    SettingsObject* injectedSettings = nullptr;
    const auto properties = injectedProperties(object, &injectedSettings);
    if (!properties.isEmpty())
        m_component->setInitialProperties(object, properties);

    m_component->completeCreate();

    // Also covers required properties the entry point declares but nothing provides
    if (m_component->isError()) {
        warnComponentErrors();
        delete object;
        discardComponent();

        if (!m_object)
            setStatus(Error);
        return;
    }

    // The new object reads the settings object it was just handed, so the manifest may not free
    // it before this one is gone. Recorded before the swap, and dropped automatically when the
    // object is destroyed.
    if (injectedSettings && m_plugin)
        m_plugin->trackSettingsHolder(injectedSettings, object);

    // The replacement exists, so the previous version can go. On a swap this is the handover
    // point: both objects have been created, only the new one survives.
    retireObject(false);

    m_object = object;
    QQmlEngine::setObjectOwnership(m_object, QQmlEngine::CppOwnership);
    m_object->setParent(this);

    m_item = qobject_cast<QQuickItem*>(m_object);
    if (m_item) {
        m_item->setParentItem(this);
        QObject::connect(m_item, &QQuickItem::implicitWidthChanged, this, &EntryPointLoader::updateImplicitSize);
        QObject::connect(m_item, &QQuickItem::implicitHeightChanged, this, &EntryPointLoader::updateImplicitSize);
        updateImplicitSize();
        updateSize();
    }

    emit itemChanged();
    setStatus(Ready);
    clearFailure();
    emit loaded();
}

void EntryPointLoader::setStatus(Status status) {
    if (m_status == status)
        return;

    m_status = status;
    emit statusChanged();
}

void EntryPointLoader::warnComponentErrors() const {
    qCWarning(lcEntryPointLoader, "Failed to load %s: %s", qUtf8Printable(source()),
        qUtf8Printable(m_component->errorString().trimmed()));

    reportFailure(m_component->errorString());
}

void EntryPointLoader::reportFailure(const QString& message) const {
    if (m_plugin)
        m_plugin->setEntryPointError(quintptr(this), message);
}

void EntryPointLoader::invokeUnload() {
    if (!m_object)
        return;

    // QML convention for anything that needs to stop timers/sockets before it is destroyed:
    //     function onUnload(): void { ... }
    if (m_object->metaObject()->indexOfMethod("onUnload()") != -1)
        QMetaObject::invokeMethod(m_object, "onUnload", Qt::DirectConnection);
}

void EntryPointLoader::clearFailure() const {
    if (m_plugin)
        m_plugin->clearEntryPointError(quintptr(this));
}

bool EntryPointLoader::declaresProperty(const QObject* object, const QString& name) {
    if (!object)
        return false;

    const auto* const meta = object->metaObject();
    const int index = meta->indexOfProperty(name.toUtf8().constData());
    if (index == -1)
        return false;

    // A QML object's dynamic metaobject also exposes its base type's properties (Item.layer,
    // Item.width, ...). Only a property declared by the component itself may receive a manifest
    // value; `properties.layer` is host metadata for desktop widgets, not Item's layer group.
    return meta->property(index).enclosingMetaObject() == meta;
}

QVariantMap EntryPointLoader::injectedProperties(const QObject* object, SettingsObject** injectedSettings) const {
    QVariantMap properties;

    // Manifest `properties` are initial values for properties the entry point actually declares.
    // Injecting only declared names keeps a typo in a manifest from adding junk dynamic
    // properties, and lets entry points use plain `required property string name` instead of
    // digging through entryPoint.properties at runtime.
    const auto declared = m_entryPoint.properties();
    for (auto it = declared.cbegin(); it != declared.cend(); ++it) {
        if (!declaresProperty(object, it.key()))
            continue;

        properties.insert(it.key(), it.value());
    }

    // Reserved names win over anything a manifest declares with the same key
    if (declaresProperty(object, QStringLiteral("entryPoint")))
        properties.insert(QStringLiteral("entryPoint"), QVariant::fromValue(m_entryPoint));

    if (declaresProperty(object, QStringLiteral("settings"))) {
        // Built on demand, so this picks up the object rebuilt for the current generation
        SettingsObject* const settings = m_plugin ? m_plugin->settings() : nullptr;
        properties.insert(QStringLiteral("settings"), QVariant::fromValue(settings));

        if (injectedSettings)
            *injectedSettings = settings;
    }

    return properties;
}

} // namespace caelestia::plugins
