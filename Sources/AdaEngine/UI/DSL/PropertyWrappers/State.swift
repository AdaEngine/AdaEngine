//
//  State.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

@MainActor
@propertyWrapper
public struct State<Value>: UpdatableProperty, PropertyStoragable {
    
    var storage: UpdatablePropertyStorage {
        self._storage
    }
    
    let _storage: StateStorage<Value>

    public var wrappedValue: Value {
        get {
            return _storage.value
        }
        nonmutating set {
            _storage.value = newValue
            self.update()
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
    
    public func update() {
        self._storage.update()
    }
    
}

final class StateStorage<Value>: UpdatablePropertyStorage {
    var value: Value

    init(value: Value) {
        self.value = value
    }
}
