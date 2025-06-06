//
//  Ref.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.05.2025.
//

/// A reference to a component.
/// Used to mutate component values via ``Query``.
@dynamicMemberLookup
@propertyWrapper
public final class Ref<T>: @unchecked Sendable {

    /// The getter of the reference.
    public typealias Getter = () -> T

    /// The setter of the reference.
    public typealias Setter = (T) -> Void

    /// The wrapped value of the reference.
    public var wrappedValue: T {
        get {
            return getValue!()
        }
        set {
            setValue?(newValue)
        }
    }

    /// Initialize a new reference.
    public init() {
        self.getValue = nil
        self.setValue = nil
    }

    /// The getter of the reference.
    var getValue: Getter?

    /// The setter of the reference.
    let setValue: Setter?

    /// Create a new reference to a component.
    /// - Parameters:
    ///   - get: A closure that returns the component value.
    ///   - set: A closure that sets the component value.
    public init(get: @escaping Getter, set: @escaping Setter) {
        self.getValue = get
        self.setValue = set
    }

    public subscript<U>(dynamicMember dynamicMember: WritableKeyPath<T, U>) -> U {
        get {
            return self.wrappedValue[keyPath: dynamicMember]
        }
        set {
            self.wrappedValue[keyPath: dynamicMember] = newValue
        }
    }
}

extension Ref: SystemQuery where T == World {
    public convenience init(from world: World) {
        fatalError()
    }

    public func update(from world: World) {
        getValue = {
            world
        }
    }
}
