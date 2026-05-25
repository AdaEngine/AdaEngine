@_spi(AdaEngine) import AdaEngine
import Foundation

enum EditorBuiltInComponentType {
    static let transform = String(reflecting: Transform.self)
    static let camera = String(reflecting: Camera.self)
    static let sprite = String(reflecting: Sprite.self)
    static let visibility = String(reflecting: Visibility.self)
    static let light2D = String(reflecting: Light2D.self)
    static let lightOccluder2D = String(reflecting: LightOccluder2D.self)
    static let lightModulate2D = String(reflecting: LightModulate2D.self)
    static let globalTransform = String(reflecting: GlobalTransform.self)
    static let bounding = String(reflecting: BoundingComponent.self)
}

enum EditorComponentFieldKind: Equatable, Sendable {
    case bool
    case int
    case float
    case string
    case enumeration([String])
    case vector2
    case vector3
    case vector4
    case color
    case assetReference
    case readOnly
}

extension EditorComponentFieldKind {
    init(reflectedKind: EditorFieldKind) {
        switch reflectedKind {
        case .bool:
            self = .bool
        case .int:
            self = .int
        case .float:
            self = .float
        case .string:
            self = .string
        case .enumeration(let cases):
            self = .enumeration(cases)
        case .vector2:
            self = .vector2
        case .vector3:
            self = .vector3
        case .vector4:
            self = .vector4
        case .color:
            self = .color
        case .assetReference:
            self = .assetReference
        case .readOnly:
            self = .readOnly
        }
    }
}

struct EditorComponentField: Equatable, Identifiable, Sendable {
    var id: String { key }
    var key: String
    var label: String
    var kind: EditorComponentFieldKind
    var isEditable: Bool

    init(key: String, label: String, kind: EditorComponentFieldKind, isEditable: Bool = true) {
        self.key = key
        self.label = label
        self.kind = kind
        self.isEditable = isEditable
    }

    func displayValue(in payload: EditorComponentPayload) -> String {
        switch kind {
        case .color:
            guard let color = payload[key]?.colorComponents else {
                return ""
            }
            return color.map(EditorSceneModelFormatting.format).joined(separator: ", ")
        default:
            return payload[key]?.stringValue ?? ""
        }
    }

