//
//  Chunks.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2025.
//

import AdaUtils
import Foundation
import OrderedCollections

// - [] Remove free chunks

public struct ChunkLocation: Sendable {
    public let chunkIndex: Int
    public let entityRow: Int
}

/// A chunk-based storage system for ECS components
/// Provides memory-efficient, cache-friendly storage for entities and their components
public struct Chunks: Sendable {

    let componentLayout: ComponentLayout

    /// Array of chunks for different archetypes
    public private(set) var chunks: [Chunk] = []
    
    /// Configuration for chunk storage
    public let chunkSize: Int

    private var friedLocation: [ChunkLocation] = []
    /// Location entity in chunk
    public private(set) var entities: [Entity.ID: ChunkLocation] = [:]

    public init(chunkSize: Int = 32, componentLayout: ComponentLayout) {
        self.chunkSize = chunkSize
        self.componentLayout = componentLayout
        self.chunks.append(Chunk(capacity: chunkSize, layout: componentLayout))
    }

    mutating func getFreeChunkIndex() -> Int {
        if let firstLocation = friedLocation.popLast() {
            return firstLocation.chunkIndex
        } else if self.chunks.last?.isFull != true {
            return self.chunks.endIndex - 1
        } else {
            self.chunks.append(Chunk(capacity: self.chunkSize, layout: componentLayout))
            return self.chunks.endIndex - 1
        }
    }

    @discardableResult
    mutating func insertEntity(_ entity: Entity.ID, components: [any Component]) -> ChunkLocation {
        let location = self.getFreeChunkIndex()
        var chunk = self.chunks[location]
        let entityLocation = chunk.addEntity(entity)!
        chunk.insert(at: entityLocation, components: components)
        let chunkLocation = ChunkLocation(
            chunkIndex: location,
            entityRow: entityLocation
        )
        self.entities[entity] = chunkLocation
        self.chunks[location] = chunk
        return chunkLocation
    }

    mutating func removeEntity(_ entity: Entity.ID) {
        guard let location = self.entities[entity] else {
            return
        }
        self.chunks[location.chunkIndex].removeEntity(at: location.entityRow)
        self.friedLocation.append(location)
    }
//
//    mutating func removeAll(keepingCapacity: Bool = false) {
//        self.friedLocation.removeAll()
//        self.chunks.removeAll(keepingCapacity: keepingCapacity)
//    }
//
//    /// Get total number of entities across all chunks
//    public var totalEntityCount: Int {
//        return chunks.reduce(0) { $0 + $1.entityCount }
//    }
//    
//    /// Get memory usage statistics
//    public var memoryStats: ChunkMemoryStats {
//        let totalChunks = chunks.count
//        let activeChunks = chunks.filter { $0.entityCount > 0 }.count
//        let totalCapacity = chunks.reduce(0) { $0 + $1.capacity }
//        let usedCapacity = chunks.reduce(0) { $0 + $1.entityCount }
//        
//        return ChunkMemoryStats(
//            totalChunks: totalChunks,
//            activeChunks: activeChunks,
//            totalCapacity: totalCapacity,
//            usedCapacity: usedCapacity,
//            fragmentationRatio: totalCapacity > 0 ? Double(usedCapacity) / Double(totalCapacity) : 0.0
//        )
//    }
}

/// Memory usage statistics for chunk storage
public struct ChunkMemoryStats: Sendable {
    public let totalChunks: Int
    public let activeChunks: Int
    public let totalCapacity: Int
    public let usedCapacity: Int
    public let fragmentationRatio: Double
    
    public var wastedCapacity: Int {
        return totalCapacity - usedCapacity
    }
}

/// A memory-efficient chunk that stores entities and their components in contiguous memory
public struct Chunk: Sendable {
    
    /// Maximum number of entities this chunk can hold
    public let capacity: Int
    
    /// Current number of entities in this chunk
    public private(set) var entityCount: Int = 0
    
    /// Entity IDs stored in this chunk
    public private(set) var entities: OrderedDictionary<Entity.ID, Int>

    /// Raw component data storage (organized by component type)
    public private(set) var componentData: [ComponentId: BlobArray]

    /// Bitmask indicating which entity slots are occupied
    private var occupancyMask: BitArray
    
    /// Free entity indices that can be reused
    private var freeIndices: [Int] = []

    public var isFull: Bool {
        self.entityCount == capacity
    }

