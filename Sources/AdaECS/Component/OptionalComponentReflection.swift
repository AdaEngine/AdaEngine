import AdaUtils
import Math

/// A value that can be exchanged through component reflection, including inside Optional.
/// Returning nil from decoding means invalid input; a decoded Optional.none is a successful value.
public protocol ReflectedFieldConvertible {
    static var reflectedFieldKind: ReflectedFieldKind { get }
    static func decodeReflectedField(_ value: ReflectedFieldValue) -> Self?
    var reflectedFieldValue: ReflectedFieldValue { get }
}

extension ComponentReflection {
    public static func kind<Value: ReflectedFieldConvertible>(for _: Value.Type) -> ReflectedFieldKind { Value.reflectedFieldKind }
    public static func isWritable<Value: ReflectedFieldConvertible>(_: Value.Type) -> Bool { true }
    public static func accepts<Value: ReflectedFieldConvertible>(_ value: ReflectedFieldValue, for _: Value.Type) -> Bool {
        Value.decodeReflectedField(value) != nil
    }
    public static func value<Value: ReflectedFieldConvertible>(_ value: ReflectedFieldValue, as _: Value.Type) -> Value? {
        Value.decodeReflectedField(value)
    }
    public static func read<Value: ReflectedFieldConvertible>(_ value: Value) -> ReflectedFieldValue { value.reflectedFieldValue }
    public static func write<Value: ReflectedFieldConvertible>(_ field: ReflectedFieldValue, to value: inout Value) -> Bool {
        guard let decoded = Value.decodeReflectedField(field) else { return false }
        value = decoded
        return true
    }
}

extension Optional: ReflectedFieldConvertible where Wrapped: ReflectedFieldConvertible {
    public static var reflectedFieldKind: ReflectedFieldKind { .optional(Wrapped.reflectedFieldKind) }
    public static func decodeReflectedField(_ value: ReflectedFieldValue) -> Self? {
        if case .null = value { return .some(.none) }
        return Wrapped.decodeReflectedField(value).map(Self.some)
    }
    public var reflectedFieldValue: ReflectedFieldValue { map(\.reflectedFieldValue) ?? .null }
}

extension ReflectedEnum {
    public static var reflectedFieldKind: ReflectedFieldKind { .enumeration(reflectedNames) }
    public static func decodeReflectedField(_ value: ReflectedFieldValue) -> Self? {
        guard case let .string(name) = value else { return nil }
        return reflectedCase(named: name)
    }
    public var reflectedFieldValue: ReflectedFieldValue { .string(reflectedName) }
}

extension Bool: ReflectedFieldConvertible {
    public static var reflectedFieldKind: ReflectedFieldKind { .bool }
    public static func decodeReflectedField(_ value: ReflectedFieldValue) -> Self? { ComponentReflection.value(value, as: Self.self) }
    public var reflectedFieldValue: ReflectedFieldValue { ComponentReflection.read(self) }
}

extension Int: ReflectedFieldConvertible {
    public static var reflectedFieldKind: ReflectedFieldKind { .int }
    public static func decodeReflectedField(_ value: ReflectedFieldValue) -> Self? { ComponentReflection.value(value, as: Self.self) }
    public var reflectedFieldValue: ReflectedFieldValue { ComponentReflection.read(self) }
}

extension Float: ReflectedFieldConvertible {
    public static var reflectedFieldKind: ReflectedFieldKind { .float }
    public static func decodeReflectedField(_ value: ReflectedFieldValue) -> Self? { ComponentReflection.value(value, as: Self.self) }
    public var reflectedFieldValue: ReflectedFieldValue { ComponentReflection.read(self) }
}

extension Double: ReflectedFieldConvertible {
    public static var reflectedFieldKind: ReflectedFieldKind { .float }
    public static func decodeReflectedField(_ value: ReflectedFieldValue) -> Self? { ComponentReflection.value(value, as: Self.self) }
    public var reflectedFieldValue: ReflectedFieldValue { ComponentReflection.read(self) }
}

extension String: ReflectedFieldConvertible {
    public static var reflectedFieldKind: ReflectedFieldKind { .string }
    public static func decodeReflectedField(_ value: ReflectedFieldValue) -> Self? { ComponentReflection.value(value, as: Self.self) }
    public var reflectedFieldValue: ReflectedFieldValue { ComponentReflection.read(self) }
}

extension Vector2: ReflectedFieldConvertible {
    public static var reflectedFieldKind: ReflectedFieldKind { .vector2 }
    public static func decodeReflectedField(_ value: ReflectedFieldValue) -> Self? { ComponentReflection.value(value, as: Self.self) }
    public var reflectedFieldValue: ReflectedFieldValue { ComponentReflection.read(self) }
}

extension Vector3: ReflectedFieldConvertible {
    public static var reflectedFieldKind: ReflectedFieldKind { .vector3 }
    public static func decodeReflectedField(_ value: ReflectedFieldValue) -> Self? { ComponentReflection.value(value, as: Self.self) }
    public var reflectedFieldValue: ReflectedFieldValue { ComponentReflection.read(self) }
}

extension Vector4: ReflectedFieldConvertible {
    public static var reflectedFieldKind: ReflectedFieldKind { .vector4 }
    public static func decodeReflectedField(_ value: ReflectedFieldValue) -> Self? { ComponentReflection.value(value, as: Self.self) }
    public var reflectedFieldValue: ReflectedFieldValue { ComponentReflection.read(self) }
}

extension Quat: ReflectedFieldConvertible {
    public static var reflectedFieldKind: ReflectedFieldKind { .vector4 }
    public static func decodeReflectedField(_ value: ReflectedFieldValue) -> Self? { ComponentReflection.value(value, as: Self.self) }
    public var reflectedFieldValue: ReflectedFieldValue { ComponentReflection.read(self) }
}

extension Color: ReflectedFieldConvertible {
    public static var reflectedFieldKind: ReflectedFieldKind { .color }
    public static func decodeReflectedField(_ value: ReflectedFieldValue) -> Self? { ComponentReflection.value(value, as: Self.self) }
    public var reflectedFieldValue: ReflectedFieldValue { ComponentReflection.read(self) }
}
