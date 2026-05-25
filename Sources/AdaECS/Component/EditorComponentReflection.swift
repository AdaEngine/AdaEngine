//
//  EditorComponentReflection.swift
//  AdaEngine
//

import AdaUtils
import Foundation
import Math

public enum EditorFieldKind: Equatable, Sendable {
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

public enum EditorFieldValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([EditorFieldValue])
    case object([String: EditorFieldValue])
}

public struct EditorComponentFieldDescriptor: @unchecked Sendable {
    public var key: String
    public var label: String
    public var kind: EditorFieldKind
    public var isEditable: Bool
    public var read: @Sendable (any Component) -> EditorFieldValue?
    public var write: @Sendable (any Component, EditorFieldValue) -> (any Component)?

    public init(
        key: String,
        label: String,
        kind: EditorFieldKind,
        isEditable: Bool,
        read: @escaping @Sendable (any Component) -> EditorFieldValue?,
        write: @escaping @Sendable (any Component, EditorFieldValue) -> (any Component)?
    ) {
        self.key = key
        self.label = label
        self.kind = kind
        self.isEditable = isEditable
        self.read = read
        self.write = write
    }
}

public struct EditorComponentDescriptor: @unchecked Sendable {
    public var typeName: String
    public var displayName: String
    public var requiredComponentTypeNames: [String]
    public var fields: [EditorComponentFieldDescriptor]

    public init(
        typeName: String,
        displayName: String,
        requiredComponentTypeNames: [String],
        fields: [EditorComponentFieldDescriptor]
    ) {
        self.typeName = typeName
        self.displayName = displayName
        self.requiredComponentTypeNames = requiredComponentTypeNames
        self.fields = fields
    }

    public init<T: Component>(
        type: T.Type,
        displayName: String = String(describing: T.self),
        requiredComponentTypeNames: [String],
        fields: [EditorComponentFieldDescriptor]
    ) {
        self.init(
            typeName: String(reflecting: T.self),
            displayName: displayName,
            requiredComponentTypeNames: requiredComponentTypeNames,
            fields: fields
        )
    }

    public func readPayload(from component: any Component) -> [String: EditorFieldValue] {
        fields.reduce(into: [:]) { result, field in
            result[field.key] = field.read(component) ?? .null
        }
    }

    public func writing(_ value: EditorFieldValue, toField key: String, in component: any Component) -> (any Component)? {
        fields.first { $0.key == key }?.write(component, value)
    }

    @discardableResult
    public func write(_ value: EditorFieldValue, toField key: String, in world: World, entity: Entity.ID) -> Bool {
        guard let component = world.getComponent(named: typeName, from: entity),
              let updated = writing(value, toField: key, in: component) else {
            return false
        }
        insert(updated, in: world, entity: entity)
        return true
    }

    private func insert(_ component: any Component, in world: World, entity: Entity.ID) {
        func insertTyped<T: Component>(_ component: T) {
            world.insert(component, for: entity)
        }
        _openExistential(component, do: insertTyped)
    }
}

public protocol EditorEnumReflectable: CaseIterable, Sendable {
    var editorCaseName: String { get }
    static var editorCaseNames: [String] { get }
    static func editorCase(named name: String) -> Self?
}

public extension EditorEnumReflectable {
    var editorCaseName: String {
        String(describing: self)
    }

    static var editorCaseNames: [String] {
        allCases.map(\.editorCaseName)
    }

    static func editorCase(named name: String) -> Self? {
        allCases.first { $0.editorCaseName == name }
    }
}

public enum EditorComponentReflectionRegistry {
    nonisolated(unsafe) private static var descriptors: [String: EditorComponentDescriptor] = [:]

    public static func register(_ descriptor: EditorComponentDescriptor) {
        unsafe descriptors[descriptor.typeName] = descriptor
    }

    public static func descriptor(named typeName: String) -> EditorComponentDescriptor? {
        unsafe descriptors[typeName]
    }

    public static func allDescriptors() -> [EditorComponentDescriptor] {
        unsafe descriptors.values.sorted { $0.displayName < $1.displayName }
    }
}

public enum EditorComponentReflection {
    public static func kind<T>(for type: T.Type) -> EditorFieldKind {
        .readOnly
    }

    public static func kind(for type: Bool.Type) -> EditorFieldKind { .bool }
    public static func kind(for type: Int.Type) -> EditorFieldKind { .int }
    public static func kind(for type: Float.Type) -> EditorFieldKind { .float }
    public static func kind(for type: Double.Type) -> EditorFieldKind { .float }
    public static func kind(for type: String.Type) -> EditorFieldKind { .string }
    public static func kind(for type: Vector2.Type) -> EditorFieldKind { .vector2 }
    public static func kind(for type: Vector3.Type) -> EditorFieldKind { .vector3 }
    public static func kind(for type: Vector4.Type) -> EditorFieldKind { .vector4 }
    public static func kind(for type: Quat.Type) -> EditorFieldKind { .vector4 }
    public static func kind(for type: Color.Type) -> EditorFieldKind { .color }
    public static func kind<T: EditorEnumReflectable>(for type: T.Type) -> EditorFieldKind { .enumeration(T.editorCaseNames) }

