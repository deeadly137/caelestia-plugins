pragma Singleton

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config

// Generic extension registry between the shell and its plugins.
//
// The shell declares named hook points where a plugin may change behaviour or add UI. A plugin
// registers into one of them from a long-lived object (usually a `custom` entry point) and
// unregisters from its `onUnload()` handler, so disabling the plugin restores the stock shell.
//
// Every registration is owned by a plugin id. A plugin can therefore replace its own registration,
// and `unregister(owner)` removes all of them at once without tracking names.
//
// Consumers that call into this singleton inside a binding automatically depend on `revision`,
// which is bumped on every registration change, so the binding re-evaluates.
Singleton {
    id: root

    // Bumped whenever any registration is added, replaced or removed. Read by every accessor so
    // bindings that use them get re-evaluated.
    property int revision: 0

    // name -> owner -> { value, priority, sequence }
    property var _values: ({})
    // name -> owner -> { fn, priority, sequence }
    property var _functions: ({})
    // name -> owner -> { component, properties, priority, sequence }
    property var _slots: ({})
    // Slot arrays are handed out to models, so they are rebuilt only when a slot registration
    // changes. A revision bump from a settings change must not recreate every delegate.
    property var _slotCache: ({})

    property int _sequence: 0

    function bump(): void {
        root.revision++;
    }

    // --- Scalar overrides -------------------------------------------------------------------
    //
    // `value()` returns the highest priority registration, or `fallback` when there is none.

    function setValue(name: string, owner: string, value: var, priority = 0): void {
        if (!root._values[name])
            root._values[name] = ({});
        root._values[name][owner] = ({
            value: value,
            priority: priority,
            sequence: ++root._sequence
        });
        bump();
    }

    function clearValue(name: string, owner: string): void {
        const entries = root._values[name];
        if (!entries || !(owner in entries))
            return;
        delete entries[owner];
        bump();
    }

    function value(name: string, fallback = undefined): var {
        // Reading the revision is what makes a binding using this accessor re-evaluate.
        void root.revision;

        const entries = root._values[name];
        if (!entries)
            return fallback;

        let best = null;
        for (const owner in entries) {
            const entry = entries[owner];
            if (!best || entry.priority > best.priority || (entry.priority === best.priority && entry.sequence > best.sequence))
                best = entry;
        }
        return best ? best.value : fallback;
    }

    // --- Function hooks ---------------------------------------------------------------------
    //
    // `call()` invokes the highest priority provider and returns its result, or `undefined` when
    // nothing is registered. Use `hasFunction()` for hooks that act without a return value.

    function setFunction(name: string, owner: string, fn: var, priority = 0): void {
        if (!root._functions[name])
            root._functions[name] = ({});
        root._functions[name][owner] = ({
            fn: fn,
            priority: priority,
            sequence: ++root._sequence
        });
        bump();
    }

    function clearFunction(name: string, owner: string): void {
        const entries = root._functions[name];
        if (!entries || !(owner in entries))
            return;
        delete entries[owner];
        bump();
    }

    function hasFunction(name: string): bool {
        void root.revision;

        const entries = root._functions[name];
        return entries ? Object.keys(entries).length > 0 : false;
    }

    function call(name: string, args = []): var {
        void root.revision;

        const entries = root._functions[name];
        if (!entries)
            return undefined;

        let best = null;
        for (const owner in entries) {
            const entry = entries[owner];
            if (!best || entry.priority > best.priority || (entry.priority === best.priority && entry.sequence > best.sequence))
                best = entry;
        }
        if (!best)
            return undefined;

        try {
            return best.fn.apply(null, args);
        } catch (e) {
            console.warn("[Hooks] handler for", name, "failed:", e);
            return undefined;
        }
    }

    // --- Component slots --------------------------------------------------------------------
    //
    // A slot is a list of components a host instantiates wherever it declares the slot. `properties`
    // are applied to every instance, then the host sets whatever is context specific.

    function inject(name: string, owner: string, component: var, properties = null, priority = 0): void {
        if (!root._slots[name])
            root._slots[name] = ({});
        root._slots[name][owner] = ({
            component: component,
            properties: properties ?? ({}),
            priority: priority,
            sequence: ++root._sequence
        });
        root._slotCache = ({});
        bump();
    }

    function retract(name: string, owner: string): void {
        const entries = root._slots[name];
        if (!entries || !(owner in entries))
            return;
        delete entries[owner];
        root._slotCache = ({});
        bump();
    }

    function slot(name: string): var {
        void root.revision;

        if (!(name in root._slotCache)) {
            const entries = root._slots[name];
            root._slotCache[name] = entries ? Object.keys(entries)
                .map(owner => entries[owner])
                .sort((a, b) => a.priority - b.priority || a.sequence - b.sequence) : [];
        }
        return root._slotCache[name];
    }

    // Removes every registration an owner made. Call from the plugin's `onUnload()`.
    function unregister(owner: string): void {
        let changed = false;

        for (const name in root._values) {
            if (owner in root._values[name]) {
                delete root._values[name][owner];
                changed = true;
            }
        }
        for (const name in root._functions) {
            if (owner in root._functions[name]) {
                delete root._functions[name][owner];
                changed = true;
            }
        }
        for (const name in root._slots) {
            if (owner in root._slots[name]) {
                delete root._slots[name][owner];
                changed = true;
            }
        }

        if (changed) {
            root._slotCache = ({});
            bump();
        }
    }

    // --- Shell hook points ------------------------------------------------------------------
    //
    // Thin wrappers for the hook points the shell itself exposes, so call sites stay short and the
    // fallback to the configured value is handled in one place.

    // `bar.position`: the effective screen edge. Falls back to the per-screen configured value.
    function barPosition(config: var): string {
        return value("bar.position", config ? config.bar.position : GlobalConfig.bar.position);
    }
}
