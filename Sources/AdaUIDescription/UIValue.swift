import Foundation

/// Detached values shared by UI documents, tools, and runtime bindings.
public indirect enum UIValue: Codable, Hashable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([UIValue])
    case object([String: UIValue])

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([UIValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: UIValue].self)) }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    public var string: String? { if case .string(let value) = self { value } else { nil } }
    public var number: Double? { if case .number(let value) = self { value } else { nil } }
    public var bool: Bool? { if case .bool(let value) = self { value } else { nil } }
    public var array: [UIValue]? { if case .array(let value) = self { value } else { nil } }

    public func value(at path: ArraySlice<String>) -> UIValue? {
        guard let key = path.first else { return self }
        guard case .object(let values) = self else { return nil }
        return values[key]?.value(at: path.dropFirst())
    }
}

public enum UIValueType: String, Codable, CaseIterable, Sendable {
    case bool, number, string, array, object, any

    public func accepts(_ value: UIValue) -> Bool {
        switch (self, value) {
        case (.any, _), (.bool, .bool), (.number, .number), (.string, .string), (.array, .array), (.object, .object): true
        default: false
        }
    }
}

/// An argument is either a literal or a named binding; these are never inferred from string contents.
public struct UIArgument: Codable, Hashable, Sendable {
    public var value: UIValue?
    public var binding: String?

    public init(value: UIValue) { self.value = value }
    public init(binding: String) { self.binding = binding }

    private enum CodingKeys: String, CodingKey { case value, binding }
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = container.contains(.value) ? try container.decode(UIValue.self, forKey: .value) : nil
        binding = try container.decodeIfPresent(String.self, forKey: .binding)
    }
}

public struct UIParameter: Codable, Hashable, Sendable {
    public var name: String
    public var type: UIValueType
    public var defaultValue: UIValue?
    public var isBinding: Bool

    public init(_ name: String, type: UIValueType, defaultValue: UIValue? = nil, isBinding: Bool = false) {
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.isBinding = isBinding
    }
}

public struct UIActionSignature: Codable, Hashable, Sendable {
    public var name: String
    public var parameters: [UIParameter]

    public init(_ name: String, parameters: [UIParameter] = []) {
        self.name = name
        self.parameters = parameters
    }
}

public enum UIContentShape: String, Codable, Sendable { case none, single, children }

/// Stable metadata; inspecting a signature never executes application code.
public struct UIDescriptorSignature: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var version: Int
    public var name: String
    public var parameters: [UIParameter]
    public var actions: [UIActionSignature]
    public var content: UIContentShape
    public var platforms: [String]

    public init(
        id: String, name: String, version: Int = 1, parameters: [UIParameter] = [],
        actions: [UIActionSignature] = [], content: UIContentShape = .none, platforms: [String] = []
    ) {
        self.id = id
        self.version = version
        self.name = name
        self.parameters = parameters
        self.actions = actions
        self.content = content
        self.platforms = platforms
    }
}

public struct UIDiagnostic: Error, LocalizedError, Hashable, Sendable {
    public var nodeID: String?
    public var message: String
    public var errorDescription: String? { nodeID.map { "\($0): \(message)" } ?? message }

    public init(_ message: String, nodeID: String? = nil) {
        self.message = message
        self.nodeID = nodeID
    }
}
