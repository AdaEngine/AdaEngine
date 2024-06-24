//
//  State.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

class StateStorage<Value>: UpdatablePropertyStorage {
    var value: Value
    
    init(value: Value) {
        self.value = value
    }
}

@propertyWrapper @MainActor
public struct State<Value>: UpdatableProperty, PropertyStoragable {
    
    var _storage: UpdatablePropertyStorage {
        self.storage
    }
    
    let storage: StateStorage<Value>
    
    public var wrappedValue: Value {
        get {
            return storage.value
        }
        
        set {
            storage.value = newValue
            self.update()
        }
    }
    
    public init(wrappedValue: Value) {
        self.storage = StateStorage(value: wrappedValue)
    }
    
    public init(initialValue: Value) {
        self.storage = StateStorage(value: initialValue)
    }
    
    public func update() {
        self.storage.update()
    }
    
}
