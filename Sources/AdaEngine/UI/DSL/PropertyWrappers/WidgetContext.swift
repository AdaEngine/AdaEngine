//
//  WidgetEnvironment.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

public protocol WidgetEnvironmentKey {
    associatedtype Value
    
    static var defaultValue: Value { get }
}

final class WidgetContextStorage {
    var values: WidgetEnvironmentValues = WidgetEnvironmentValues()
}

@propertyWrapper
public struct WidgetEnvironment<Value> {

    let keyPath: KeyPath<WidgetEnvironmentValues, Value>
    let container = WidgetContextStorage()
    
    public var wrappedValue: Value {
        container.values[keyPath: keyPath]
    }
    
    public init(_ keyPath: KeyPath<WidgetEnvironmentValues, Value>) {
        self.keyPath = keyPath
    }
}

public struct WidgetEnvironmentValues {

    var values: [ObjectIdentifier: Any] = [:]
    
    public subscript<K: WidgetEnvironmentKey>(_ type: K.Type) -> K.Value {
        get {
            (self.values[ObjectIdentifier(type)] as? K.Value) ?? K.defaultValue
        }
        
        set {
            self.values[ObjectIdentifier(type)] = newValue
        }
    }
}

struct FontWidgetEnvironmentKey: WidgetEnvironmentKey {
    static var defaultValue: Font = Font(
        fontResource: .system(),
        pointSize: 17
    )
}

public extension WidgetEnvironmentValues {
    var font: Font {
        get {
            self[FontWidgetEnvironmentKey.self]
        }
        set {
            self[FontWidgetEnvironmentKey.self] = newValue
        }
    }
}
