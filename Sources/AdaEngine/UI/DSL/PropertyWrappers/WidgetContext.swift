//
//  WidgetContext.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

public protocol WidgetContextKey {
    associatedtype Value
    
    static var defaultValue: Value { get }
}

class WidgetContextStorage {
    var values: WidgetContextValues = WidgetContextValues()
}

@propertyWrapper
public struct WidgetContext<Value> {
    
    let keyPath: KeyPath<WidgetContextValues, Value>
    let container = WidgetContextStorage()
    
    public var wrappedValue: Value {
        container.values[keyPath: keyPath]
    }
    
    public init(_ keyPath: KeyPath<WidgetContextValues, Value>) {
        self.keyPath = keyPath
    }
}

public struct WidgetContextValues {
    
    var values: [ObjectIdentifier: Any] = [:]
    
    public subscript<K: WidgetContextKey>(_ type: K.Type) -> K.Value {
        get {
            (self.values[ObjectIdentifier(type)] as? K.Value) ?? K.defaultValue
        }
        
        set {
            self.values[ObjectIdentifier(type)] = newValue
        }
    }
}

struct FontWidgetContextKey: WidgetContextKey {
    static var defaultValue: Font = Font(
        fontResource: .system(),
        pointSize: 17
    )
}

public extension WidgetContextValues {
    var font: Font {
        get {
            self[FontWidgetContextKey.self]
        }
        
        set {
            self[FontWidgetContextKey.self] = newValue
        }
    }
}
