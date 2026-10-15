/// Applies a declared type to the shared ``AdaScriptDefaultValue`` syntax and produces a schema default,
/// or the field-specific error the schema parser reports.
struct AdaScriptDefaultValueResolver {
    /// Script enums by name, with their case names.
    let enums: [String: [String]]
    let path: String

    private static let namedColors: [String: [Double]] = ["white": [1, 1, 1, 1], "black": [0, 0, 0, 1], "clear": [0, 0, 0, 0]]

    func resolve(_ value: AdaScriptDefaultValue, fieldName: String, declaredType: String?) throws -> AdaScriptSchemaField.Value {
        if let declaredType, let structured = try resolveStructured(value, fieldName: fieldName, type: declaredType) {
            return structured
        }
        return try resolveScalar(value, fieldName: fieldName)
    }

    private func error(_ message: String) -> AdaScriptSchemaError {
        .invalid(path: path, message: message)
    }

    // MARK: Structured types

    /// `nil` for a scalar or unknown type, which falls back to the literal-driven scalar resolution.
    private func resolveStructured(
        _ value: AdaScriptDefaultValue,
        fieldName: String,
        type: String
    ) throws -> AdaScriptSchemaField.Value? {
        switch type {
        case "Vector2", "Vector3", "Vector4":
            let count = Int(type.dropFirst("Vector".count)) ?? 0
            return .vector(try resolveVector(value, fieldName: fieldName, type: type, count: count))
        case "Color":
            return try resolveColor(value, fieldName: fieldName)
        case "Entity":
            switch value {
            case .name("null"), .member(base: "Entity", member: "none"):
                return .entity
            default:
                throw error("field '\(fieldName)' of type Entity must default to null")
            }
        case "Asset":
            switch value {
            case .name("null"):
                return .asset(path: nil)
            case let .string(path):
                return .asset(path: path)
            default:
                throw error("field '\(fieldName)' of type Asset must default to null or an asset path string")
            }
        default:
            guard let cases = enums[type] else {
                return nil
            }
            guard case let .member(base, selected) = value, base == type else {
                throw error("field '\(fieldName)' of enum \(type) must default to \(type).<case>")
            }
            guard cases.contains(selected) else {
                throw error("enum \(type) has no case '\(selected)' (cases: \(cases.joined(separator: ", ")))")
            }
            return .enumeration(type: type, cases: cases, selected: selected)
        }
    }

    private func resolveVector(_ value: AdaScriptDefaultValue, fieldName: String, type: String, count: Int) throws -> [Double] {
        switch value {
        case let .member(base, member) where base == type:
            guard member == "ZERO" else {
                throw error("unknown \(type) constant for '\(fieldName)'; only \(type).ZERO is supported")
            }
            return Array(repeating: 0, count: count)
        case let .name(name) where name == type:
            throw error("field '\(fieldName)' of type \(type) needs component values")
        case let .construction(callee, components, isClosed) where callee == nil || callee == type:
            return try resolveComponents(components, isClosed: isClosed, closing: callee == nil ? "]" : ")", fieldName: fieldName, type: type, expected: [count])
        default:
            throw error("field '\(fieldName)' of type \(type) needs a \(type)(...) or [...] default")
        }
    }

    private func resolveColor(_ value: AdaScriptDefaultValue, fieldName: String) throws -> AdaScriptSchemaField.Value {
        switch value {
        case let .member(base, constant) where base == "Color":
            guard let components = Self.namedColors[constant] else {
                throw error("unknown Color constant '\(constant)' for '\(fieldName)'; use white, black, clear or Color(r, g, b, a)")
            }
            return .color(components)
        case .name("Color"):
            throw error("field '\(fieldName)' of type Color needs component values")
        case let .construction(callee, components, isClosed) where callee == nil || callee == "Color":
            let values = try resolveComponents(
                components,
                isClosed: isClosed,
                closing: callee == nil ? "]" : ")",
                fieldName: fieldName,
                type: "Color",
                expected: [3, 4]
            )
            return .color(values.count == 3 ? values + [1] : values)
        default:
            throw error("field '\(fieldName)' of type Color needs a Color(...) or [...] default")
        }
    }

    private func resolveComponents(
        _ components: [String?],
        isClosed: Bool,
        closing: String,
        fieldName: String,
        type: String,
        expected: [Int]
    ) throws -> [Double] {
        var values: [Double] = []
        for component in components {
            guard let component, let number = Double(component), number.isFinite else {
                throw error("\(type) component of '\(fieldName)' must be a finite number")
            }
            values.append(number)
        }
        guard isClosed else {
            throw error("expected '\(closing)' in the default of '\(fieldName)'")
        }
        guard expected.contains(values.count) else {
            let list = expected.map(String.init).joined(separator: " or ")
            throw error("\(type) default of '\(fieldName)' needs \(list) components, found \(values.count)")
        }
        return values
    }

    // MARK: Scalars

    private func resolveScalar(_ value: AdaScriptDefaultValue, fieldName: String) throws -> AdaScriptSchemaField.Value {
        switch value {
        case .missing:
            throw error("missing default for '\(fieldName)'")
        case let .string(text):
            return .string(text)
        case let .bool(flag):
            return .bool(flag)
        case let .number(text):
            if text.contains(".") || text.lowercased().contains("e") {
                guard let number = Double(text), number.isFinite else {
                    throw error("invalid floating-point default for '\(fieldName)'")
                }
                return .double(number)
            }
            guard let number = Int64(text) else {
                throw error("invalid integer default for '\(fieldName)'")
            }
            return .int(number)
        case .construction, .member, .name, .unsupported:
            throw error("unsupported default for '\(fieldName)'")
        }
    }
}
