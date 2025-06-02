//
//  QueryResult.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/21/25.
//

/// Contains array of entities matched for the given EntityQuery request.
public struct QueryResult<B: QueryBuilder>: Sequence, Sendable {

    /// The element type of the query result.
    public typealias Element = B.Components

    /// The iterator type of the query result.
    public typealias Iterator = QueryTargetIterator<B>

    /// The state of the query result.
    let state: QueryState

    /// Initialize a new query result.
    /// - Parameter state: The state of the query result.
    internal init(state: QueryState) {
        self.state = state
    }
    
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
        QueryTargetIterator(state: self.state)
    }
}

/// An iterator that iterates over the query targets.
public struct QueryTargetIterator<B: QueryBuilder>: IteratorProtocol {

    /// The element type of the query target iterator.
    public typealias Element = B.Components

    /// The state of the query target iterator.
    let state: QueryState

    /// The entity iterator of the query target iterator.
    var entityIterator: EntityIterator

    /// Initialize a new query target iterator.
    /// - Parameter state: The state of the query target iterator.
    init(state: QueryState) {
        self.entityIterator = .init(state: state)
        self.state = state
    }

    public mutating func next() -> Element? {
        guard let entity = self.entityIterator.next() else {
            return nil
        }

        return B.getQueryTarget(from: entity)
    }
}