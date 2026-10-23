@_spi(Scripting) import AdaECS
import AdaRender
import AdaScene
import AdaSprite
import AdaUtils

enum ShaderGraphScriptError: String, Error { case expired, readOnly, unavailable, unknownParameter, ambiguousName, typeMismatch, invalidSlot }

/// A callback-scoped capability retains only the selected material, never an ECS
/// pointer. VM/native callback coordinators serialize lease checks; values use
/// ShaderGraphMaterial's own synchronization.
final class ShaderGraphScriptHandle {
    let material: ShaderGraphMaterial
    private let writable: Bool
    private let isActive: () -> Bool

    init(material: ShaderGraphMaterial, writable: Bool, isActive: @escaping () -> Bool) {
        self.material = material
        self.writable = writable
        self.isActive = isActive
    }

    func ids() throws -> [String] {
        try check()
        return Set(material.program.parameters.map(\.id) + material.program.textures.compactMap(\.parameterID)).sorted()
    }

    func name(_ reference: String) throws -> String {
        let id = try resolve(reference)
        return material.program.parameters.first { $0.id == id }?.displayName ?? material.program.textures.first { $0.parameterID == id }?.displayName ?? id
    }

    func type(_ reference: String) throws -> ShaderGraph.ValueType {
        let id = try resolve(reference)
        if let parameter = material.program.parameters.first(where: { $0.id == id }) {
            return parameter.type
        }
        return .texture2D
    }

    func value(_ reference: String, type: ShaderGraph.ValueType) throws -> [Float] {
        let id = try checkedID(reference, type: type)
        guard let value = material.value(for: id) else { throw ShaderGraphScriptError.unavailable }
        return value
    }

    func set(_ reference: String, type: ShaderGraph.ValueType, value: [Float]) throws {
        try check(writing: true)
        try material.setValue(value, for: checkedID(reference, type: type))
    }

    func texture(_ reference: String) throws -> String {
        let id = try checkedID(reference, type: .texture2D)
        return material.descriptor.textures[id] ?? material.program.textures.first { $0.parameterID == id }?.path ?? ""
    }

    func setTexture(_ reference: String, path: String) throws {
        try check(writing: true)
        try material.setTexturePath(path, for: checkedID(reference, type: .texture2D))
    }

    func reflected(_ reference: String, type: ShaderGraph.ValueType) throws -> ReflectedFieldValue {
        if type == .texture2D {
            return .string(try texture(reference))
        }
        let values = try value(reference, type: type)
        if type == .bool {
            return .bool(values[0] != 0)
        }
        if type == .float {
            return .double(Double(values[0]))
        }
        return .array(values.map { .double(Double($0)) })
    }

    func setReflected(_ reference: String, type: ShaderGraph.ValueType, value: ReflectedFieldValue) throws {
        switch (type, value) {
        case (.texture2D, .string(let path)): try setTexture(reference, path: path)
        case (.bool, .bool(let flag)): try set(reference, type: type, value: [flag ? 1 : 0])
        case (.float, _):
            guard let number = value.validFloatValue else { throw ShaderGraphScriptError.typeMismatch }
            try set(reference, type: type, value: [number])
        case (.vector2, _), (.vector3, _), (.vector4, _), (.color, _):
            let count = type == .vector2 ? 2 : type == .vector3 ? 3 : 4
            guard let values = value.validFloatArray(count: count) else { throw ShaderGraphScriptError.typeMismatch }
            try set(reference, type: type, value: values)
        default: throw ShaderGraphScriptError.typeMismatch
        }
    }

    private func checkedID(_ reference: String, type: ShaderGraph.ValueType) throws -> String {
        let id = try resolve(reference)
        guard try self.type(id) == type else { throw ShaderGraphScriptError.typeMismatch }
        return id
    }

    private func resolve(_ reference: String) throws -> String {
        try check()
        let ids = try ids()
        if ids.contains(reference) {
            return reference
        }
        let names = material.program.parameters.filter { $0.displayName == reference }.map(\.id) + material.program.textures.filter { $0.displayName == reference }.compactMap(\.parameterID)
        guard names.count == 1, let id = names.first else { throw names.isEmpty ? ShaderGraphScriptError.unknownParameter : ShaderGraphScriptError.ambiguousName }
        return id
    }

