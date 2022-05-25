//
//  Query.swift
//  
//
//  Created by v.prusakov on 5/24/22.
//

public struct EntityQuery {
    let predicate: QueryPredicate<Entity>
    
    public init(where predicate: QueryPredicate<Entity>) {
        self.predicate = predicate
    }
}

// MARK: Predicate

public struct QueryPredicate<Value> {
    let fetch: (Value) -> Bool
}

public extension QueryPredicate {
    static func has<T: Component>(_ type: T.Type) -> QueryPredicate<Entity> {
        QueryPredicate<Entity> { entity in
            return entity.components.has(type)
        }
    }
    
    static func && (lhs: QueryPredicate<Value>, rhs: QueryPredicate<Value>) -> QueryPredicate<Value> {
        QueryPredicate { value in
            lhs.fetch(value) && rhs.fetch(value)
        }
    }
    
    static func || (lhs: QueryPredicate<Value>, rhs: QueryPredicate<Value>) -> QueryPredicate<Value> {
        QueryPredicate { value in
            lhs.fetch(value) || rhs.fetch(value)
        }
    }
}