    func write(_ rawValue: String, to payload: inout EditorComponentPayload) {
        guard isEditable else {
            return
        }

        switch kind {
        case .bool:
            payload[key] = .bool(rawValue.lowercased() == "true" || rawValue == "1")
        case .int:
            payload[key] = .int(Int(rawValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0)
        case .float:
            payload[key] = .double(Double(rawValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0)
        case .string, .assetReference:
            payload[key] = rawValue.isEmpty ? .null : .string(rawValue)
        case .enumeration(let cases):
            payload[key] = .string(cases.contains(rawValue) ? rawValue : cases.first ?? rawValue)
        case .vector2:
            payload[key] = .array(Self.parseVector(rawValue, count: 2))
        case .vector3:
            payload[key] = .array(Self.parseVector(rawValue, count: 3))
        case .vector4:
            payload[key] = .array(Self.parseVector(rawValue, count: 4))
        case .color:
            let values = Self.parseVector(rawValue, count: 4).map { $0.doubleValue ?? 0 }
            payload[key] = .object([
                "red": .double(values[0]),
                "green": .double(values[1]),
                "blue": .double(values[2]),
                "alpha": .double(values[3])
            ])
        case .readOnly:
            break
        }
    }

    private static func parseVector(_ value: String, count: Int) -> [EditorSceneValue] {
        var numbers = value
            .split { $0 == "," || $0 == " " || $0 == "\t" }
            .map { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0 }
        if numbers.count < count {
            numbers.append(contentsOf: Array(repeating: 0, count: count - numbers.count))
        }
        return numbers.prefix(count).map(EditorSceneValue.double)
    }
}

struct EditorComponentDescriptor: @unchecked Sendable {
    var typeName: String
    var displayName: String
    var category: String
    var requiredComponentTypeNames: [String]
    var fields: [EditorComponentField]
    var makeDefaultPayload: @Sendable () -> EditorComponentPayload
    var decode: @Sendable (EditorComponentPayload) throws -> any Component
}

enum EditorComponentRegistry {
    static var descriptors: [EditorComponentDescriptor] {
        let overrideNames = Set(overrideDescriptors.map(\.typeName))
        let reflectedDescriptors = EditorComponentReflectionRegistry
            .allDescriptors()
            .filter { !overrideNames.contains($0.typeName) }
            .map(editorDescriptor(from:))
        return overrideDescriptors + reflectedDescriptors
    }

    private static let overrideDescriptors: [EditorComponentDescriptor] = [
        transformDescriptor,
        cameraDescriptor,
        spriteDescriptor,
        visibilityDescriptor,
        light2DDescriptor,
        lightOccluder2DDescriptor,
        lightModulate2DDescriptor
    ]

    private static let overrideDescriptorsByName: [String: EditorComponentDescriptor] = Dictionary(
        uniqueKeysWithValues: overrideDescriptors.map { ($0.typeName, $0) }
    )

    @MainActor
    static func registerBuiltIns() {
        Transform.registerComponent()
        GlobalTransform.registerComponent()
        Camera.registerComponent()
        Sprite.registerComponent()
        Visibility.registerComponent()
        BoundingComponent.registerComponent()
        Light2D.registerComponent()
        LightOccluder2D.registerComponent()
        LightModulate2D.registerComponent()

        EditorComponentReflectionRegistry.register(Transform.editorComponentDescriptor)
        EditorComponentReflectionRegistry.register(GlobalTransform.editorComponentDescriptor)
        EditorComponentReflectionRegistry.register(Camera.editorComponentDescriptor)
        EditorComponentReflectionRegistry.register(Sprite.editorComponentDescriptor)
        EditorComponentReflectionRegistry.register(Visibility.editorComponentDescriptor)
        EditorComponentReflectionRegistry.register(BoundingComponent.editorComponentDescriptor)
        EditorComponentReflectionRegistry.register(Light2D.editorComponentDescriptor)
        EditorComponentReflectionRegistry.register(LightOccluder2D.editorComponentDescriptor)
        EditorComponentReflectionRegistry.register(LightModulate2D.editorComponentDescriptor)
    }

    static func descriptor(named typeName: String) -> EditorComponentDescriptor? {
        overrideDescriptorsByName[typeName] ?? EditorComponentReflectionRegistry.descriptor(named: typeName).map(editorDescriptor(from:))
    }

    static func addableDescriptors(for entity: EditorSceneEntity?) -> [EditorComponentDescriptor] {
        descriptors.filter { descriptor in
            guard let entity else {
                return true
            }
            return entity.components[descriptor.typeName] == nil
        }
    }

    static func defaultPayload(for typeName: String) -> EditorComponentPayload {
        overrideDescriptorsByName[typeName]?.makeDefaultPayload() ?? [:]
    }

    static func decode(typeName: String, payload: EditorComponentPayload) throws -> (any Component)? {
        if let descriptor = overrideDescriptorsByName[typeName] {
            return try descriptor.decode(payload)
        }

        guard let componentType = RuntimeTypeRegistry.componentType(named: typeName),
              let decodableType = componentType as? Decodable.Type else {
            return nil
        }
        let value = try EditorComponentPayloadDecoder.decode(decodableType, payload: payload)
        return value as? any Component
    }

    private static func editorDescriptor(from descriptor: AdaECS.EditorComponentDescriptor) -> EditorComponentDescriptor {
        EditorComponentDescriptor(
            typeName: descriptor.typeName,
            displayName: descriptor.displayName,
            category: "Reflected",
            requiredComponentTypeNames: descriptor.requiredComponentTypeNames,
            fields: descriptor.fields.map {
                EditorComponentField(
                    key: $0.key,
                    label: $0.label,
                    kind: EditorComponentFieldKind(reflectedKind: $0.kind),
                    isEditable: $0.isEditable
                )
            },
            makeDefaultPayload: { [:] },
            decode: { payload in
                guard let componentType = RuntimeTypeRegistry.componentType(named: descriptor.typeName),
                      let decodableType = componentType as? Decodable.Type,
                      let component = try EditorComponentPayloadDecoder.decode(decodableType, payload: payload) as? any Component else {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(codingPath: [], debugDescription: "Cannot decode reflected component \(descriptor.typeName)")
                    )
                }
                return component
            }
        )
    }
}

private extension EditorComponentRegistry {
    static let transformDescriptor = EditorComponentDescriptor(
        typeName: EditorBuiltInComponentType.transform,
        displayName: "Transform",
        category: "Core",
        requiredComponentTypeNames: [],
        fields: [
            EditorComponentField(key: "position", label: "Position", kind: .vector3),
            EditorComponentField(key: "rotation", label: "Rotation", kind: .vector4),
            EditorComponentField(key: "scale", label: "Scale", kind: .vector3)
        ],
        makeDefaultPayload: {
            [
                "position": .array([.double(0), .double(0), .double(0)]),
                "rotation": .array([.double(0), .double(0), .double(0), .double(1)]),
                "scale": .array([.double(1), .double(1), .double(1)])
            ]
        },
        decode: { payload in
            try EditorComponentPayloadDecoder.decode(Transform.self, payload: payload) as! Transform
        }
    )

