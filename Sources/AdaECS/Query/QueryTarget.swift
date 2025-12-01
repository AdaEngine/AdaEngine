//
//  QueryTarget.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.05.2025.
//

import AdaUtils

/// A protocol that allows to use components and entities as query targets.
public protocol QueryTarget: Sendable, ~Copyable {

    associatedtype Fetch

    associatedtype State: Sendable

    @inlinable
    static func _initState(world: World) -> State

    @inlinable
    static func _initFetch(
        world: World,
        state: State,
        lastTick: Tick,
        currentTick: Tick
    ) -> Fetch

    @inlinable
    static func _setData(
        state: State,
        fetch: Fetch,
        chunk: Chunk,
        archetype: Archetype,
    ) -> Fetch

    /// Check that entity contains target.
    /// - Parameter entity: The entity to check.
    /// - Returns: True if the entity contains the target, otherwise false.
    @inlinable
    static func _queryTargetContains(in entity: Entity) -> Bool

    /// Create a new query target from an entity.
    /// - Parameter entity: The entity to create a query target from.
    /// - Returns: A new query target.
    @inlinable
    static func _queryFetch(
        for entity: Entity,
        state: State,
        fetch: Fetch,
        at row: Int
    ) -> Self?

    /// Check if an archetype contains the target.
    /// - Parameter archetype: The archetype to check.
    /// - Returns: True if the archetype contains the target, otherwise false.
    @inlinable
    static func _queryContains(in archetype: borrowing Archetype) -> Bool
}

extension Component {

    @inlinable
    public static func _initState(world: World) -> ComponentId {
        return Self.identifier
    }

    @inlinable
    public static func _initFetch(
        world: World,
        state: ComponentId,
        lastTick: Tick,
        currentTick: Tick
    ) -> ReadFetch<Self> {
        ReadFetch(data: nil)
    }

    public static func _queryFetch(
        for entity: Entity,
        state: ComponentId,
        fetch: ReadFetch<Self>,
        at row: Int
    ) -> Self? {
        unsafe fetch.data?[row]
    }

    public static func _setData(
        state: ComponentId,
        fetch: ReadFetch<Self>,
        chunk: Chunk,
        archetype: Archetype
    ) -> ReadFetch<Self> {
        guard let slice = chunk.getComponentSlice(for: Self.self) else {
            return fetch
        }
        return unsafe ReadFetch(data: slice)
    }

    @inlinable
    public static func _queryTargetContains(in entity: Entity) -> Bool {
        return entity.components.has(Self.self)
    }

    @inlinable
    public static func _queryContains(in archetype: borrowing Archetype) -> Bool {
        archetype.componentLayout.maskSet.contains(Self.identifier)
    }
}

@safe
public struct RefFetch<T> {
    var data: UnsafeMutableBufferPointer<T>?

    @usableFromInline
    init(data: UnsafeMutableBufferPointer<T>?) {
        unsafe self.data = data
    }
}

@safe
public struct ReadFetch<T> {
    var data: UnsafeBufferPointer<T>?

    @usableFromInline
    init(data: UnsafeBufferPointer<T>?) {
        unsafe self.data = data
    }
}

extension Ref: QueryTarget where T: Component {
    public static func _initFetch(
        world: World,
        state: ComponentId,
        lastTick: Tick,
        currentTick: Tick
    ) -> RefFetch<T> {
        RefFetch(data: nil)
    }

    public static func _initState(world: World) -> ComponentId {
        T.identifier
    }

    @inlinable
    public static func _queryTargetContains(in entity: Entity) -> Bool {
        T._queryTargetContains(in: entity)
    }

    public static func _setData(
        state: ComponentId,
        fetch: RefFetch<T>,
        chunk: Chunk,
        archetype: Archetype
    ) -> RefFetch<T> {
        guard let slice = chunk.getMutableComponentSlice(for: T.self) else {
            return fetch
        }
        return unsafe RefFetch(
            data: UnsafeMutableBufferPointer(
                start: slice,
                count: chunk.count
            )
        )
    }

    public static func _queryFetch(
        for entity: Entity,
        state: ComponentId,
        fetch: RefFetch<T>,
        at row: Int
    ) -> Ref<T>? {
//        unsafe Ref(
        //            pointer: chunk.getMutablePointer(T.self, for: entity.id)!,
        //            changeTick: .init(
        //                change: chunk.getMutableTick(T.self, for: entity.id)!.unsafeBox(),
        //                lastTick: world.lastTick,
        //                currentTick: world.lastTick
        //            )
        //        )
        return unsafe Ref(
            pointer: unsafe fetch.data?.baseAddress?.advanced(by: row),
            changeTick: ChangeDetectionTick(
                change: nil,
                lastTick: Tick.init(value: 0),
                currentTick: Tick.init(value: 0)
            )
        )
    }

    @inlinable
    public static func _queryContains(in archetype: borrowing Archetype) -> Bool {
        return archetype.componentLayout.maskSet.contains(T.identifier)
    }
}

extension Entity: QueryTarget {
    public static func _setData(
        state: Void,
        fetch: Void,
        chunk: Chunk,
        archetype: Archetype
    ) -> Void { }

    public static func _queryFetch(
        for entity: Entity,
        state: (),
        fetch: (),
        at row: Int
    ) -> Self? {
        entity as? Self
    }

    public static func _initState(world: World) -> Void { }

    public static func _initFetch(
        world: World,
        state: Void,
        lastTick: Tick,
        currentTick: Tick
    ) -> Void { }

    @inlinable
    public static func _queryTargetContains(in entity: Entity) -> Bool {
        return true
    }
    
    /// Always returns true because entity is always present in an archetype.
    @inlinable
    public static func _queryContains(in archetype: borrowing Archetype) -> Bool {
        return true
    }
}

extension Optional: QueryTarget where Wrapped: QueryTarget {
    public typealias State = Wrapped.State
    public typealias Fetch = Wrapped.Fetch

    @inlinable
    public static func _setData(
        state: Wrapped.State,
        fetch: Wrapped.Fetch,
        chunk: Chunk,
        archetype: Archetype
    ) -> Wrapped.Fetch {
        Wrapped._setData(state: state, fetch: fetch, chunk: chunk, archetype: archetype)
    }

    @inlinable
    public static func _queryFetch(
        for entity: Entity,
        state: Wrapped.State,
        fetch: Wrapped.Fetch,
        at row: Int
    ) -> Optional<Wrapped>? {
        .some(
            Wrapped._queryFetch(for: entity, state: state, fetch: fetch, at: row)
        )
    }

    @inlinable
    public static func _initState(world: World) -> State {
        Wrapped._initState(world: world)
    }

    @inlinable
    public static func _initFetch(world: World, state: State, lastTick: Tick, currentTick: Tick) -> Fetch {
        Wrapped._initFetch(world: world, state: state, lastTick: lastTick, currentTick: currentTick)
    }

    @inlinable
    public static func _queryTargetContains(in entity: Entity) -> Bool {
        Wrapped._queryTargetContains(in: entity)
    }

    @inlinable
    public static func _queryContains(in archetype: borrowing Archetype) -> Bool {
        return Wrapped._queryContains(in: archetype)
    }
}
