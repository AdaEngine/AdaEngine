//
//  ResourceQuery.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.05.2025.
//

/// A property wrapper that allows you to query a resource in a system.
@propertyWrapper
public final class ResourceQuery<T: Resource>: @unchecked Sendable {

    private var _value: T?
    public var wrappedValue: T? {
        return _value
    }

    public init() {
        self._value = nil
    }

    public init(from world: World) {
        self._value = world.getResource(T.self)
    }

    public func callAsFunction() -> T? {
        _value
    }
}

extension ResourceQuery: SystemQuery {
    public func update(from world: World) {
        let resource = world.getResource(T.self)
        if resource == nil {
            return
        }

        self._value = resource!
    }
}
