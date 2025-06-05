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
    let filter: QueryFilter

    /// Create a new query for specific predicate.
    /// - Parameter predicate: Describe what entity should contains to satisfy query.
    /// - Parameter filter: Describe filter of this query. By default is ``Filter/all``
    public init(filter: QueryFilter = .all) {
        self.filter = filter
        self.state = QueryState(
            predicate: .init(
                evaluate: { Builder.predicate(in: $0) }
            ),
            filter: filter
        )
    }

    public init(from world: World) {
        self.init(filter: .all)
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
        self.archetypes = world.archetypes.filter { self.predicate.evaluate($0) }
        self.world = world
    }
}
