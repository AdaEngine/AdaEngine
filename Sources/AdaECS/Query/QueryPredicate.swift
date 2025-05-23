//
//  QueryPredicate.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.05.2025.
//

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