    public static func isEditable<T>(_ type: T.Type) -> Bool {
        kind(for: T.self) != .readOnly
    }

    public static func read<T>(_ value: T) -> EditorFieldValue {
        .string(String(describing: value))
    }

    public static func read(_ value: Bool) -> EditorFieldValue { .bool(value) }
    public static func read(_ value: Int) -> EditorFieldValue { .int(value) }
    public static func read(_ value: Float) -> EditorFieldValue { .double(Double(value)) }
    public static func read(_ value: Double) -> EditorFieldValue { .double(value) }
    public static func read(_ value: String) -> EditorFieldValue { .string(value) }
    public static func read(_ value: Vector2) -> EditorFieldValue { .array([.double(Double(value.x)), .double(Double(value.y))]) }
    public static func read(_ value: Vector3) -> EditorFieldValue { .array([.double(Double(value.x)), .double(Double(value.y)), .double(Double(value.z))]) }
    public static func read(_ value: Vector4) -> EditorFieldValue { .array([.double(Double(value.x)), .double(Double(value.y)), .double(Double(value.z)), .double(Double(value.w))]) }
    public static func read(_ value: Quat) -> EditorFieldValue { .array([.double(Double(value.x)), .double(Double(value.y)), .double(Double(value.z)), .double(Double(value.w))]) }
    public static func read(_ value: Color) -> EditorFieldValue {
        .object([
            "red": .double(Double(value.red)),
            "green": .double(Double(value.green)),
            "blue": .double(Double(value.blue)),
            "alpha": .double(Double(value.alpha))
        ])
    }
    public static func read<T: EditorEnumReflectable>(_ value: T) -> EditorFieldValue { .string(value.editorCaseName) }

    public static func write<T>(_ fieldValue: EditorFieldValue, to value: inout T) -> Bool {
        false
    }

    public static func write(_ fieldValue: EditorFieldValue, to value: inout Bool) -> Bool {
        guard let bool = fieldValue.boolValue else { return false }
        value = bool
        return true
    }

    public static func write(_ fieldValue: EditorFieldValue, to value: inout Int) -> Bool {
        guard let int = fieldValue.intValue else { return false }
        value = int
        return true
    }

    public static func write(_ fieldValue: EditorFieldValue, to value: inout Float) -> Bool {
        guard let double = fieldValue.doubleValue else { return false }
        value = Float(double)
        return true
    }

    public static func write(_ fieldValue: EditorFieldValue, to value: inout Double) -> Bool {
        guard let double = fieldValue.doubleValue else { return false }
        value = double
        return true
    }

    public static func write(_ fieldValue: EditorFieldValue, to value: inout String) -> Bool {
        guard case .string(let string) = fieldValue else { return false }
        value = string
        return true
    }

    public static func write(_ fieldValue: EditorFieldValue, to value: inout Vector2) -> Bool {
        guard let components = fieldValue.numericArray(count: 2) else { return false }
        value = Vector2(Float(components[0]), Float(components[1]))
        return true
    }

    public static func write(_ fieldValue: EditorFieldValue, to value: inout Vector3) -> Bool {
        guard let components = fieldValue.numericArray(count: 3) else { return false }
        value = Vector3(Float(components[0]), Float(components[1]), Float(components[2]))
        return true
    }

    public static func write(_ fieldValue: EditorFieldValue, to value: inout Vector4) -> Bool {
        guard let components = fieldValue.numericArray(count: 4) else { return false }
        value = Vector4(Float(components[0]), Float(components[1]), Float(components[2]), Float(components[3]))
        return true
    }

    public static func write(_ fieldValue: EditorFieldValue, to value: inout Quat) -> Bool {
        guard let components = fieldValue.numericArray(count: 4) else { return false }
        value = Quat(x: Float(components[0]), y: Float(components[1]), z: Float(components[2]), w: Float(components[3]))
        return true
    }

    public static func write(_ fieldValue: EditorFieldValue, to value: inout Color) -> Bool {
        guard let components = fieldValue.colorComponents else { return false }
        value = Color(red: Float(components[0]), green: Float(components[1]), blue: Float(components[2]), alpha: Float(components[3]))
        return true
    }

    public static func write<T: EditorEnumReflectable>(_ fieldValue: EditorFieldValue, to value: inout T) -> Bool {
        guard case .string(let string) = fieldValue,
              let enumValue = T.editorCase(named: string) else {
            return false
        }
        value = enumValue
        return true
    }
}

public extension EditorFieldValue {
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

    var intValue: Int? {
        switch self {
        case .int(let value):
            value
        case .double(let value):
            Int(value)
        case .string(let value):
            Int(value)
        default:
            nil
        }
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let value):
            value
        case .string("true"), .string("1"):
            true
        case .string("false"), .string("0"):
            false
        default:
            nil
        }
    }

    var colorComponents: [Double]? {
        if let components = numericArray(count: 4) {
            return components
        }
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

    func numericArray(count: Int) -> [Double]? {
        guard case .array(let values) = self else {
            return nil
        }
        var numbers = values.map { $0.doubleValue ?? 0 }
        if numbers.count < count {
            numbers.append(contentsOf: Array(repeating: 0, count: count - numbers.count))
        }
        return Array(numbers.prefix(count))
    }
}
