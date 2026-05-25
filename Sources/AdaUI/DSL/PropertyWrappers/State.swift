//
//  State.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

@MainActor
@propertyWrapper
public struct State<Value>: UpdatableProperty, PropertyStoragable {
    final class Handle {
        var storage: StateStorage<Value>?
        let initialValue: Value

        init(initialValue: Value) {
            self.initialValue = initialValue
        }
    }

    private let handle: Handle

    var storage: UpdatablePropertyStorage {
        return self.currentStorage()
    }

    public var wrappedValue: Value {
        _read {
            yield currentStorage().value
        }
        nonmutating _modify {
            let storage = currentStorage()
            yield &storage.value
            storage.update()
        }
    }

    public var projectedValue: Binding<Value> {
        Binding(storage: currentStorage())
    }

    public init(wrappedValue: Value) {
        self.handle = Handle(initialValue: wrappedValue)
    }

    public init(initialValue: Value) {
        self.handle = Handle(initialValue: initialValue)
    }

    public func update() { }

    private func currentStorage() -> StateStorage<Value> {
        if let storage = handle.storage {
            return storage
        }

        let storage = StateStorage(value: handle.initialValue)
        handle.storage = storage
        return storage
    }
}

final class StateStorage<Value>: UpdatablePropertyStorage, AnyStateStorage {
    var value: Value

    init(value: Value) {
        self.value = value
    }
}

extension State: ViewStateBindable {
    var stateValueType: ObjectIdentifier {
        ObjectIdentifier(Value.self)
    }

    func bind(to container: ViewStateContainer, key: ViewStatePropertyKey) {
        let storage = container.storage(
            for: key,
            initialValue: self.handle.storage ?? StateStorage(value: handle.initialValue)
        )
        self.handle.storage = storage
    }
}
