//
//  Query.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/24/22.
//

// TODO: Should EntityQuery hold state?

/// This object describe query to ECS world.
///
/// ```swift
/// struct MovementSystem: System {
///     static let query = EntityQuery(where: .has(Transform.self))
///
///     func update(context: UpdateContext) {
///         context.world.performQuery(Self.query).forEach {
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
/// struct RendererSystem: System {
///     static let query = EntityQuery(where: .has(SpriteComponent.self) && .has(Transform.self))
///
///     func update(context: UpdateContext) {
///         var entities = context.world.performQuery(Self.query)
///
///         for entity in entities {
///             // Get components from entity and do some render
///         }
///     }
/// }
/// ```
@frozen public struct EntityQuery: Sendable {

    /// Filter for entity query.
    public struct Filter: OptionSet, Sendable {
        public typealias RawValue = UInt8
        
        public var rawValue: UInt8
        
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
        
        /// Returns entities which added to world.
        public static let added = Filter(rawValue: 1 << 0)
        
        /// Returns entities which stored in world.
        public static let stored = Filter(rawValue: 1 << 1)

        /// Returns entities which wait removing from world.
        public static let removed = Filter(rawValue: 1 << 2)
        
        /// Filter that include all values
        public static let all: Filter = [.added, .stored, .removed]
    }
    
    let state: State
    let predicate: QueryPredicate
    let filter: Filter
    
    /// Create a new entity query for specific predicate.
    /// - Parameter predicate: Describe what entity should contains to satisfy query.
    /// - Parameter filter: Describe filter of this query. By default is ``Filter/all``
    public init(where predicate: QueryPredicate, filter: Filter = .all) {
        self.predicate = predicate
        self.filter = filter
        self.state = State(predicate: predicate, filter: filter)
    }
}

extension EntityQuery {
    @usableFromInline
    final class State: @unchecked Sendable {
        @usableFromInline
        private(set) var archetypes: [Archetype] = []
        
        @usableFromInline
        let predicate: QueryPredicate
        
        @usableFromInline
        let filter: Filter
        
        private(set) weak var world: World?
        
        internal init(predicate: QueryPredicate, filter: Filter) {
            self.predicate = predicate
            self.filter = filter
        }
        
        func updateArchetypes(in world: World) {
            self.world = world
            self.archetypes = world.archetypes.filter { self.predicate.evaluate($0) }
        }
    }
}

// MARK: Predicate

/// An object that defines the criteria for an entity query.
public struct QueryPredicate: Sendable {
    let evaluate: @Sendable (Archetype) -> Bool
}

prefix public func ! (operand: QueryPredicate) -> QueryPredicate {
    QueryPredicate { archetype in
        !operand.evaluate(archetype)
    }
}

public extension QueryPredicate {
    /// Set the rule that entity should contains given type.
    static func has<T: Component>(_ type: T.Type) -> QueryPredicate {
        QueryPredicate { archetype in
            return archetype.componentsBitMask.contains(type.identifier)
        }
    }
    
    /// Set the rule that entity doesn't contains given type.
    static func without<T: Component>(_ type: T.Type) -> QueryPredicate {
        QueryPredicate { archetype in
            return !archetype.componentsBitMask.contains(type.identifier)
        }
    }
    
    /// Set AND condition for predicate.
    static func && (lhs: QueryPredicate, rhs: QueryPredicate) -> QueryPredicate {
        QueryPredicate { value in
            lhs.evaluate(value) && rhs.evaluate(value)
        }
    }
    
    /// Set OR condition for predicate.
    static func || (lhs: QueryPredicate, rhs: QueryPredicate) -> QueryPredicate {
        QueryPredicate { value in
            lhs.evaluate(value) || rhs.evaluate(value)
        }
    }
}

/// Contains array of entities matched for the given EntityQuery request.
public struct QueryResult: Sequence, Sendable {

    let state: EntityQuery.State
    
    internal init(state: EntityQuery.State) {
        self.state = state
    }
    
    public typealias Element = Entity
    public typealias Iterator = EntityIterator
    
    /// Returns first element of collection.
    public var first: Element? {
        return self.first { _ in return true }
    }
    
    /// Calculate count of element in collection
    /// - Complexity: O(n)
    public var count: Int {
        return self.count { _ in return true }
    }
    
    /// Return iterator over the query results.
    public func makeIterator() -> Iterator {
        return EntityIterator(state: self.state)
    }
    
    /// A Boolean value indicating whether the collection is empty.
    public var isEmpty: Bool {
        return self.state.archetypes.isEmpty
    }
}

// MARK: Iterator

public extension QueryResult {
    /// This iterator iterate by each entity in passed archetype array
    struct EntityIterator: IteratorProtocol {

        // We use pointer to avoid additional allocation in memory
        let count: Int
        let state: EntityQuery.State
        
        private var currentArchetypeIndex = 0
        private var currentEntityIndex = -1 // We should use -1 for first iterating.
        private var canIterateNext: Bool = true
        
        /// - Parameter pointer: Pointer to archetypes array.
        /// - Parameter count: Count archetypes in array.
        init(state: EntityQuery.State) {
            self.count = state.archetypes.count
            self.state = state
        }
        
        public mutating func next() -> Element? {
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
}
