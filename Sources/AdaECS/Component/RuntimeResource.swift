import Foundation

/// Reflection metadata for a script-declared `@resource` struct, which has no Swift type of its own.
///
/// The value lives in a ``RuntimeResourceStore`` and is reached through pointer-backed fields, so the
/// existing dynamic resource access (`DynamicResource`, `World.readResourceField`) works unchanged.
@_spi(Scripting)
public struct RuntimeResourceLayout: Sendable {
    public let aliases: [String]
    public let defaults: RuntimeComponentPayload
    public let fields: [ReflectedComponentField]
    public let name: String
    public let stableID: String

    public init(component descriptor: RuntimeComponentDescriptor) {
        let stableID = descriptor.stableID
        self.aliases = descriptor.aliases
        self.defaults = descriptor.makeDefault()
        self.name = descriptor.name
        self.stableID = stableID
        self.fields = descriptor.fields.enumerated().map { index, base in
            unsafe ReflectedComponentField(
                key: base.key,
                label: base.label,
                kind: base.kind,
                isWritable: base.isWritable,
                accepts: base.accepts,
                read: { _ in nil },
                write: { _, _ in nil },
                readPointer: { pointer in
                    let store = unsafe pointer.assumingMemoryBound(to: RuntimeResourceStore.self)
                    guard let payload = unsafe store.pointee.payloads[stableID], payload.values.indices.contains(index) else {
                        return nil
                    }
                    return payload.values[index]
                },
                writePointer: { pointer, value in
                    let store = unsafe pointer.assumingMemoryBound(to: RuntimeResourceStore.self)
                    guard
                        let payload = unsafe store.pointee.payloads[stableID],
                        let updated = base.write(payload, value) as? RuntimeComponentPayload
                    else {
                        return false
                    }
                    unsafe store.pointee.payloads[stableID] = updated
                    return true
                }
            )
        }
    }
}

/// Backing storage for every script-declared `@resource` in a world.
///
/// Resources are keyed by Swift type, so all script resources share this one type; each is a payload
/// addressed by its stable ID.
@_spi(Scripting)
public struct RuntimeResourceStore: Resource {
    public private(set) var layouts: [RuntimeResourceLayout] = []
    public internal(set) var payloads: [String: RuntimeComponentPayload] = [:]

    public init() {}

    /// Adds the layout and its default payload; an existing payload keeps its current values.
    public mutating func register(_ layout: RuntimeResourceLayout) {
        layouts.removeAll { $0.stableID == layout.stableID }
        layouts.append(layout)
        if payloads[layout.stableID] == nil {
            payloads[layout.stableID] = layout.defaults
        }
    }

    public func layout(named name: String) -> RuntimeResourceLayout? {
        layouts.first { $0.name == name || $0.stableID == name || $0.aliases.contains(name) }
    }
}

extension World {
    /// Declares script resources in this world, inserting the store when it is missing.
    @_spi(Scripting)
    public func registerRuntimeResources(_ layouts: [RuntimeResourceLayout]) {
        guard !layouts.isEmpty else {
            return
        }
        var store = getResource(RuntimeResourceStore.self) ?? RuntimeResourceStore()
        for layout in layouts {
            store.register(layout)
        }
        insertResource(store)
    }
}
