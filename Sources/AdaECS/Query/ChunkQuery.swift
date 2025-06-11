//
//  ChunkQuery.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2025.
//

import Foundation
//
///// A high-performance query system that operates directly on chunks for optimal memory access patterns
//public struct ChunkQuery<Components>: Sendable {
//    /// The component types this query searches for
//    private let componentIds: [ComponentId]
//    
//    /// Filter predicate for additional constraints
//    private let filter: ChunkFilter?
//    
//    /// Cache of matching archetypes and their chunks
//    private var cachedChunks: [Archetype.ID: [Int]] = [:]
//    
//    /// Version tracking for cache invalidation
//    private var cacheVersion: UInt64 = 0
//    
//    public init(componentIds: [ComponentId], filter: ChunkFilter? = nil) {
//        self.componentIds = componentIds.sorted { $0.id < $1.id }
//        self.filter = filter
//    }
//    
//    /// Execute the query on a world and iterate over matching chunks
//    /// - Parameters:
//    ///   - world: The world to query
//    ///   - callback: Callback executed for each matching chunk
//    public mutating func forEach(in world: World, _ callback: (ChunkIterator<Components>) throws -> Void) rethrows {
//        let matchingChunks = getMatchingChunks(from: world)
//        
//        for (archetypeId, chunkIndices) in matchingChunks {
//            for chunkIndex in chunkIndices {
//                let chunk = world.chunks.chunks[chunkIndex]
//                let iterator = ChunkIterator<Components>(
//                    chunk: chunk,
//                    componentIds: componentIds
//                )
//                try callback(iterator)
//            }
//        }
//    }
//    
//    /// Execute the query asynchronously with parallel processing
//    /// - Parameters:
//    ///   - world: The world to query
//    ///   - callback: Async callback executed for each matching chunk
//    public mutating func forEachAsync(in world: World, _ callback: @Sendable (ChunkIterator<Components>) async throws -> Void) async rethrows {
//        let matchingChunks = getMatchingChunks(from: world)
//        
//        try await withThrowingTaskGroup(of: Void.self) { group in
//            for (_, chunkIndices) in matchingChunks {
//                for chunkIndex in chunkIndices {
//                    group.addTask {
//                        let chunk = world.chunks.chunks[chunkIndex]
//                        let iterator = ChunkIterator<Components>(
//                            chunk: chunk,
//                            componentIds: self.componentIds
//                        )
//                        try await callback(iterator)
//                    }
//                }
//            }
//            
//            try await group.waitForAll()
//        }
//    }
//    
//    /// Get statistics about the query results
//    /// - Parameter world: The world to analyze
//    /// - Returns: Query statistics
//    public mutating func getStats(from world: World) -> ChunkQueryStats {
//        let matchingChunks = getMatchingChunks(from: world)
//        
//        var totalChunks = 0
//        var totalEntities = 0
//        var totalCapacity = 0
//        
//        for (_, chunkIndices) in matchingChunks {
//            totalChunks += chunkIndices.count
//            for chunkIndex in chunkIndices {
//                let chunk = world.chunks.chunks[chunkIndex]
//                totalEntities += chunk.entityCount
//                totalCapacity += chunk.capacity
//            }
//        }
//        
//        return ChunkQueryStats(
//            matchingArchetypes: matchingChunks.count,
//            matchingChunks: totalChunks,
//            totalEntities: totalEntities,
//            totalCapacity: totalCapacity,
//            utilization: totalCapacity > 0 ? Double(totalEntities) / Double(totalCapacity) : 0.0
//        )
//    }
//    
//    /// Get matching chunks from the world
//    private mutating func getMatchingChunks(from world: World) -> [Archetype.ID: [Int]] {
//        // Simple cache invalidation - in a real implementation, you'd want more sophisticated versioning
//        if cacheVersion != world.chunks.version {
//            cachedChunks.removeAll()
//            cacheVersion = world.chunks.version
//        }
//        
//        if cachedChunks.isEmpty {
//            updateCache(from: world)
//        }
//        
//        return cachedChunks
//    }
//    
//    /// Update the cached matching chunks
//    private mutating func updateCache(from world: World) {
//        cachedChunks.removeAll()
//        
//        for archetype in world.archetypes.archetypes {
//            if archetypeMatches(archetype) {
//                let chunkIndices = world.chunks.getChunks(for: archetype.id)
//                if !chunkIndices.isEmpty {
//                    cachedChunks[archetype.id] = chunkIndices
//                }
//            }
//        }
//    }
//    
//    /// Check if an archetype matches the query requirements
//    private func archetypeMatches(_ archetype: Archetype) -> Bool {
//        // Check if archetype contains all required components
//        for componentId in componentIds {
//            if !archetype.componentsBitMask.contains(componentId) {
//                return false
//            }
//        }
//        
//        // Apply additional filters if present
//        if let filter = filter {
//            return filter.matches(archetype)
//        }
//        
//        return true
//    }
//}
//
///// Statistics about a chunk query execution
//public struct ChunkQueryStats: Sendable {
//    public let matchingArchetypes: Int
//    public let matchingChunks: Int
//    public let totalEntities: Int
//    public let totalCapacity: Int
//    public let utilization: Double
//    
//    public var wastedCapacity: Int {
//        return totalCapacity - totalEntities
//    }
//}
//
///// Filter for additional chunk query constraints
//public protocol ChunkFilter: Sendable {
//    /// Check if an archetype matches this filter
//    /// - Parameter archetype: The archetype to check
//    /// - Returns: true if the archetype matches the filter
//    func matches(_ archetype: Archetype) -> Bool
//}
//
///// A high-performance iterator over entities in a chunk
//public struct ChunkIterator<Components>: Sendable {
//    /// The chunk being iterated
//    private let chunk: Chunk
//    
//    /// Component IDs for the components being accessed
//    private let componentIds: [ComponentId]
//    
//    /// Cached component data pointers for fast access
//    private let componentPointers: [ComponentId: UnsafeMutableRawPointer]
//    
//    /// Current iteration index
//    private var currentIndex: Int = 0
//    
//    /// Array of occupied indices for efficient iteration
//    private let occupiedIndices: [Int]
//    
//    public init(chunk: Chunk, componentIds: [ComponentId]) {
//        self.chunk = chunk
//        self.componentIds = componentIds
//        self.componentPointers = chunk.getAllComponentData()
//        self.occupiedIndices = chunk.getOccupiedIndices()
//    }
//    
//    /// Get the number of entities in this chunk
//    public var entityCount: Int {
//        return chunk.entityCount
//    }
//    
//    /// Get the chunk capacity
//    public var capacity: Int {
//        return chunk.capacity
//    }
//    
//    /// Iterate over all entities in the chunk
//    /// - Parameter callback: Callback executed for each entity
//    public func forEach<T>(_ callback: (ChunkEntity<T>) throws -> Void) rethrows {
//        for entityIndex in occupiedIndices {
//            let entity = ChunkEntity<T>(
//                entityId: chunk.entities[entityIndex],
//                entityIndex: entityIndex,
//                chunk: chunk,
//                componentPointers: componentPointers
//            )
//            try callback(entity)
//        }
//    }
//    
//    /// Iterate over entities with index information
//    /// - Parameter callback: Callback executed for each entity with its index
//    public func forEachIndexed<T>(_ callback: (Int, ChunkEntity<T>) throws -> Void) rethrows {
//        for (index, entityIndex) in occupiedIndices.enumerated() {
//            let entity = ChunkEntity<T>(
//                entityId: chunk.entities[entityIndex],
//                entityIndex: entityIndex,
//                chunk: chunk,
//                componentPointers: componentPointers
//            )
//            try callback(index, entity)
//        }
//    }
//    
//    /// Get component data arrays for vectorized operations
//    /// - Parameter componentId: The component to get data for
//    /// - Returns: Unsafe pointer to the component data array
//    public func getComponentArray<T>(for componentId: ComponentId, as type: T.Type) -> UnsafeMutablePointer<T>? {
//        guard let pointer = componentPointers[componentId] else {
//            return nil
//        }
//        return pointer.bindMemory(to: type, capacity: capacity)
//    }
//    
//    /// Perform vectorized operations on component data
//    /// - Parameters:
//    ///   - componentId: The component type to operate on
//    ///   - operation: The vectorized operation to perform
//    public func vectorizedOperation<T>(on componentId: ComponentId, as type: T.Type, _ operation: (UnsafeMutableBufferPointer<T>) throws -> Void) rethrows {
//        guard let pointer = getComponentArray(for: componentId, as: type) else {
//            return
//        }
//        
//        let buffer = UnsafeMutableBufferPointer(start: pointer, count: capacity)
//        try operation(buffer)
//    }
//}
//
///// Represents an entity within a chunk context
//public struct ChunkEntity<Components>: Sendable {
//    /// The entity ID
//    public let entityId: Entity.ID
//    
//    /// The index of this entity within the chunk
//    public let entityIndex: Int
//    
//    /// Reference to the chunk (for accessing component data)
//    private let chunk: Chunk
//    
//    /// Cached component pointers for fast access
//    private let componentPointers: [ComponentId: UnsafeMutableRawPointer]
//    
//    internal init(
//        entityId: Entity.ID,
//        entityIndex: Int,
//        chunk: Chunk,
//        componentPointers: [ComponentId: UnsafeMutableRawPointer]
//    ) {
//        self.entityId = entityId
//        self.entityIndex = entityIndex
//        self.chunk = chunk
//        self.componentPointers = componentPointers
//    }
//    
//    /// Get a component for this entity
//    /// - Parameters:
//    ///   - componentId: The component identifier
//    ///   - type: The component type
//    /// - Returns: Pointer to the component data, or nil if not found
//    public func getComponent<T>(for componentId: ComponentId, as type: T.Type) -> UnsafeMutablePointer<T>? {
//        return chunk.getComponentData(at: entityIndex, for: componentId, as: type)
//    }
//    
//    /// Get multiple components at once for efficient access
//    /// - Parameter componentIds: Array of component identifiers
//    /// - Returns: Dictionary mapping component IDs to their data pointers
//    public func getComponents(for componentIds: [ComponentId]) -> [ComponentId: UnsafeMutableRawPointer] {
//        var result: [ComponentId: UnsafeMutableRawPointer] = [:]
//        
//        for componentId in componentIds {
//            if let pointer = componentPointers[componentId],
//               let componentSize = chunk.componentLayout.componentSizes[componentId] {
//                let offset = entityIndex * componentSize
//                result[componentId] = pointer.advanced(by: offset)
//            }
//        }
//        
//        return result
//    }
//}
//
//// MARK: - Extensions for World
//
//public extension World {
//    /// Create a chunk query for the specified component types
//    /// - Parameter componentIds: The component types to query for
//    /// - Returns: A configured chunk query
//    func createChunkQuery<T>(for componentIds: [ComponentId]) -> ChunkQuery<T> {
//        return ChunkQuery<T>(componentIds: componentIds)
//    }
//    
//    /// Create a chunk query with a filter
//    /// - Parameters:
//    ///   - componentIds: The component types to query for
//    ///   - filter: Additional filter constraints
//    /// - Returns: A configured chunk query
//    func createChunkQuery<T>(for componentIds: [ComponentId], filter: ChunkFilter) -> ChunkQuery<T> {
//        return ChunkQuery<T>(componentIds: componentIds, filter: filter)
//    }
//}
//
//// MARK: - Common Chunk Filters
//
///// Filter that excludes archetypes containing specific components
//public struct ExcludeFilter: ChunkFilter {
//    private let excludedComponents: [ComponentId]
//    
//    public init(excluding componentIds: [ComponentId]) {
//        self.excludedComponents = componentIds
//    }
//    
//    public func matches(_ archetype: Archetype) -> Bool {
//        for componentId in excludedComponents {
//            if archetype.componentsBitMask.contains(componentId) {
//                return false
//            }
//        }
//        return true
//    }
//}
//
///// Filter that requires specific optional components
//public struct OptionalFilter: ChunkFilter {
//    private let optionalComponents: [ComponentId]
//    private let requireAtLeastOne: Bool
//    
//    public init(optional componentIds: [ComponentId], requireAtLeastOne: Bool = false) {
//        self.optionalComponents = componentIds
//        self.requireAtLeastOne = requireAtLeastOne
//    }
//    
//    public func matches(_ archetype: Archetype) -> Bool {
//        if !requireAtLeastOne {
//            return true
//        }
//        
//        for componentId in optionalComponents {
//            if archetype.componentsBitMask.contains(componentId) {
//                return true
//            }
//        }
//        
//        return false
//    }
//}
//
///// Composite filter that combines multiple filters
//public struct CompositeFilter: ChunkFilter {
//    private let filters: [ChunkFilter]
//    private let operation: Operation
//    
//    public enum Operation: Sendable {
//        case and
//        case or
//    }
//    
//    public init(_ filters: [ChunkFilter], operation: Operation = .and) {
//        self.filters = filters
//        self.operation = operation
//    }
//    
//    public func matches(_ archetype: Archetype) -> Bool {
//        switch operation {
//        case .and:
//            return filters.allSatisfy { $0.matches(archetype) }
//        case .or:
//            return filters.contains { $0.matches(archetype) }
//        }
//    }
//} 
