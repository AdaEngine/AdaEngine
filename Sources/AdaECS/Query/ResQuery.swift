//
//  ResQuery.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.05.2025.
//

/// A property wrapper that allows you to query a resource in a system.
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
