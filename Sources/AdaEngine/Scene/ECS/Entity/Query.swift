//
//  Query.swift
//  
//
//  Created by v.prusakov on 5/24/22.
//

/// This object describe query to ecs world.
///
/// ```swift
/// struct MovementSystem: System {
///     static let query = EntityQuery(where: .has(Transform.self))
///
///     func update(context: UpdateContext) {
///         context.scene.performQuery(Self.query).forEach {
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
///         var entities = context.scene.performQuery(Self.query)
///
///         for entity in entities {
///             // Get components from entity and do some render
///         }
///     }
/// }
/// ```
@frozen public struct EntityQuery {
    
    public struct Filter: OptionSet {
        public typealias RawValue = UInt8
        
        public var rawValue: UInt8
        
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
        
        public static let added = Filter(rawValue: 1 << 0)
        
        public static let stored = Filter(rawValue: 1 << 1)
        
        public static let removed = Filter(rawValue: 1 << 2)
        
        public static let all: Filter = [.added, .stored, .removed]
    }
    
    let state: State
    let predicate: QueryPredicate
    let filter: Filter
    
    /// - Parameter predicate: Describe what entity should contains to satisfy query.
    public init(where predicate: QueryPredicate, filter: Filter = .all) {
        self.predicate = predicate
        self.filter = filter
        self.state = State(predicate: predicate, filter: filter)
    }
}

extension EntityQuery {
    @usableFromInline
    final class State {
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

public struct QueryPredicate {
    let evaluate: (Archetype) -> Bool
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
    
    static func && (lhs: QueryPredicate, rhs: QueryPredicate) -> QueryPredicate {
        QueryPredicate { value in
            lhs.evaluate(value) && rhs.evaluate(value)
        }
    }
    
    static func || (lhs: QueryPredicate, rhs: QueryPredicate) -> QueryPredicate {
        QueryPredicate { value in
            lhs.evaluate(value) || rhs.evaluate(value)
        }
    }
}

/// Contains array of entities matched for the given EntityQuery request.
public struct QueryResult: Sequence {
    
    let state: EntityQuery.State
    
    internal init(state: EntityQuery.State) {
        self.state = state
    }
    
    public typealias Element = Entity
    public typealias Iterator = EntityIterator
    
    public var first: Element? {
        return self.first { _ in return true }
    }
    
    /// Return concurrent iterator over the query results.
    public var concurrentIterator: ConcurrentIterator {
        ConcurrentIterator(state: self.state)
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
}

extension QueryResult {
    
    /// A parallel iterator over query results.
    public struct ConcurrentIterator {
        
        public typealias Element = QueryResult.Element
        
        @usableFromInline
        let state: EntityQuery.State
        
        init(state: EntityQuery.State) {
            self.state = state
        }
        
        /// Calls the given closure on each element in the query in parallel.
        ///
        /// - Parameter body: A closure that takes an element of the sequence as a
        ///   parameter.
        @inlinable
        @inline(__always)
        public func forEach(_ body: (Self.Element) -> Void) {
            let arhetypes = self.state.archetypes
            
            for arhetype in arhetypes {
                let entities = arhetype.entities
                DispatchQueue.concurrentPerform(iterations: entities.count) { index in
                    
                    // skip nil values in space array
                    guard let entity = entities[index] else {
                        return
                    }
                    
                    body(entity)
                }
            }
        }
    }
}