    static let cameraDescriptor = EditorComponentDescriptor(
        typeName: EditorBuiltInComponentType.camera,
        displayName: "Camera",
        category: "Rendering",
        requiredComponentTypeNames: [],
        fields: [
            EditorComponentField(key: "isActive", label: "Active", kind: .bool),
            EditorComponentField(key: "renderOrder", label: "Render Order", kind: .int),
            EditorComponentField(key: "backgroundColor", label: "Background", kind: .color)
        ],
        makeDefaultPayload: {
            [
                "isActive": .bool(true),
                "renderOrder": .int(0),
                "backgroundColor": .object([
                    "red": .double(43.0 / 255.0),
                    "green": .double(44.0 / 255.0),
                    "blue": .double(47.0 / 255.0),
                    "alpha": .double(1)
                ])
            ]
        },
        decode: { payload in
            var camera = Camera()
            camera.isActive = payload["isActive"]?.boolValue ?? true
            camera.renderOrder = Int(payload["renderOrder"]?.doubleValue ?? 0)
            camera.backgroundColor = payload["backgroundColor"]?.colorValue ?? .surfaceClearColor
            return camera
        }
    )

    static let spriteDescriptor = EditorComponentDescriptor(
        typeName: EditorBuiltInComponentType.sprite,
        displayName: "Sprite",
        category: "2D",
        requiredComponentTypeNames: [EditorBuiltInComponentType.visibility],
        fields: [
            EditorComponentField(key: "tintColor", label: "Tint", kind: .color),
            EditorComponentField(key: "flipX", label: "Flip X", kind: .bool),
            EditorComponentField(key: "flipY", label: "Flip Y", kind: .bool),
            EditorComponentField(key: "texture", label: "Texture", kind: .assetReference, isEditable: false),
            EditorComponentField(key: "size", label: "Size", kind: .vector2, isEditable: false)
        ],
        makeDefaultPayload: {
            [
                "texture": .null,
                "tintColor": .object(["red": .double(1), "green": .double(1), "blue": .double(1), "alpha": .double(1)]),
                "flipX": .bool(false),
                "flipY": .bool(false),
                "size": .null
            ]
        },
        decode: { payload in
            try EditorComponentPayloadDecoder.decode(Sprite.self, payload: payload) as! Sprite
        }
    )

    static let visibilityDescriptor = EditorComponentDescriptor(
        typeName: EditorBuiltInComponentType.visibility,
        displayName: "Visibility",
        category: "Rendering",
        requiredComponentTypeNames: [],
        fields: [
            EditorComponentField(key: "value", label: "State", kind: .enumeration(["visible", "hidden", "inherited"]))
        ],
        makeDefaultPayload: {
            ["value": .string("visible")]
        },
        decode: { payload in
            switch payload["value"]?.stringValue {
            case "hidden":
                return Visibility.hidden
            case "inherited":
                return Visibility.inherited
            default:
                return Visibility.visible
            }
        }
    )

    static let light2DDescriptor = EditorComponentDescriptor(
        typeName: EditorBuiltInComponentType.light2D,
        displayName: "Light 2D",
        category: "2D",
        requiredComponentTypeNames: [EditorBuiltInComponentType.visibility],
        fields: [
            EditorComponentField(key: "kind", label: "Kind", kind: .enumeration(["point", "directional"])),
            EditorComponentField(key: "color", label: "Color", kind: .color),
            EditorComponentField(key: "energy", label: "Energy", kind: .float),
            EditorComponentField(key: "isEnabled", label: "Enabled", kind: .bool),
            EditorComponentField(key: "direction", label: "Direction", kind: .vector2),
            EditorComponentField(key: "radius", label: "Radius", kind: .float),
            EditorComponentField(key: "spotAngle", label: "Spot Angle", kind: .float),
            EditorComponentField(key: "castsShadows", label: "Casts Shadows", kind: .bool)
        ],
        makeDefaultPayload: {
            [
                "kind": .string("point"),
                "color": .object(["red": .double(1), "green": .double(1), "blue": .double(1), "alpha": .double(1)]),
                "energy": .double(1),
                "isEnabled": .bool(true),
                "direction": .array([.double(0), .double(-1)]),
                "radius": .double(400),
                "spotAngle": .double(0),
                "texture": .null,
                "castsShadows": .bool(true)
            ]
        },
        decode: { payload in
            Light2D(
                kind: payload["kind"]?.stringValue == "directional" ? .directional : .point,
                color: payload["color"]?.colorValue ?? .white,
                energy: Float(payload["energy"]?.doubleValue ?? 1),
                isEnabled: payload["isEnabled"]?.boolValue ?? true,
                direction: payload["direction"]?.vector2Value ?? Vector2(0, -1),
                radius: Float(payload["radius"]?.doubleValue ?? 400),
                spotAngle: Float(payload["spotAngle"]?.doubleValue ?? 0),
                texture: nil,
                castsShadows: payload["castsShadows"]?.boolValue ?? true
            )
        }
    )

