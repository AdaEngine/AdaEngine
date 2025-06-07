//
//  SystemQuery.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/21/25.
//

/// A query that can fetch query targets like components or entities.
///
/// Use queries to efficiently access and iterate over entities and their components that match specific criteria.
///
/// ```swift
/// // Query for entities with both Position and Velocity components
/// @Query<Entity, Ref<Position>, Ref<Velocity>>
/// var movingEntities
///
/// // Query for just Position components
/// @Query<Position>
/// var positions
///
/// // Query with multiple component references
/// @Query<Position, Rotation>
/// var transforms
/// ```
public typealias Query<each T: QueryTarget> = FilterQuery<repeat (each T), NoFilter>

/// A query that can fetch query targets like components or entities with filters.
///
/// Use queries to efficiently access and iterate over entities and their components that match specific criteria.
///
/// ```swift
/// // Query for entities with Position or Velocity components
/// @FilterQuery<Entity, Ref<Position>, Or<Ref<Velocity>>>
/// var movingEntities
///
/// // Query for just Position components
/// @FilterQuery<Position, NoFilter>
/// var positions
///
/// // Query without Rotation component
/// @FilterQuery<Position, Without<Rotation>>
/// var transforms
/// ```
@propertyWrapper
public struct FilterQuery<each T: QueryTarget, F: Filter>: Sequence, Sendable {
    /// The element type of the query result.
    public typealias Element = Builder.Components

    /// The iterator type of the query result.
    public typealias Iterator = QueryTargetIterator<Builder>

    public typealias Builder = QueryBuilderTargets<repeat each T, F>

    public var wrappedValue: Self {
        return self
    }

    let state: QueryState

    /// Create a new query for specific predicate.
    /// - Parameter predicate: Describe what entity should contains to satisfy query.
    /// - Parameter filter: Describe filter of this query. By default is ``Filter/all``
    public init(filter: QueryFilter = .all) {
        self.state = QueryState(
            predicate: .init(
                evaluate: { Builder.predicate(in: $0) }
            ),
            filter: filter
        )
    }

    public init(from world: World) {
        self.state = QueryState(
            predicate: .init(
                evaluate: { Builder.predicate(in: $0) }
            ),
            filter: .all
        )
        self.state.updateArchetypes(in: world)
    }
}

/// Contains array of entities matched for the given EntityQuery request.
extension FilterQuery  {

    /// Returns first element of collection.
    public var first: Element? {
        return self.first { _ in return true }
    }

    /// Calculate count of element in collection
    /// - Complexity: O(n)
    public var count: Int {
        return self.count { _ in return true }
    }

        /// A Boolean value indicating whether the collection is empty.
    public var isEmpty: Bool {
        return self.state.archetypes.isEmpty
    }

    public func makeIterator() -> Iterator {
        QueryTargetIterator(state: self.state)
    }
}

extension FilterQuery: SystemQuery {
    public func update(from world: consuming World) {
        self.state.updateArchetypes(in: world)
    }
}

@usableFromInline
final class QueryState: @unchecked Sendable {
    @usableFromInline
    private(set) var archetypes: [Archetype] = []

    @usableFromInline
    let predicate: QueryPredicate

    @usableFromInline
    let filter: QueryFilter

    private(set) weak var world: World?

    internal init(predicate: QueryPredicate, filter: QueryFilter) {
        self.predicate = predicate
        self.filter = filter
    }

    func updateArchetypes(in world: consuming World) {
        self.archetypes = world.archetypes.archetypes.filter {
            self.predicate.evaluate($0)
        }
        self.world = world
    }
}

/// This iterator iterate by each entity in passed archetype array
public struct FilterQueryIterator: IteratorProtocol {
    let count: Int
    let state: QueryState

    private var currentArchetypeIndex = 0
    private var currentEntityIndex = -1 // We should use -1 for first iterating.

    /// - Parameter pointer: Pointer to archetypes array.
    /// - Parameter count: Count archetypes in array.
    init(state: QueryState) {
        self.count = state.archetypes.count
        self.state = state
    }

    public mutating func next() -> Entity? {
        // swiftlint:disable:next empty_count
        guard self.count > 0 else {
            return nil
        }

        while true {
            guard self.currentArchetypeIndex < self.count else {
                return nil
            }

            let currentEntitiesCount = self.state.archetypes[self.currentArchetypeIndex].entities.count
            if self.currentEntityIndex < currentEntitiesCount - 1 {
                self.currentEntityIndex += 1
            } else {
                self.currentArchetypeIndex += 1
                self.currentEntityIndex = -1
                continue
            }

            let currentArchetype = self.state.archetypes[self.currentArchetypeIndex]
            guard let entity = currentArchetype.entities[self.currentEntityIndex] else {
                continue
            }

            guard let world = self.state.world else {
                return nil
            }

            if self.state.filter.contains(.all) {
                return entity
            } else if self.state.filter.contains(.added) && world.addedEntities.contains(entity.id) {
                return entity
            } else if self.state.filter.contains(.removed) && world.removedEntities.contains(entity.id) {
                return entity
            } else if self.state.filter.contains(.stored) {
                return entity
            }

            continue
        }
    }
}
