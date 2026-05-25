@_spi(AdaEngine) import AdaEngine
import Foundation
import Yams

typealias EditorComponentPayload = [String: EditorSceneValue]

enum EditorSceneValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([EditorSceneValue])
    case object([String: EditorSceneValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([EditorSceneValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: EditorSceneValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported scene value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let values):
            try container.encode(values)
        case .object(let values):
            try container.encode(values)
        }
    }
}

extension EditorSceneValue {
    var jsonCompatibleValue: Any {
        switch self {
        case .null:
            NSNull()
        case .bool(let value):
            value
        case .int(let value):
            value
        case .double(let value):
            value
        case .string(let value):
            value
        case .array(let values):
            values.map(\.jsonCompatibleValue)
        case .object(let values):
            values.mapValues(\.jsonCompatibleValue)
        }
    }

    var stringValue: String {
        switch self {
        case .null:
            ""
        case .bool(let value):
            value ? "true" : "false"
        case .int(let value):
            String(value)
        case .double(let value):
            EditorSceneModelFormatting.format(value)
        case .string(let value):
            value
        case .array(let values):
            values.map(\.stringValue).joined(separator: ", ")
        case .object(let values):
            values
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value.stringValue)" }
                .joined(separator: ", ")
        }
    }

    var doubleValue: Double? {
        switch self {
        case .int(let value):
            Double(value)
        case .double(let value):
            value
        case .string(let value):
            Double(value)
        default:
            nil
        }
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let value):
            value
        case .string("true"):
            true
        case .string("false"):
            false
        default:
            nil
        }
    }
}

struct EditorSceneModel: Codable, Equatable, Sendable {
    var format: String
    var schemaVersion: Int
    var engineVersion: String?
    var scene: EditorSceneMetadata
    var entities: [EditorSceneEntity]
    var editor: EditorSceneState?

    init(
        format: String = "ada.scene",
        schemaVersion: Int = 1,
        engineVersion: String? = "1.0.0",
        scene: EditorSceneMetadata,
        entities: [EditorSceneEntity],
        editor: EditorSceneState? = nil
    ) {
        self.format = format
        self.schemaVersion = schemaVersion
        self.engineVersion = engineVersion
        self.scene = scene
        self.entities = entities
        self.editor = editor
    }

    static func decode(from content: String) throws -> EditorSceneModel {
        try YAMLDecoder(encoding: .utf8).decode(EditorSceneModel.self, from: content)
    }

    func encodedYAML() throws -> String {
        try YAMLEncoder().encode(self)
    }

    static func `default`(projectName: String) -> EditorSceneModel {
        let rootID = "root"
        return EditorSceneModel(
            scene: EditorSceneMetadata(id: UUID().uuidString, name: normalizedSceneName(projectName)),
            entities: [
                EditorSceneEntity(
                    id: rootID,
                    name: "Root",
                    enabled: true,
                    parent: nil,
                    components: [
                        EditorBuiltInComponentType.transform: EditorComponentRegistry.defaultPayload(for: EditorBuiltInComponentType.transform)
                    ]
                )
            ],
            editor: EditorSceneState(selectedEntity: rootID, expandedEntities: [rootID], viewport: [
                "position": .array([.double(0), .double(0)]),
                "zoom": .double(1)
            ])
        )
    }

    mutating func addEntity(name: String = "Entity") -> EditorSceneEntity {
        let selectedID = editor?.selectedEntity
        let entity = EditorSceneEntity(
            id: UUID().uuidString,
            name: name,
            enabled: true,
            parent: selectedID,
            components: [
                EditorBuiltInComponentType.transform: EditorComponentRegistry.defaultPayload(for: EditorBuiltInComponentType.transform)
            ]
        )
        entities.append(entity)
        selectEntity(entity.id)
        return entity
    }

    mutating func selectEntity(_ entityID: String?) {
        var editor = self.editor ?? EditorSceneState()
        editor.selectedEntity = entityID
        if let entityID {
            for expandedEntityID in expandedEntityIDs(for: entityID) where !editor.expandedEntities.contains(expandedEntityID) {
                editor.expandedEntities.append(expandedEntityID)
            }
        }
        self.editor = editor
    }

    mutating func toggleEntityExpanded(_ entityID: String) {
        var editor = self.editor ?? EditorSceneState()
        if let index = editor.expandedEntities.firstIndex(of: entityID) {
            editor.expandedEntities.remove(at: index)
        } else {
            editor.expandedEntities.append(entityID)
        }
        self.editor = editor
    }

    mutating func addComponent(typeName: String, to entityID: String) {
        guard let entityIndex = entities.firstIndex(where: { $0.id == entityID }) else {
            return
        }

        let descriptor = EditorComponentRegistry.descriptor(named: typeName)
        let requiredTypes = descriptor?.requiredComponentTypeNames ?? []
        for requiredType in requiredTypes where entities[entityIndex].components[requiredType] == nil {
            entities[entityIndex].components[requiredType] = EditorComponentRegistry.defaultPayload(for: requiredType)
        }

        guard entities[entityIndex].components[typeName] == nil else {
            return
        }
        entities[entityIndex].components[typeName] = EditorComponentRegistry.defaultPayload(for: typeName)
    }

    mutating func removeComponent(typeName: String, from entityID: String) {
        guard let entityIndex = entities.firstIndex(where: { $0.id == entityID }) else {
            return
        }
        entities[entityIndex].components[typeName] = nil
    }

    mutating func updateField(typeName: String, field: EditorComponentField, value: String, in entityID: String) {
        guard let entityIndex = entities.firstIndex(where: { $0.id == entityID }),
              var payload = entities[entityIndex].components[typeName] else {
            return
        }

        field.write(value, to: &payload)
        entities[entityIndex].components[typeName] = payload
    }

    func selectedEntity() -> EditorSceneEntity? {
        guard let selectedEntity = editor?.selectedEntity else {
            return nil
        }
        return entities.first { $0.id == selectedEntity }
    }

    private static func normalizedSceneName(_ projectName: String) -> String {
        let trimmed = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Main" : trimmed
    }

    private func expandedEntityIDs(for entityID: String) -> [String] {
        var result: [String] = []
        var nextEntityID: String? = entityID
        var visited: Set<String> = []

        while let currentID = nextEntityID, !visited.contains(currentID) {
            visited.insert(currentID)
            result.append(currentID)
            nextEntityID = entities.first { $0.id == currentID }?.parent
        }

        return result.reversed()
    }
}

struct EditorSceneMetadata: Codable, Equatable, Sendable {
    var id: String
    var name: String
}

struct EditorSceneEntity: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var enabled: Bool
    var parent: String?
    var components: [String: EditorComponentPayload]
}

struct EditorSceneState: Codable, Equatable, Sendable {
    var selectedEntity: String?
    var expandedEntities: [String]
    var viewport: [String: EditorSceneValue]?

    init(
        selectedEntity: String? = nil,
        expandedEntities: [String] = [],
        viewport: [String: EditorSceneValue]? = nil
    ) {
        self.selectedEntity = selectedEntity
        self.expandedEntities = expandedEntities
        self.viewport = viewport
    }
}

enum EditorSceneModelFormatting {
    static func format(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.3f", value)
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }
}
