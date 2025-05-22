//
//  Ref.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.05.2025.
//

/// A reference to a component.
/// Used to mutate component values via ``Query``.
@dynamicMemberLookup
public struct Ref<T: Component>: @unchecked Sendable {
    public typealias Getter = () -> T
    public typealias Setter = (T) -> Void
    
    let getValue: Getter
    let setValue: Setter
    
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
            return getValue()[keyPath: dynamicMember]
        }
        nonmutating set {
            var value = getValue()
            value[keyPath: dynamicMember] = newValue
            setValue(value)
        }
    }
}
