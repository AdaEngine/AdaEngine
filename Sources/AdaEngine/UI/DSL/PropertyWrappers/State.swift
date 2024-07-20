//
//  State.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

import Observation

@MainActor
@propertyWrapper
public struct State<Value>: UpdatableProperty, PropertyStoragable {
    
    nonisolated var storage: UpdatablePropertyStorage {
        self._storage
    }
    
    let _storage: StateStorage<Value>

    public var wrappedValue: Value {
        get {
            return _storage.value
        }
        nonmutating set {
            _storage.value = newValue
            _storage.update()
        }
    }

    public var projectedValue: Binding<Value> {
        Binding<Value> {
            self.wrappedValue
        } set: { newValue in
            self.wrappedValue = newValue
        }
    }

    public init(wrappedValue: Value) {
        self._storage = StateStorage(value: wrappedValue)
    }

    public init(initialValue: Value) {
        self._storage = StateStorage(value: initialValue)
    }

    public func update() { }
}

final class StateStorage<Value>: UpdatablePropertyStorage {
    var value: Value

    init(value: Value) {
        self.value = value
    }
}
