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
    public typealias Iterator = FilterQueryIterator<Builder, F>

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
        FilterQueryIterator(state: self.state)
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
    private(set) weak var world: World?

    @usableFromInline
    let predicate: QueryPredicate

    @usableFromInline
    let filter: QueryFilter

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
public struct FilterQueryIterator<
    B: QueryBuilder,
    F: Filter
>: IteratorProtocol {
    
    public typealias Element = B.Components

    struct Cursor {
        var currentArchetypeIndex = 0
        var currentChunkIndex = 0
        var currentRow = 0
    }

    let count: Int
    let state: QueryState
    var cursor: Cursor

    /// - Parameter pointer: Pointer to archetypes array.
    /// - Parameter count: Count archetypes in array.
    init(state: QueryState) {
        self.count = state.archetypes.count
        self.state = state
        self.cursor = Cursor()
    }

    @inline(__always)
    public mutating func next() -> Element? {
        // swiftlint:disable:next empty_count
        guard self.count > 0 else {
            return nil
        }

        while true {
            guard self.cursor.currentArchetypeIndex < self.count else {
                return nil
            }
            let archetype = self.state.archetypes[self.cursor.currentArchetypeIndex]
            if self.cursor.currentRow >= archetype.entities.count {
                self.cursor.currentArchetypeIndex += 1
                self.cursor.currentRow = 0
                continue
            }

            guard let entity = archetype.entities[self.cursor.currentRow] else {
                self.cursor.currentRow += 1
                continue
            }

            if self.cursor.currentChunkIndex >= archetype.chunks.chunks.count {
                self.cursor.currentArchetypeIndex += 1
                self.cursor.currentChunkIndex = 0
                self.cursor.currentRow = 0
                continue
            }

            let chunk = archetype.chunks.chunks[self.cursor.currentChunkIndex]
            if !F.condition(for: archetype) {
                self.cursor.currentRow += 1
                continue
            }

            return B.getQueryTarget(for: entity, in: chunk, archetype: archetype)
        }
    }
}
