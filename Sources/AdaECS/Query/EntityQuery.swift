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
///     func update(context: UpdateContext) {
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
///     func update(context: UpdateContext) {
///         for entity in self.query {
///             // Get components from entity and do some render
///         }
///     }
/// }
/// ```
@propertyWrapper
@frozen public struct EntityQuery: Sendable {

    public var wrappedValue: QueryResult<Entity> {
        return QueryResult(state: self.state)
    }

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

extension EntityQuery: SystemQuery {
    public func update(from world: World) {
        self.state.updateArchetypes(in: world)
    }
}

extension EntityQuery {
    @usableFromInline
    final class State: @unchecked Sendable, QueryState {
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
