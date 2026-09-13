import Foundation

public enum EditorCloudValue: Codable, Sendable, Equatable, ExpressibleByDictionaryLiteral, ExpressibleByArrayLiteral, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral, ExpressibleByNilLiteral {
    case object([String: EditorCloudValue]), array([EditorCloudValue]), string(String), integer(Int64), number(Double), bool(Bool), null
    public init(dictionaryLiteral elements: (String, EditorCloudValue)...) { self = .object(Dictionary(uniqueKeysWithValues: elements)) }
    public init(arrayLiteral elements: EditorCloudValue...) { self = .array(elements) }
    public init(stringLiteral value: String) { self = .string(value) }
    public init(integerLiteral value: Int64) { self = .integer(value) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(nilLiteral: ()) { self = .null }
    public subscript(_ key: String) -> EditorCloudValue {
        get { object[key] ?? .null }
        set { var fields = object; fields[key] = newValue; self = .object(fields) }
    }
    public var object: [String: EditorCloudValue] { if case .object(let value) = self { value } else { [:] } }
    public var array: [EditorCloudValue] { if case .array(let value) = self { value } else { [] } }
    public var string: String? { if case .string(let value) = self { value } else { nil } }
    public var int: Int64? { if case .integer(let value) = self { value } else { nil } }
    public var bool: Bool? { if case .bool(let value) = self { value } else { nil } }
    public var seconds: Double { switch self { case .number(let n): n; case .integer(let n): Double(n); default: 0 } }
    public init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let v = try? value.decode(Bool.self) { self = .bool(v) }
        else if let v = try? value.decode(Int64.self) { self = .integer(v) }
        else if let v = try? value.decode(Double.self) { self = .number(v) }
        else if let v = try? value.decode(String.self) { self = .string(v) }
        else if let v = try? value.decode([EditorCloudValue].self) { self = .array(v) }
        else { self = .object(try value.decode([String: EditorCloudValue].self)) }
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .integer(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
}
