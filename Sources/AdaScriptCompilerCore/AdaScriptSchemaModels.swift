public struct AdaScriptCompilerSource: Hashable, Sendable {
    public let path: String
    public let source: String

    public init(path: String, source: String) {
        self.path = path
        self.source = source
    }
}

public struct AdaScriptDataSchema: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case component
        case resource(autoInsert: Bool)
    }

    public let fields: [AdaScriptSchemaField]
    public let id: String
    public let kind: Kind
    public let name: String
    public let sourcePath: String
}

public struct AdaScriptSchemaField: Equatable, Sendable {
    public enum Value: Equatable, Sendable {
        case bool(Bool)
        case double(Double)
        case int(Int64)
        case string(String)
    }

    public let defaultValue: Value
    public let name: String

    public init(defaultValue: Value, name: String) {
        self.defaultValue = defaultValue
        self.name = name
    }
}

public struct AdaScriptableSchema: Equatable, Sendable {
    public let aliases: [String]
    public let bindings: [AdaScriptableBinding]
    public let fields: [AdaScriptSchemaField]
    public let id: String
    public let name: String
    public let sourcePath: String
    public let version: Int

    public init(
        aliases: [String],
        bindings: [AdaScriptableBinding] = [],
        fields: [AdaScriptSchemaField],
        id: String,
        name: String,
        sourcePath: String,
        version: Int
    ) {
        self.aliases = aliases
        self.bindings = bindings
        self.fields = fields
        self.id = id
        self.name = name
        self.sourcePath = sourcePath
        self.version = version
    }
}

public struct AdaScriptableBinding: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case component(required: Bool)
        case resource(optional: Bool)
    }

    public let kind: Kind
    public let propertyName: String
    public let typeName: String

    public init(kind: Kind, propertyName: String, typeName: String) {
        self.kind = kind
        self.propertyName = propertyName
        self.typeName = typeName
    }
}

public struct AdaScriptResourceBinding: Equatable, Sendable {
    public let isOptional: Bool
    public let propertyName: String
    public let resourceName: String
    public let systemName: String

    public init(isOptional: Bool, propertyName: String, resourceName: String, systemName: String) {
        self.isOptional = isOptional
        self.propertyName = propertyName
        self.resourceName = resourceName
        self.systemName = systemName
    }
}

public struct AdaScriptSystemCapabilities: Equatable, Sendable {
    public let systemName: String
    public let usesDeferredCommands: Bool

    public init(systemName: String, usesDeferredCommands: Bool) {
        self.systemName = systemName
        self.usesDeferredCommands = usesDeferredCommands
    }
}

/// Compile-time metadata for a declarative AdaUI view declared in Ada Script.
public struct AdaScriptViewSchema: Equatable, Sendable {
    public let className: String
    public let environment: [AdaScriptViewEnvironmentBinding]
    public let id: String
    public let isIDExplicit: Bool
    public let isPreviewable: Bool
    public let isTitleExplicit: Bool
    public let line: Int
    public let sourcePath: String
    public let title: String

    public init(
        className: String,
        environment: [AdaScriptViewEnvironmentBinding] = [],
        id: String,
        isIDExplicit: Bool = true,
        isPreviewable: Bool = false,
        isTitleExplicit: Bool = true,
        line: Int,
        sourcePath: String,
        title: String
    ) {
        self.className = className
        self.environment = environment
        self.id = id
        self.isIDExplicit = isIDExplicit
        self.isPreviewable = isPreviewable
        self.isTitleExplicit = isTitleExplicit
        self.line = line
        self.sourcePath = sourcePath
        self.title = title
    }
}

public struct AdaScriptViewEnvironmentBinding: Equatable, Sendable {
    public let key: String
    public let propertyName: String

    public init(key: String, propertyName: String) {
        self.key = key
        self.propertyName = propertyName
    }
}

func humanizedAdaScriptViewTitle(_ name: String) -> String {
    let characters = Array(name)
    var result = ""
    for index in characters.indices {
        let character = characters[index]
        if character == "_" {
            if result.last != " " {
                result.append(" ")
            }
        } else {
            let previous = index > characters.startIndex ? characters[index - 1] : nil
            let nextIndex = characters.index(after: index)
            let next = nextIndex < characters.endIndex ? characters[nextIndex] : nil
            let startsWord = character.isUppercase && (
                previous?.isLowercase == true
                    || previous?.isNumber == true
                    || (previous?.isUppercase == true && next?.isLowercase == true)
            )
            if startsWord, result.last != " " {
                result.append(" ")
            }
            result.append(character)
        }
    }
    return result
}

public enum AdaScriptSchemaError: Error, Equatable, CustomStringConvertible {
    case duplicateID(String)
    case duplicateName(String)
    case invalid(path: String, message: String)

    public var description: String {
        switch self {
        case .duplicateID(let id):
            "Duplicate Ada Script data id '\(id)'"
        case .duplicateName(let name):
            "Duplicate Ada Script data declaration '\(name)'"
        case let .invalid(path, message):
            "Invalid Ada Script schema in '\(path)': \(message)"
        }
    }
}
