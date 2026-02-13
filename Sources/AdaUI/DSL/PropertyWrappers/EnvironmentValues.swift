//
//  Environment.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import AdaUtils
import Observation

/// A property wrapper that reads a value from a view’s environment.
@MainActor
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
    
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        self.readValue = {
            $0.values[keyPath: keyPath]
        }
    }

    public func update() { }
}

extension Environment where Value: Observable & AnyObject {
    public init(_ observable: Value.Type) where Value: Observable & AnyObject {
        self.readValue = { container in
            let value = container.values.observableStorage.getValue(observable)

            return withObservationTracking {
                value
            } onChange: {
                MainActor.assumeIsolated {
                    container.update()
                }
            }
        }
    }
}

final class ViewContextStorage: UpdatablePropertyStorage {
    var values: EnvironmentValues = EnvironmentValues()
}
