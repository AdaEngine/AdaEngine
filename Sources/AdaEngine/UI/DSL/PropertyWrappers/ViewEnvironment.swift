//
//  Environment.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

@propertyWrapper
public struct Environment<Value>: PropertyStoragable, UpdatableProperty {

    let container = ViewContextStorage()
    var storage: UpdatablePropertyStorage {
        return self.container
    }

    var readValue: (ViewContextStorage) -> Value

    public var wrappedValue: Value {
        return readValue(container)
    }
    
    public init(_ keyPath: KeyPath<ViewEnvironmentValues, Value>) {
        self.readValue = { $0.values[keyPath: keyPath] }
    }

    public func update() {
        self.storage.update()
    }
}

#if canImport(Observation)
import Observation

extension Environment where Value: Observable & AnyObject {
    public init(_ observable: Value.Type) where Value: Observable & AnyObject {
        self.readValue = { container in
            let value = container.values.observableStorage.getValue(observable)

            return withObservationTracking {
                value
            } onChange: {
                Task { @MainActor in
                    container.update()
                }
            }
        }
    }
}
#endif

final class ViewContextStorage: UpdatablePropertyStorage {
    var values: ViewEnvironmentValues = ViewEnvironmentValues()
}

public protocol ViewEnvironmentKey {
    associatedtype Value

    static var defaultValue: Value { get }
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
