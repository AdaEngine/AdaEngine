//
//  Binding.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 28.06.2024.
//

@propertyWrapper
public struct Binding<T>: UpdatableProperty {

    public var wrappedValue: T {
        get {
            return getValue()
        }
        nonmutating set {
            setValue(newValue)
        }
    }

    let getValue: () -> T
    let setValue: (T) -> Void

    public init(get: @escaping () -> T, set: @escaping (T) -> Void) {
        self.getValue = get
        self.setValue = set
    }

    public func update() { }

    public static func constant<Value>(_ value: Value) -> Binding<Value> {
        Binding<Value>(
            get: { return value },
            set: { _ in }
        )
    }
}
