#pragma once

#include <qobject.h>
#include <qpointer.h>
#include <qqmlcomponent.h>
#include <qqmlintegration.h>
#include <qquickitem.h>
#include <qstring.h>
#include <qvariant.h>

#include "entrypoint.hpp"

namespace caelestia::plugins {

class PluginManifest;
class SettingsObject;

class EntryPointLoader : public QQuickItem {
    Q_OBJECT
    QML_ELEMENT

    // The entry point to load
    Q_PROPERTY(caelestia::plugins::EntryPoint entryPoint READ entryPoint WRITE setEntryPoint RESET resetEntryPoint
            NOTIFY entryPointChanged)
    // The URL to load. Defaults to the entry point's source resolved against its plugin at the
    // plugin's current generation, so it changes, and the loader reloads, on every plugin edit.
    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
    // The loaded object, null until it has finished loading
    Q_PROPERTY(QObject* item READ item NOTIFY itemChanged)
    // The loader's state. Stays Ready while a swap-compile is in flight, because the previous
    // object is still the live one.
    Q_PROPERTY(caelestia::plugins::EntryPointLoader::Status status READ status NOTIFY statusChanged)

public:
    enum Status {
        Null,    // Nothing to load
        Loading, // Waiting for the component to compile
        Ready,   // Object created successfully
        Error,   // The entry point, its source or the created object is invalid
    };
    Q_ENUM(Status)

    explicit EntryPointLoader(QQuickItem* parent = nullptr);
    ~EntryPointLoader() override;

    void componentComplete() override;

    [[nodiscard]] EntryPoint entryPoint() const;
    void setEntryPoint(const EntryPoint& entryPoint);
    void resetEntryPoint();

    [[nodiscard]] QString source() const;
    void setSource(const QString& source);

    [[nodiscard]] QObject* item() const;
    [[nodiscard]] Status status() const;

    // Whether `object` declares `name` itself rather than inheriting it from a base type. Used so
    // manifest `properties` cannot collide with QML base properties (Item.layer, Item.width, ...).
    [[nodiscard]] static bool declaresProperty(const QObject* object, const QString& name);

signals:
    void entryPointChanged();
    void sourceChanged();
    void itemChanged();
    void statusChanged();

    // Emitted after the object has been created and injected
    void loaded();

private slots:
    void onComponentStatusChanged(QQmlComponent::Status status);
    void onGenerationChanged();
    void updateSize();
    void updateImplicitSize();

private:
    // What happens to the object that is currently loaded when a new one has to be loaded.
    enum class Handover {
        // Destroy it before compiling. Used when the entry point or source itself changed, so the
        // old object is simply wrong, and for custom services, where two copies would both act on
        // the shell (timers, hooks, IPC targets) even for a moment.
        DropFirst,
        // Leave it live until the replacement has been created, then retire it. Used for a plugin
        // generation bump: a compile takes long enough that blanking a bar item or a desktop
        // widget would be visible.
        SwapWhenReady,
    };

    void reload(Handover handover = Handover::DropFirst);
    void create();
    void setStatus(Status status);
    void warnComponentErrors() const;
    [[nodiscard]] bool canSwap() const;

    // Drops the component of an in-flight or finished compile without touching the live object.
    void discardComponent();

    // Calls the object's `onUnload()` hook, detaches it and schedules its destruction. `notify`
    // tells QML the item is gone; a swap skips that and emits itemChanged once, after the
    // replacement is installed.
    void retireObject(bool notify);

    // Surfaces failures on the plugin so the Nexus detail page can show them, keyed by this
    // loader instance so several live copies of one entry point each keep their own message.
    void reportFailure(const QString& message) const;
    void clearFailure() const;

    // Calls the loaded object's optional `onUnload()` hook before it is destroyed.
    void invokeUnload();

    // Follows the entry point's plugin so a generation bump reloads this loader. Loaders are
    // created lazily, so each one derives its URL when it builds its component and joins
    // whichever generation is current then; there is no stored URL to go stale.
    void trackPlugin();

    // The subset of the injectable properties actually declared by the given object. Sets
    // `injectedSettings` to the settings object when it was one of them, so the caller can record
    // the object as a holder of it.
    [[nodiscard]] QVariantMap injectedProperties(
        const QObject* object, SettingsObject** injectedSettings = nullptr) const;

    EntryPoint m_entryPoint;
    QPointer<PluginManifest> m_plugin;
    QString m_source;
    QQmlComponent* m_component = nullptr;
    QObject* m_object = nullptr;
    QQuickItem* m_item = nullptr;
    Status m_status = Null;
    bool m_complete = false;
};

} // namespace caelestia::plugins
