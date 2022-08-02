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
    let predicate: QueryPredicate
    
    /// - Parameter predicate: Describe what entity should contains to satisfy query.
    public init(where predicate: QueryPredicate) {
        self.predicate = predicate
    }
}

// MARK: Predicate

public struct QueryPredicate {
    let evaluate: (Archetype) -> Bool
}

public extension QueryPredicate {
    /// Set the rule that entity should contains given type.
    static func has<T: Component>(_ type: T.Type) -> QueryPredicate {
        QueryPredicate { archetype in
            return archetype.componentsBitMask.contains(type.identifier)
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
    
    // TODO: (Vlad) I'm not sure that archetype as ref types should right choise.
    private var buffer: [Archetype]
    
    internal init(archetypes: [Archetype]) {
        self.buffer = archetypes
    }
    
    public typealias Element = Entity
    public typealias Iterator = EntityIterator
    
    public func makeIterator() -> Iterator {
        return EntityIterator(pointer: buffer, count: buffer.count)
    }
    
    /// A Boolean value indicating whether the collection is empty.
    public var isEmpty: Bool {
        return self.buffer.isEmpty
    }
}

// MARK: Iterator

public extension QueryResult {
    /// This iterator iterrate by each entity in passed archetype array
    struct EntityIterator: IteratorProtocol {
        
        // We use pointer to avoid additional allocation in memory
        let pointer: UnsafePointer<Archetype>
        let count: Int
        
        private var currentArchetypeIndex = 0
        private var currentEntityIndex = -1 // We should use -1 for first itterating.
        
        /// - Parameter pointer: Pointer to archetypes array.
        /// - Parameter count: Count archetypes in array.
        init(pointer: UnsafePointer<Archetype>, count: Int) {
            self.pointer = pointer
            self.count = count
        }
        
        public mutating func next() -> Element? {
            // swiftlint:disable:next empty_count
            guard self.count > 0 else {
                return nil
            }
            
            let currentEntitiesCount = self.pointer.advanced(by: self.currentArchetypeIndex).pointee.entities.count
            
            if self.currentEntityIndex < currentEntitiesCount - 1 {
                self.currentEntityIndex += 1
            } else {
                self.currentArchetypeIndex += 1
                self.currentEntityIndex = 0
            }
            
            guard self.currentArchetypeIndex < self.count else {
                return nil
            }
            
            let currentArchetype = self.pointer.advanced(by: self.currentArchetypeIndex).pointee
            
            while currentArchetype.entities[currentEntityIndex] == nil {
                if self.currentEntityIndex < currentEntitiesCount - 1 {
                    self.currentEntityIndex += 1
                }
            }
            
            return currentArchetype.entities[currentEntityIndex]
        }
    }
}
