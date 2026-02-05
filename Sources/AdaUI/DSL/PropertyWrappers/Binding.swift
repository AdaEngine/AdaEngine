//
//  Binding.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 28.06.2024.
//

/// A property wrapper type that can read and write a value owned by a source of truth.
/// 
/// Use a binding to create a two-way connection between a property that stores data, and a view that displays and changes the data. 
/// A binding connects a property to a source of truth stored elsewhere, instead of storing data directly. 
/// For example, a button that toggles between play and pause can create a binding to a property of its parent view using the Binding property wrapper.
@propertyWrapper
public struct Binding<T>: UpdatableProperty {

    /// The underlying value referenced by the binding variable.
    public var wrappedValue: T {
        get {
            return getValue()
        }
        nonmutating set {
            setValue(newValue)
        }
    }

    private let getValue: () -> T
    private let setValue: (T) -> Void

    /// Initialize a new binding.
    ///
    /// - Parameter get: The getter function.
    /// - Parameter set: The setter function.
    @preconcurrency
    public init(get: @escaping @isolated(any) () -> T, set: @escaping @isolated(any) (T) -> Void) {
        self.getValue = get
        self.setValue = set
    }

    @preconcurrency
    init(storage: StateStorage<T>) {
        self.getValue = {
            unsafe storage.value
        }
        self.setValue = { newValue in
            unsafe storage.value = newValue
            Task { @MainActor in
                storage.update()
            }
        }
    }

    /// Update the binding.
    ///
    /// - Returns: The binding.
    public func update() { }

    /// Create a constant binding.
    ///
    /// - Parameter value: The value to bind.
    /// - Returns: A constant binding.
    public static func constant<Value>(_ value: Value) -> Binding<Value> {
        Binding<Value>(
            get: { return value },
            set: { _ in }
        )
    }

    /// Create a binding from a reference.
    ///
    /// - Parameter reference: The reference to bind.
    /// - Returns: A binding from a reference.
    subscript<Subject>(dynamicMember keyPath: WritableKeyPath<T, Subject>) -> Binding<Subject> {
        return Binding<Subject>(
            get: { self.wrappedValue[keyPath: keyPath] },
            set: { self.wrappedValue[keyPath: keyPath] = $0 }
        )
    }
}
