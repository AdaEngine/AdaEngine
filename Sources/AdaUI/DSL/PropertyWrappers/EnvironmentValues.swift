//
//  Environment.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import AdaUtils
import Observation

/// A property wrapper that reads a value from a view's environment.
@MainActor
@propertyWrapper
public struct Environment<Value>: PropertyStoragable, UpdatableProperty {

    let container: ViewContextStorage
    var storage: UpdatablePropertyStorage {
        return self.container
    }

    var readValue: (ViewContextStorage) -> Value

    public var wrappedValue: Value {
        return readValue(container)
    }

    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        // Record which environment keys this wrapper reads so the node can skip
        // invalidation when only unrelated keys change (Phase 4 subscription tracking).
        var capturedIDs = Set<ObjectIdentifier>()
        EnvironmentValues._recordKeyAccess = { capturedIDs.insert($0) }
        _ = EnvironmentValues()[keyPath: keyPath]
        EnvironmentValues._recordKeyAccess = nil

        let storage = ViewContextStorage()
        storage.subscribedKeyIDs = capturedIDs
        self.container = storage
        self.readValue = { $0.values[keyPath: keyPath] }
    }

    public func update() { }
}

extension Environment where Value: Observable & AnyObject {
    public init(_ observable: Value.Type) where Value: Observable & AnyObject {
        let storage = ViewContextStorage()
        self.container = storage
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

    /// Keys this storage subscribes to. Populated once at `@Environment` init time.
    /// Empty means "subscribe to everything" (Observable-based environments).
    var subscribedKeyIDs: Set<ObjectIdentifier> = []
}
