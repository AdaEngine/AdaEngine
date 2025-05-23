//
//  QueryResult.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/21/25.
//

/// Contains array of entities matched for the given EntityQuery request.
public struct QueryResult<B: QueryBuilder>: Sequence, Sendable {

    public typealias Element = B.Components
    public typealias Iterator = QueryTargetIterator<B>

    let state: QueryState

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

public struct QueryTargetIterator<B: QueryBuilder>: IteratorProtocol {

    public typealias Element = B.Components

    let state: QueryState
    var entityIterator: EntityIterator

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