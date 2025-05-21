//
//  QueryResult.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/21/25.
//

public protocol QueryState: Sendable {}

/// Contains array of entities matched for the given EntityQuery request.
public struct QueryResult<T: Sendable>: Sendable {

    let state: any QueryState

    internal init(state: any QueryState) {
        self.state = state
    }
}

// MARK: Iterator

extension QueryResult: Sequence where T == Entity {

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

    private var entityState: EntityQuery.State {
        return self.state as! EntityQuery.State
    }

        /// A Boolean value indicating whether the collection is empty.
    public var isEmpty: Bool {
        return self.entityState.archetypes.isEmpty
    }

    /// Return iterator over the query results.
    public func makeIterator() -> Iterator {
        return EntityIterator(state: self.entityState)
    }

    /// This iterator iterate by each entity in passed archetype array
    public struct EntityIterator: IteratorProtocol {

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
