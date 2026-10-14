import AdaEngine
import AdaScriptCompilerCore
import AdaUIDescription

extension AdaScriptSchemaField.Value {
    /// The inspector control used to edit a field with this default.
    var editorFieldKind: EditorComponentFieldKind {
        switch self {
        case .bool: .bool
        case .double: .float
        case .int: .int
        case .string: .string
        case let .vector(components): components.count == 2 ? .vector2 : components.count == 3 ? .vector3 : .vector4
        case .color: .color
        case let .enumeration(_, cases, _): .enumeration(cases)
        // Entity references are plain integer ids (-1 is "none") until the inspector gains an entity picker.
        case .entity: .int
        case .asset: .assetReference
        }
    }

    var editorSceneValue: EditorSceneValue {
        switch self {
        case let .bool(value): .bool(value)
        case let .double(value): .double(value)
        case let .int(value): .int(Int(value))
        case let .string(value): .string(value)
        case let .vector(components): .array(components.map(EditorSceneValue.double))
        case let .color(components): .object(Dictionary(uniqueKeysWithValues: zip(["red", "green", "blue", "alpha"], components.map(EditorSceneValue.double))))
        case let .enumeration(_, _, selected): .string(selected)
        case .entity: .int(-1)
        case let .asset(path): path.map(EditorSceneValue.string) ?? .null
        }
    }

    var reflectedValue: ReflectedFieldValue {
        switch self {
        case let .bool(value): .bool(value)
        case let .double(value): .double(value)
        case let .int(value): .int(Int(value))
        case let .string(value): .string(value)
        case let .vector(components): .array(components.map(ReflectedFieldValue.double))
        case let .color(components): .object(Dictionary(uniqueKeysWithValues: zip(["red", "green", "blue", "alpha"], components.map(ReflectedFieldValue.double))))
        case let .enumeration(_, _, selected): .string(selected)
        case .entity: .int(-1)
        case let .asset(path): path.map(ReflectedFieldValue.string) ?? .null
        }
    }

    var uiValue: UIValue {
        switch self {
        case let .bool(value): .bool(value)
        case let .int(value): .number(Double(value))
        case let .double(value): .number(value)
        case let .string(value): .string(value)
        case let .vector(components), let .color(components): .array(components.map(UIValue.number))
        case let .enumeration(_, _, selected): .string(selected)
        case .entity: .number(-1)
        case let .asset(path): path.map(UIValue.string) ?? .null
        }
    }
}
