//
//  SystemQuery.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/21/25.
//

import AdaUtils
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

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

    public typealias Builder = QueryBuilderTargets<repeat each T>

    public var wrappedValue: Self {
        return self
    }

    let state: QueryState

    /// Create a new query for specific predicate.
    /// - Parameter predicate: Describe what entity should contains to satisfy query.
    public init() {
        self.state = QueryState(
            predicate: .init(
                evaluate: { Builder.predicate(in: $0) }
            ),
            filter: .all
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
        return self.state.archetypeIndecies.isEmpty
    }

    public func makeIterator() -> Iterator {
        Iterator(state: self.state)
    }

    /// Returns a parallel query processor for concurrent iteration over chunks.
    ///
    /// Use this method to process query results in parallel across multiple threads.
    /// The batch size determines how many chunks are grouped together in a single task,
    /// which helps balance the workload across available CPU cores.
    ///
    /// ```swift
    /// // Process entities in parallel with custom batch size
    /// await query.parallel(batchSize: 8).forEach { position, velocity in
    ///     position.x += velocity.x * deltaTime
    ///     position.y += velocity.y * deltaTime
    /// }
    ///
    /// // Map entities in parallel and collect results
    /// let distances = await query.parallel().map { position in
    ///     return sqrt(position.x * position.x + position.y * position.y)
    /// }
    /// ```
    ///
    /// - Parameter batchSize: Number of chunks to process per task. Default is 4.
    ///   Larger values reduce task overhead but may cause load imbalance.
    ///   Smaller values provide better load distribution but increase task overhead.
    /// - Returns: A ``ParallelQueryResult`` instance for concurrent processing
    public func parallel(batchSize: Int = 4) -> ParallelQueryResult<Builder, F> {
        return ParallelQueryResult(state: self.state, batchSize: batchSize)
    }
}

extension FilterQuery: SystemParameter {
    public func update(from world: World) {
        self.state.updateArchetypes(in: world)
    }
}

@usableFromInline
final class QueryState: @unchecked Sendable {
    @usableFromInline
    private(set) var archetypeIndecies: [Int] = []

    @usableFromInline
    private(set) var entities: Entities = Entities()

    @usableFromInline
    private(set) weak var world: World!

    @usableFromInline
    private(set) var lastTick: Tick = Tick(value: 0)

    @usableFromInline
    let predicate: QueryPredicate

    @usableFromInline
    let filter: QueryFilter

    internal init(predicate: QueryPredicate, filter: QueryFilter) {
        self.predicate = predicate
        self.filter = filter
    }

    func updateArchetypes(in world: World) {
        self.entities = world.entities
        self.archetypeIndecies = world.archetypes.archetypes.enumerated().compactMap {
            self.predicate.evaluate($0.element) ? $0.offset : nil
        }
        self.lastTick = world.lastTick
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

    let archetypes: Archetypes
    let count: Int
    let state: QueryState
    var cursor: Cursor

    /// - Parameter pointer: Pointer to archetypes array.
    /// - Parameter count: Count archetypes in array.
    init(state: QueryState) {
        self.count = state.archetypeIndecies.count
        self.state = state
        self.cursor = Cursor()
        self.archetypes = state.world.archetypes
    }

    @inline(__always)
    public mutating func next() -> Element? {
        // swiftlint:disable:next empty_count
        guard count > 0 else {
            return nil
        }

        if archetypes.archetypes.isEmpty {
            return nil
        }

        while true {
            guard cursor.currentArchetypeIndex < self.count else {
                return nil
            }
            let archetypeIndex = state.archetypeIndecies[cursor.currentArchetypeIndex]

            if archetypeIndex > self.archetypes.archetypes.count {
                cursor.currentArchetypeIndex += 1
                continue
            }

            let archetype = self.archetypes.archetypes[archetypeIndex]
            if cursor.currentChunkIndex >= archetype.chunks.chunks.count {
                cursor.currentArchetypeIndex += 1
                cursor.currentChunkIndex = 0
                cursor.currentRow = 0
                continue
            }
            
            if cursor.currentRow > archetype.chunks.chunks[cursor.currentChunkIndex].entities.count - 1 {
                cursor.currentChunkIndex += 1
                cursor.currentRow = 0
                continue
            }

            let currentChunk = archetype.chunks.chunks[cursor.currentChunkIndex]
            let entityId = currentChunk.entities[cursor.currentRow]

            guard let location = state.entities.entities[entityId] else {
                cursor.currentRow += 1
                continue
            }

            let entity = archetype.entities[location.archetypeRow]

            guard F.condition(
                for: archetype,
                in: currentChunk,
                entity: entity,
                lastTick: state.lastTick
            ) else {
                cursor.currentRow += 1
                continue
            }

            cursor.currentRow += 1
            return B.getQueryTarget(
                for: entity,
                in: currentChunk,
                archetype: archetype,
                world: state.world
            )
        }
    }
}