    private func check(writing: Bool = false) throws {
        guard isActive() else { throw ShaderGraphScriptError.expired }
        guard !writing || writable else { throw ShaderGraphScriptError.readOnly }
    }
}

enum ShaderGraphScriptComponent {
    static func material(world: World, entity: Entity.ID, component: ComponentId, slot: Int) throws -> ShaderGraphMaterial {
        guard slot >= 0 else { throw ShaderGraphScriptError.invalidSlot }
        if component == Sprite.identifier, slot == 0, let graph = world.get(Sprite.self, from: entity)?.graphMaterial {
            return graph
        }
        if component == Mesh3DComponent.identifier, let mesh = world.get(Mesh3DComponent.self, from: entity), mesh.materials.indices.contains(slot),
            let graph = (mesh.materials[slot] as? PBRMaterial)?.graphMaterial {
            return graph
        }
        throw ShaderGraphScriptError.unavailable
    }

    static func assign(world: World, entity: Entity.ID, component: ComponentId, slot: Int, path: String) throws -> Bool {
        guard slot >= 0 else { throw ShaderGraphScriptError.invalidSlot }
        let graph = path.isEmpty ? nil : try ShaderGraphMaterial(source: .init(path: path))
        if component == Sprite.identifier, var sprite = world.get(Sprite.self, from: entity) {
            guard slot == 0 else { throw ShaderGraphScriptError.invalidSlot }
            guard graph == nil || graph?.program.target == .sprite else { throw ShaderGraphScriptError.typeMismatch }
            sprite.graphMaterial = graph
            world.insert(sprite, for: entity)
            return true
        }
        if component == Mesh3DComponent.identifier, var mesh = world.get(Mesh3DComponent.self, from: entity), mesh.materials.indices.contains(slot),
            let original = mesh.materials[slot] as? PBRMaterial {
            guard graph == nil || graph?.program.target == .pbrSurface else { throw ShaderGraphScriptError.typeMismatch }
            let instance = original.makeInstance()
            instance.graphMaterial = graph
            mesh.materials[slot] = instance
            world.insert(mesh, for: entity)
            return true
        }
        throw ShaderGraphScriptError.unavailable
    }

    static func material(cursor: DynamicQueryCursor, index: Int, slot: Int) throws -> ShaderGraphMaterial {
        guard slot >= 0 else { throw ShaderGraphScriptError.invalidSlot }
        if let sprite = cursor.readTyped(Sprite.self, componentAt: index), slot == 0, let graph = sprite.graphMaterial {
            return graph
        }
        if let mesh = cursor.readTyped(Mesh3DComponent.self, componentAt: index), mesh.materials.indices.contains(slot), let graph = (mesh.materials[slot] as? PBRMaterial)?.graphMaterial {
            return graph
        }
        throw ShaderGraphScriptError.unavailable
    }

    static func assign(cursor: DynamicQueryCursor, index: Int, slot: Int, path: String, writable: Bool) throws -> Bool {
        guard writable else { throw ShaderGraphScriptError.readOnly }
        guard slot >= 0 else { throw ShaderGraphScriptError.invalidSlot }
        let graph = path.isEmpty ? nil : try ShaderGraphMaterial(source: .init(path: path))
        if cursor.readTyped(Sprite.self, componentAt: index) != nil {
            guard slot == 0 else { throw ShaderGraphScriptError.invalidSlot }
            guard graph == nil || graph?.program.target == .sprite else { throw ShaderGraphScriptError.typeMismatch }
            return cursor.updateTyped(Sprite.self, componentAt: index) { $0.graphMaterial = graph }
        }
        if let mesh = cursor.readTyped(Mesh3DComponent.self, componentAt: index), mesh.materials.indices.contains(slot), let original = mesh.materials[slot] as? PBRMaterial {
            guard graph == nil || graph?.program.target == .pbrSurface else { throw ShaderGraphScriptError.typeMismatch }
            let instance = original.makeInstance()
            instance.graphMaterial = graph
            return cursor.updateTyped(Mesh3DComponent.self, componentAt: index) { $0.materials[slot] = instance }
        }
        throw ShaderGraphScriptError.unavailable
    }
}
