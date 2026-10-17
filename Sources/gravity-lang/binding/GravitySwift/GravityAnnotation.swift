import CGravity

public struct GravityAnnotation: Sendable, Equatable {
    public let name: String
    public let target: Target
    public let arguments: [Argument]
    public let source: SourceLocation

    public init(name: String, target: Target, arguments: [Argument], source: SourceLocation) {
        self.name = name; self.target = target; self.arguments = arguments; self.source = source
    }

    public struct Target: Sendable, Equatable {
        public let kind: Kind
        public let identifier: String
        public let parentIdentifier: String?

        public init(kind: Kind, identifier: String, parentIdentifier: String? = nil) {
            self.kind = kind; self.identifier = identifier; self.parentIdentifier = parentIdentifier
        }

        public enum Kind: UInt32, Sendable, Equatable {
            case enumeration = 7
            case function = 8
            case variableDeclaration = 9
            case `class` = 10
            case module = 11
            case variable = 12
            case unknown = 4_294_967_295
        }
    }

    public struct Argument: Sendable, Equatable {
        public let label: String?
        public let value: Value

        public init(label: String?, value: Value) {
            self.label = label
            self.value = value
        }
    }

    public struct SourceLocation: Sendable, Equatable {
        public let fileID: UInt32
        public let line: UInt32
        public let column: UInt32

        public init(fileID: UInt32, line: UInt32, column: UInt32) {
            self.fileID = fileID; self.line = line; self.column = column
        }
    }

    public indirect enum Value: Sendable, Equatable {
        case identifier(String)
        case string(String)
        case integer(Int64)
        case double(Double)
        case boolean(Bool)
        case null
        case list([Value])
    }
}

extension GravityAnnotation {
    static func collect(from compiler: OpaquePointer) -> [GravityAnnotation] {
        (0..<gravity_compiler_annotation_count(compiler)).compactMap { index in
            guard let annotation = gravity_compiler_annotation_at(compiler, index),
                  let name = gravity_annotation_name(annotation),
                  let identifier = gravity_annotation_target_identifier(annotation) else {
                return nil
            }
            let rawKind = gravity_annotation_target_kind(annotation)
            let kind = Target.Kind(rawValue: rawKind) ?? .unknown
            let parentIdentifier = gravity_annotation_target_parent_identifier(annotation).map(String.init(cString:))
            let arguments = (0..<gravity_annotation_argument_count(annotation)).compactMap { argumentIndex -> Argument? in
                guard let value = gravity_annotation_argument_value(annotation, argumentIndex) else {
                    return nil
                }
                return Argument(
                    label: gravity_annotation_argument_label(annotation, argumentIndex).map(String.init(cString:)),
                    value: makeValue(value)
                )
            }
            return GravityAnnotation(
                name: String(cString: name),
                target: Target(
                    kind: kind,
                    identifier: String(cString: identifier),
                    parentIdentifier: parentIdentifier
                ),
                arguments: arguments,
                source: SourceLocation(
                    fileID: gravity_annotation_fileid(annotation),
                    line: gravity_annotation_line(annotation),
                    column: gravity_annotation_column(annotation)
                )
            )
        }
    }

    private static func makeValue(_ value: UnsafePointer<gravity_annotation_value_t>) -> Value {
        switch gravity_annotation_value_kind_get(value) {
        case 0:
            return .identifier(gravity_annotation_value_string(value).map(String.init(cString:)) ?? "")
        case 1:
            return .string(gravity_annotation_value_string(value).map(String.init(cString:)) ?? "")
        case 2:
            return .integer(gravity_annotation_value_int(value))
        case 3:
            return .double(gravity_annotation_value_float(value))
        case 4:
            return .boolean(gravity_annotation_value_bool(value))
        case 5:
            return .null
        case 6:
            return .list(
                (0..<gravity_annotation_value_count(value)).compactMap { index in
                    gravity_annotation_value_at(value, index).map(makeValue)
                }
            )
        default:
            return .null
        }
    }
}
