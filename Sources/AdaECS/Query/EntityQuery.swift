//
//  Query.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/24/22.
//

/// This object describe query to ECS world.
///
/// ```swift
/// @System
/// struct MovementSystem {
///     @EntityQuery(where: .has(Transform.self)) private var query
///
///     func update(context: inout UpdateContext) {
///         self.query.forEach {
///             var transform = entity.components[Transform.self]
///             // Do some movement
///         }
///     }
/// }
/// ```
///
/// Also, you can combine types in query using `&&` and `||` operators.
///
/// ```swift
/// @System
/// struct RendererSystem {
///     @EntityQuery(where: .has(SpriteComponent.self) && .has(Transform.self))
///     private var query
///
///     func update(context: inout UpdateContext) {
///         for entity in self.query {
///             // Get components from entity and do some render
///         }
///     }
/// }
/// ```
@propertyWrapper
@frozen public struct EntityQuery: Sendable {
    
    public typealias Result = QueryResult<QueryBuilderTargets<Entity>, NoFilter>

    public var wrappedValue: Result {
        return QueryResult(state: self.state)
    }
    
    let state: QueryState
    let predicate: QueryPredicate
    let filter: QueryFilter
    
    /// Create a new entity query for specific predicate.
    /// - Parameter predicate: Describe what entity should contains to satisfy query.
    /// - Parameter filter: Describe filter of this query. By default is ``Filter/all``
    public init(where predicate: QueryPredicate, filter: QueryFilter = .all) {
        self.predicate = predicate
        self.filter = filter
        self.state = QueryState(predicate: predicate, filter: filter)
    }

    public init(from world: World) {
        fatalError("Can't initialize EntityQuery from world")
    }

    public func callAsFunction() -> Result {
        .init(state: self.state)
    }
}

extension EntityQuery: SystemQuery {
    public func update(from world: consuming World) {
        self.state.updateArchetypes(in: world)
    }
}

/// This iterator iterate by each entity in passed archetype array
public struct EntityIterator: IteratorProtocol {
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
            guard let entity = currentArchetype.entities[self.currentEntityIndex], entity.isActive else {
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
