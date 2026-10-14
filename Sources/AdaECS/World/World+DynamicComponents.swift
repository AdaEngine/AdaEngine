import Foundation

/// Component access by script name or stable ID, for hosts that cannot name a component's Swift type.
///
/// AdaScript data components are either generated native structs (registered in
/// ``RuntimeTypeRegistry``) or runtime payloads described by ``RuntimeComponentDescriptor``.
/// These operations resolve both the same way, validate every value against the component's
/// reflected fields, and never partially apply a change.
extension World {
    /// Resolves a component's identity from a registered name, stable ID, or runtime descriptor.
    public func dynamicComponentID(named name: String) -> ComponentId? {
        if let descriptor = runtimeComponentDescriptor(named: name) {
            return descriptor.componentID
        }
        return RuntimeTypeRegistry.componentType(named: name)?.identifier
    }

    /// Removes the named component. Returns `false` when the name is unknown or the entity lacks the component.
    @discardableResult
    public func removeDynamicComponent(named name: String, from entity: Entity.ID) -> Bool {
        guard let identifier = dynamicComponentID(named: name), has(identifier, in: entity) else {
            return false
        }
        remove(identifier, from: entity)
        return true
    }

    /// Reads every reflected field of the named component, or `nil` when it is unknown or absent.
    public func dynamicComponentPayload(named name: String, of entity: Entity.ID) -> [String: ReflectedFieldValue]? {
        if let descriptor = runtimeComponentDescriptor(named: name) {
            guard let payload = getRuntimeComponent(descriptor.componentID, from: entity) else {
                return nil
            }
            var result: [String: ReflectedFieldValue] = [:]
            for (field, value) in zip(descriptor.fields, payload.values) {
                result[field.key] = value
            }
            return result
        }
        guard
            let type = RuntimeTypeRegistry.componentType(named: name),
            let component = getComponent(named: name, from: entity),
            let descriptor = ComponentReflectionRegistry.descriptor(named: String(reflecting: type))
        else {
            return nil
        }
        return descriptor.readPayload(from: component)
    }

    /// Encodes the named component's fields as a JSON object.
    public func encodeDynamicComponent(named name: String, of entity: Entity.ID) throws -> Data? {
        guard let payload = dynamicComponentPayload(named: name, of: entity) else {
            return nil
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(payload)
    }

    /// Inserts the named component starting from its default, overriding `fields`.
    ///
    /// Returns `false` without changing the entity when the name has no default, a field is
    /// unknown, or a value is rejected by the field's reflection.
    @discardableResult
    public func insertDynamicComponent(
        named name: String,
        fields: [String: ReflectedFieldValue] = [:],
        into entity: Entity.ID
    ) -> Bool {
        guard getEntityByID(entity) != nil else {
            return false
        }
        if let descriptor = runtimeComponentDescriptor(named: name) {
            var payload = descriptor.makeDefault()
            for (key, value) in fields {
                guard
                    let index = descriptor.fields.firstIndex(where: { $0.key == key }),
                    descriptor.fields[index].accepts(value),
                    let updated = descriptor.fields[index].write(payload, value) as? RuntimeComponentPayload
                else {
                    return false
                }
                payload = updated
            }
            insertRuntimeComponent(payload, for: entity)
            return true
        }
        guard
            var component = RuntimeTypeRegistry.makeDefaultComponent(named: name),
            let type = RuntimeTypeRegistry.componentType(named: name)
        else {
            return false
        }
        if !fields.isEmpty {
            guard let descriptor = ComponentReflectionRegistry.descriptor(named: String(reflecting: type)) else {
                return false
            }
            for (key, value) in fields {
                guard
                    descriptor.fields.contains(where: { $0.key == key && $0.accepts(value) }),
                    let updated = descriptor.writing(value, toField: key, in: component)
                else {
                    return false
                }
                component = updated
            }
        }
        insert(detachedComponent: component, for: entity)
        return true
    }

    /// Decodes a JSON object of field values and inserts the named component with them.
    @discardableResult
    public func insertDynamicComponent(named name: String, json: Data, into entity: Entity.ID) -> Bool {
        guard let fields = try? JSONDecoder().decode([String: ReflectedFieldValue].self, from: json) else {
            return false
        }
        return insertDynamicComponent(named: name, fields: fields, into: entity)
    }

    /// Writes one field of the named component in place, updating its change tick.
    @discardableResult
    public func setDynamicComponentField(
        named name: String,
        field key: String,
        to value: ReflectedFieldValue,
        in entity: Entity.ID
    ) -> Bool {
        if let descriptor = runtimeComponentDescriptor(named: name) {
            guard let field = descriptor.fields.first(where: { $0.key == key }) else {
                return false
            }
            return writeComponentField(component: descriptor.componentID, entity: entity, field: field, value: value)
        }
        guard
            let type = RuntimeTypeRegistry.componentType(named: name),
            let descriptor = ComponentReflectionRegistry.descriptor(named: String(reflecting: type)),
            descriptor.fields.contains(where: { $0.key == key && $0.accepts(value) })
        else {
            return false
        }
        return descriptor.write(value, toField: key, in: self, entity: entity)
    }
}
