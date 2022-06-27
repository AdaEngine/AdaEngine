//
//  Query.swift
//  
//
//  Created by v.prusakov on 5/24/22.
//

@frozen
public struct EntityQuery {
    let predicate: QueryPredicate
    
    public init(where predicate: QueryPredicate) {
        self.predicate = predicate
    }
}

// MARK: Predicate

public struct QueryPredicate {
    let evaluate: (Archetype) -> Bool
}

public extension QueryPredicate {
    static func has<T: Component>(_ type: T.Type) -> QueryPredicate {
        QueryPredicate { archetype in
            return archetype.componentsBitMask.contains(type)
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

@frozen
public struct QueryResult: Sequence {
    
    internal init(entities: [Entity]) {
        self.buffer = entities
    }
    
    private var buffer: [Entity] = []
    
    public typealias Element = Entity
    public typealias Iterator = IndexingIterator<[Element]>
    
    public func makeIterator() -> Iterator {
        return buffer.makeIterator()
    }
    
    /// A Boolean value indicating whether the collection is empty.
    public var isEmpty: Bool {
        return self.buffer.isEmpty
    }
    
    /// The number of elements in the result.
    public var count: Int {
        return self.buffer.count
    }
}