    public init(capacity: Int, layout: ComponentLayout) {
        self.capacity = capacity
        self.entities = [:]
        self.occupancyMask = BitArray(size: capacity)
        self.componentData = [:]
        for component in layout.components {
            self.componentData[component.identifier] = BlobArray(count: capacity, of: component)
        }
    }
    
    /// Add an entity to this chunk
    /// - Parameter entityId: The entity identifier to add
    /// - Returns: The index where the entity was placed, or nil if chunk is full
    public mutating func addEntity(_ entityId: Entity.ID) -> Int? {
        if entityCount >= capacity {
            return nil
        }
        
        let index: Int
        if let freeIndex = freeIndices.popLast() {
            index = freeIndex
        } else {
            index = entityCount
        }
        
        entities[entityId] = index
        occupancyMask.set(index, to: true)
        entityCount += 1
        
        return index
    }
    
    /// Remove an entity from this chunk
    /// - Parameter index: The index of the entity to remove
    public mutating func removeEntity(at entityId: Entity.ID) {
        guard let index = self.entities[entityId] else {
            return
        }

        guard index < capacity && occupancyMask.get(index) else {
            return
        }
        
        entities[entityId] = 0
        occupancyMask.set(index, to: false)
        entityCount -= 1
        freeIndices.append(index)
    }

    public func insert(at entityIndex: Int, components: [any Component]) {
        for component in components {
            let componentId = type(of: component).identifier
            guard let array = componentData[componentId] else {
                fatalError()
            }
            array.insert(element: component, at: entityIndex)
        }
    }

    @inline(__always)
    public func get<T: Component>(at entityIndex: Int) -> T? {
        self.componentData[T.identifier]?.get(at: entityIndex, as: T.self)
    }

    @inline(__always)
    public func get<T: Component>(_ type: T.Type, for entity: Entity.ID) -> T? {
        guard let index = self.entities[entity] else {
            return nil
        }
        return self.componentData[T.identifier]?.get(at: index, as: T.self)
    }

    @inline(__always)
    public func getMutablePointer<T: Component>(_ type: T.Type, for entity: Entity.ID) -> UnsafeMutablePointer<T>? {
        guard let index = self.entities[entity] else {
            return nil
        }
        return self.componentData[T.identifier]?.getMutablePointer(at: index, as: T.self)
    }

    public func set<T: Component>(_ component: consuming T, at entityIndex: Int) {
        self.componentData[T.identifier]?.insert(element: component, at: entityIndex)
    }

    /// Get all component data arrays for efficient iteration
    /// - Returns: Dictionary mapping component IDs to their data arrays
    public func getAllComponentData() -> [ComponentId: BlobArray] {
        return componentData
    }
    
    /// Check if an entity slot is occupied
    /// - Parameter index: The entity index to check
    /// - Returns: true if the slot is occupied
    public func isOccupied(at index: Int) -> Bool {
        return index < capacity && occupancyMask.get(index)
    }
    
    /// Get array of occupied entity indices for efficient iteration
    /// - Returns: Array of indices that contain entities
    public func getOccupiedIndices() -> [Int] {
        return (0..<capacity).filter { occupancyMask.get($0) }
    }

    /// Get array of occupied entity indices for efficient iteration
    /// - Returns: Array of indices that contain entities
    public func getFreeIndex() -> Int? {
        return (0..<capacity).firstIndex { !occupancyMask.get($0) }
    }

    /// Cleanup and deallocate memory
    public func deallocate() {
        for (_, pointer) in componentData {
            pointer.data.deallocate()
        }
    }
}

/// A bit array for efficiently tracking occupied slots in chunks
public struct BitArray: Sendable {
    private var storage: [UInt64]
    private let size: Int
    
    public init(size: Int) {
        self.size = size
        let wordCount = (size + 63) / 64 // Round up to nearest multiple of 64
        self.storage = Array(repeating: 0, count: wordCount)
    }
    
    public func get(_ index: Int) -> Bool {
        guard index < size else { return false }
        let wordIndex = index / 64
        let bitIndex = index % 64
        return (storage[wordIndex] & (1 << bitIndex)) != 0
    }
    
    public mutating func set(_ index: Int, to value: Bool) {
        guard index < size else { return }
        let wordIndex = index / 64
        let bitIndex = index % 64
        
        if value {
            storage[wordIndex] |= (1 << bitIndex)
        } else {
            storage[wordIndex] &= ~(1 << bitIndex)
        }
    }
    
    /// Count the number of set bits (occupied slots)
    public func popCount() -> Int {
        return storage.reduce(0) { $0 + $1.nonzeroBitCount }
    }
}

