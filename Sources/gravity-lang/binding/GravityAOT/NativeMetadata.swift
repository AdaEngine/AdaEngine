import CGravity

public indirect enum NativeLiteral: Equatable, Sendable {
    case null, boolean(Bool), integer(Int64), double(Double), string(String), identifier(String), list([NativeLiteral])

    public var string: String? {
        switch self { case let .string(value), let .identifier(value): value; default: nil }
    }
    public var identifiers: [String] {
        switch self {
        case let .identifier(value): [value]
        case let .list(values): values.compactMap { if case let .identifier(v) = $0 { v } else { nil } }
        default: []
        }
    }
}

public struct NativeAttribute: Equatable, Sendable {
    public struct Argument: Equatable, Sendable {
        public let label: String?
        public let value: NativeLiteral
    }
    public let name: String
    public let arguments: [Argument]
    public let fileID: UInt32
    public let line: UInt32
    public let column: UInt32

    public func argument(_ label: String) -> NativeLiteral? { arguments.first { $0.label == label }?.value }
    public var positional: [NativeLiteral] { arguments.filter { $0.label == nil }.map(\.value) }
}

public struct NativeDeclaration: Equatable, Sendable {
    public enum Kind: UInt32, Sendable { case function, `class`, `struct`, field, method }
    public struct Parameter: Equatable, Sendable { public let name: String; public let type: String? }
    public let name: String
    public let parent: String?
    public let type: String?
    public let kind: Kind
    public let attributes: [NativeAttribute]
    public let parameters: [Parameter]
    public let line: UInt32

    public func attribute(_ name: String) -> NativeAttribute? { attributes.first { $0.name == name } }
}

public struct NativeType: Equatable, Sendable {
    public struct Field: Equatable, Sendable {
        public let declaration: NativeDeclaration
        public let defaultValue: NativeLiteral
        public let isReadOnly: Bool
    }
    public let declaration: NativeDeclaration
    public let fields: [Field]
    public let methods: [NativeDeclaration]
    public var name: String { declaration.name }
    public var isStruct: Bool { declaration.kind == .struct }
}

public enum NativeRuntimeError: Error, Equatable, Sendable {
    case incompatibleABI(UInt32)
    case malformedMetadata(String)
    case unknownType(String)
    case foreignInstance
    case runtime(code: UInt32, detail: String?)
    case allocationLimit
    case unsupportedValue
    case reentrantCall
}

func nativeString(_ pointer: UnsafePointer<CChar>?) throws -> String {
    guard let pointer else { throw NativeRuntimeError.malformedMetadata("Missing name") }
    return String(cString: pointer)
}
func nativeArray<T>(_ pointer: UnsafePointer<T>?, _ count: UInt32) throws -> UnsafeBufferPointer<T> {
    guard count < 1_000_000, count == 0 || pointer != nil else {
        throw NativeRuntimeError.malformedMetadata("Invalid array count or pointer")
    }
    return UnsafeBufferPointer(start: pointer, count: Int(count))
}
func nativeAttributeValue(_ p: UnsafePointer<gravity_aot_attribute_value>, depth: Int = 0) throws -> NativeLiteral {
    guard depth < 64 else { throw NativeRuntimeError.malformedMetadata("Attribute nesting exceeds 64") }
    let value = p.pointee
    switch value.kind {
    case 0: return .identifier(try nativeString(value.text))
    case 1: return .string(try nativeString(value.text))
    case 2: return .integer(value.integer)
    case 3: return .double(value.floating)
    case 4: return .boolean(value.integer != 0)
    case 5: return .null
    case 6:
        return .list(try nativeArray(value.items, value.count).map {
            guard let item = $0 else { throw NativeRuntimeError.malformedMetadata("Null attribute item") }
            return try nativeAttributeValue(item, depth: depth + 1)
        })
    default: throw NativeRuntimeError.malformedMetadata("Unknown attribute value kind")
    }
}
func nativeDeclaration(_ p: UnsafePointer<gravity_aot_declaration>) throws -> NativeDeclaration {
    let d = p.pointee
    guard let kind = NativeDeclaration.Kind(rawValue: d.kind) else {
        throw NativeRuntimeError.malformedMetadata("Unknown declaration kind")
    }
    let attributes = try nativeArray(d.attributes, d.attribute_count).map { a in
        NativeAttribute(
            name: try nativeString(a.name),
            arguments: try nativeArray(a.arguments, a.argument_count).map { arg in
                guard let value = arg.value else { throw NativeRuntimeError.malformedMetadata("Null attribute argument") }
                return NativeAttribute.Argument(label: arg.label.map { String(cString: $0) }, value: try nativeAttributeValue(value))
            },
            fileID: a.fileid, line: a.line, column: a.column
        )
    }
    return NativeDeclaration(
        name: try nativeString(d.name), parent: d.parent.map { String(cString: $0) }, type: d.type_name.map { String(cString: $0) },
        kind: kind, attributes: attributes,
        parameters: try nativeArray(d.parameters, d.parameter_count).map {
            NativeDeclaration.Parameter(name: try nativeString($0.name), type: $0.type_name.map { String(cString: $0) })
        }, line: d.line
    )
}
func nativeLiteral(_ value: gravity_aot_value) throws -> NativeLiteral {
    switch value.kind {
    case 0: .null
    case 1: .integer(value.integer)
    case 2: .boolean(value.integer != 0)
    case 3: .double(value.floating)
    case 4:
        if let p = value.string { .string(String(decoding: UnsafeRawBufferPointer(start: p, count: Int(value.length)), as: UTF8.self)) }
        else { throw NativeRuntimeError.malformedMetadata("Null string") }
    default: throw NativeRuntimeError.unsupportedValue
    }
}
