//
//  ViewEnvironment.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

public protocol ViewEnvironmentKey {
    associatedtype Value
    
    static var defaultValue: Value { get }
}

@propertyWrapper
public struct ViewEnvironment<Value>: PropertyStoragable, UpdatableProperty {

    let keyPath: KeyPath<ViewEnvironmentValues, Value>
    let container = ViewContextStorage()
    var storage: UpdatablePropertyStorage {
        return self.container
    }

    public var wrappedValue: Value {
        container.values[keyPath: keyPath]
    }
    
    public init(_ keyPath: KeyPath<ViewEnvironmentValues, Value>) {
        self.keyPath = keyPath
    }

    public func update() {
        self.storage.update()
    }
}

final class ViewContextStorage: UpdatablePropertyStorage {
    var values: ViewEnvironmentValues = ViewEnvironmentValues()
}

public struct ViewEnvironmentValues {

    var values: [ObjectIdentifier: Any] = [:]
    
    public subscript<K: ViewEnvironmentKey>(_ type: K.Type) -> K.Value {
        get {
            (self.values[ObjectIdentifier(type)] as? K.Value) ?? K.defaultValue
        }
        
        set {
            self.values[ObjectIdentifier(type)] = newValue
        }
    }
}


