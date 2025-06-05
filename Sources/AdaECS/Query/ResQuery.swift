//
//  ResQuery.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.05.2025.
//

/// A property wrapper that allows you to query a resource from a world.
@dynamicMemberLookup
@propertyWrapper
public final class ResQuery<T: Resource>: @unchecked Sendable {

    /// The value of the query.
    private var _value: T?

    /// The wrapped value of the query.
    public var wrappedValue: T? {
        return _value
    }

    /// Initialize a new resource query.
    public init() {
        self._value = nil
    }

    /// Initialize a new resource query.
    /// - Parameter world: The world that will be used to initialize the query.
    public init(from world: World) {
        self._value = world.getResource(T.self)
    }

    /// Get the value of the query.
    /// - Returns: The value of the query.
    public func callAsFunction() -> T? {
        _value
    }

    public subscript<U>(dynamicMember dynamicMember: WritableKeyPath<T, U>) -> U? {
        self.wrappedValue?[keyPath: dynamicMember]
    }
}

extension ResQuery: SystemQuery {
    public func update(from world: consuming World) {
        let resource = world.getResource(T.self)
        if resource == nil {
            return
        }

        self._value = resource!
    }
}

/// A property wrapper that allows you to query a mutable resource from a world.
@dynamicMemberLookup
@propertyWrapper
public final class ResMutQuery<T: Resource>: @unchecked Sendable {

    /// The value of the query.
    private var _value: Ref<T?>

    /// The wrapped value of the query.
    public var wrappedValue: T? {
        get { self._value.wrappedValue }
        set { self._value.wrappedValue = newValue }
    }

    /// Initialize a new resource query.
    public init() {
        self._value = Ref(get: { nil }, set: { _ in })
    }

    /// Initialize a new resource query.
    /// - Parameter world: The world that will be used to initialize the query.
    public init(from world: World) {
        self._value = Ref { [weak world] in
            world?.getResource(T.self)
        } set: { [weak world] newValue in
            if let newValue = newValue {
                world?.insertResource(newValue)
            } else {
                world?.removeResource(T.self)
            }
        }
    }

    /// Get the value of the query.
    /// - Returns: The value of the query.
    public func callAsFunction() -> Ref<T?> {
        _value
    }

    public subscript<U>(dynamicMember dynamicMember: WritableKeyPath<T, U>) -> U? {
        get {
            self.wrappedValue?[keyPath: dynamicMember]
        }
        set {
            guard let newValue else {
                return
            }
            self.wrappedValue?[keyPath: dynamicMember] = newValue
        }
    }
}

extension ResMutQuery: SystemQuery {
    public func update(from world: consuming World) {
        /// seems like we have actual state, because we captured world.
    }
}