    static let lightOccluder2DDescriptor = EditorComponentDescriptor(
        typeName: EditorBuiltInComponentType.lightOccluder2D,
        displayName: "Light Occluder 2D",
        category: "2D",
        requiredComponentTypeNames: [EditorBuiltInComponentType.visibility],
        fields: [
            EditorComponentField(key: "isEnabled", label: "Enabled", kind: .bool),
            EditorComponentField(key: "points", label: "Points", kind: .readOnly, isEditable: false)
        ],
        makeDefaultPayload: {
            ["points": .array([]), "isEnabled": .bool(true)]
        },
        decode: { payload in
            try EditorComponentPayloadDecoder.decode(LightOccluder2D.self, payload: payload) as! LightOccluder2D
        }
    )

    static let lightModulate2DDescriptor = EditorComponentDescriptor(
        typeName: EditorBuiltInComponentType.lightModulate2D,
        displayName: "Light Modulate 2D",
        category: "2D",
        requiredComponentTypeNames: [],
        fields: [
            EditorComponentField(key: "color", label: "Color", kind: .color)
        ],
        makeDefaultPayload: {
            ["color": .object(["red": .double(1), "green": .double(1), "blue": .double(1), "alpha": .double(1)])]
        },
        decode: { payload in
            try EditorComponentPayloadDecoder.decode(LightModulate2D.self, payload: payload) as! LightModulate2D
        }
    )
}

enum EditorComponentPayloadDecoder {
    static func decode(_ type: Decodable.Type, payload: EditorComponentPayload) throws -> Any {
        let object = payload.reduce(into: [String: Any]()) { result, item in
            result[item.key] = normalizedComponentValue(item.value.jsonCompatibleValue, key: item.key)
        }
        let data = try JSONSerialization.data(withJSONObject: object, options: [])
        return try DynamicDecodableValue.decode(type, from: data)
    }

    private static func normalizedComponentValue(_ value: Any, key: String) -> Any {
        guard let array = value as? [Any] else {
            return value
        }

        switch (key, array.count) {
        case ("position", 3), ("scale", 3):
            return ["x": array[0], "y": array[1], "z": array[2]]
        case ("rotation", 4):
            return ["x": array[0], "y": array[1], "z": array[2], "w": array[3]]
        case ("direction", 2):
            return ["x": array[0], "y": array[1]]
        default:
            return value
        }
    }
}

private struct DynamicDecodableValue: Decodable {
    nonisolated(unsafe) private static var type: Decodable.Type?
    let value: Any

    static func decode(_ type: Decodable.Type, from data: Data) throws -> Any {
        self.type = type
        defer { self.type = nil }
        return try JSONDecoder().decode(Self.self, from: data).value
    }

    init(from decoder: Decoder) throws {
        guard let type = Self.type else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing dynamic component type")
            )
        }

        self.value = try type.init(from: decoder)
    }
}

private extension EditorSceneValue {
    var colorComponents: [Double]? {
        guard case .object(let object) = self else {
            return nil
        }
        return [
            object["red"]?.doubleValue ?? 0,
            object["green"]?.doubleValue ?? 0,
            object["blue"]?.doubleValue ?? 0,
            object["alpha"]?.doubleValue ?? 1
        ]
    }

    var colorValue: Color? {
        guard let colorComponents else {
            return nil
        }
        return Color(
            red: Float(colorComponents[0]),
            green: Float(colorComponents[1]),
            blue: Float(colorComponents[2]),
            alpha: Float(colorComponents[3])
        )
    }

    var vector2Value: Vector2? {
        guard case .array(let values) = self, values.count >= 2 else {
            return nil
        }
        return Vector2(Float(values[0].doubleValue ?? 0), Float(values[1].doubleValue ?? 0))
    }
}
