//
//  Chunks.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2025.
//

import AdaUtils
import Foundation
import OrderedCollections

public struct ChunkLocation: Sendable {
    public let chunkIndex: Int
    public let entityRow: Int
}

/// A chunk-based storage system for ECS components
/// Provides memory-efficient, cache-friendly storage for entities and their components
public final class Chunks: @unchecked Sendable {
    let componentLayout: ComponentLayout

    /// Array of chunks for different archetypes
    public internal(set) var chunks: ManagedArray<Chunk> = .init()

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

    func getFreeChunkIndex() -> Int {
        if let firstLocation = friedLocation.popLast() {
//            print("Get free chunk index from friedLocation \(firstLocation.chunkIndex)")
            return firstLocation.chunkIndex
        } else if self.chunks.reborrow(at: self.chunks.endIndex - 1, { $0.isFull }) == false {
//            print(
//                "Get free chunk index \(self.chunks.endIndex), entityCount \(self.chunks.reborrow(at: self.chunks.endIndex - 1) { $0.entityCount })"
//            )
            return max(0, self.chunks.endIndex - 1)
        } else {
//            print("Append chunk \(self.chunks.endIndex)")
            self.chunks.append(Chunk(capacity: self.chunkSize, layout: componentLayout))
            return self.chunks.endIndex - 1
        }
    }

    func insert<T: Component>(
        _ component: T,
        for entity: Entity.ID,
        lastTick: Tick
    ) {
        guard let location = self.entities[entity] else {
            return
        }
        self.chunks.reborrow(at: location.chunkIndex) { chunk in
            chunk.set(
                component,
                at: location.chunkIndex,
                lastTick: lastTick)
        }
    }

    @discardableResult
    func insertEntity(_ entity: Entity.ID, components: [any Component]) -> ChunkLocation {
        let location = self.getFreeChunkIndex()
//        print(
//            "Insert entity \(entity), comp: \(components.map { type(of: $0) }) to chunk \(location), chunks count \(chunks.count)"
//        )
        return self.chunks.reborrow(at: location) { chunk in
//            print(
//                "Chunk capacity \(chunk.capacity), entityCount \(chunk.entityCount), isFull \(chunk.isFull)"
//            )
            guard let entityLocation = chunk.addEntity(entity) else {
                fatalError("Failed to add entity to chunk")
            }
            chunk.insert(at: entityLocation, components: components)
            let chunkLocation = ChunkLocation(
                chunkIndex: location,
                entityRow: entityLocation
            )
            self.entities[entity] = chunkLocation
            return chunkLocation
        }
    }

    func removeEntity(_ entity: Entity.ID) {
        guard let location = self.entities[entity] else {
//            print("Entity \(entity) not fiund")
            return
        }
//        print("Remove entity \(entity) from chunk \(location.chunkIndex)")
        let chunk = self.chunks.getPointer(at: location.chunkIndex)
        chunk.pointee.removeEntity(at: entity)
        if chunk.pointee.entityCount == 0, self.chunks.count > 1 {
             self.chunks.remove(at: location.chunkIndex)
            return
        }
        self.friedLocation.append(location)
    }

    func moveEntity(_ entity: Entity.ID, to chunks: inout Chunks) -> ChunkLocation {
        guard let location = self.entities[entity] else {
            fatalError("Entity \(entity) not found in chunks")
        }
        let chunkLocation = self.chunks.reborrow(at: location.chunkIndex) { oldChunk in
            let newLocation = chunks.getFreeChunkIndex()
            return chunks.chunks.reborrow(at: newLocation) { chunk in
                let entityLocation = chunk.addEntity(entity)!
                let chunkLocation = ChunkLocation(
                    chunkIndex: newLocation,
                    entityRow: entityLocation
                )
                chunks.entities[entity] = chunkLocation
                for component in chunks.componentLayout.components {
                    guard
                        let oldChunkComponent = oldChunk.componentsData[component.identifier],
                        var newChunkComponent = chunk.componentsData[component.identifier]
                    else {
                        continue
                    }

                    oldChunkComponent.data
                        .copyElement(
                            to: &newChunkComponent.data,
                            from: location.entityRow,
                            to: chunkLocation.entityRow
                        )
                    oldChunkComponent.changesTicks
                        .copyElement(
                            to: &newChunkComponent.changesTicks,
                            from: location.entityRow,
                            to: chunkLocation.entityRow
                        )
                    chunk.componentsData[component.identifier] = newChunkComponent
                }
                return chunkLocation
            }
        }
        self.removeEntity(entity)
        return chunkLocation
    }
}

/// A memory-efficient chunk that stores entities and their components in contiguous memory
public struct Chunk: Sendable, ~Copyable {

    public struct ComponentsData: @unchecked Sendable {
        var data: BlobArray
        var changesTicks: BlobArray

        init<T: Component>(capacity: Int, component: T.Type) {
            self.data = BlobArray(count: capacity, of: T.self)
            self.changesTicks = BlobArray(count: capacity, of: Tick.self)
        }
    }

    public struct ComponentData<T: Component> {
        public let component: UnsafeMutablePointer<T>
        public let changeTick: Tick
    }

    /// Maximum number of entities this chunk can hold
    public let capacity: Int

    /// Current number of entities in this chunk
    public private(set) var entityCount: Int = 0

    /// Entity IDs stored in this chunk
    public private(set) var entities: OrderedDictionary<Entity.ID, Int>

    /// Raw component data storage (organized by component type)
    public internal(set) var componentsData: [ComponentId: ComponentsData]

    /// Bitmask indicating which entity slots are occupied
    private var occupancyMask: BitArray

    /// Free entity indices that can be reused
    private var freeIndices: [Int] = []

    public var isFull: Bool {
        self.entityCount == capacity
    }

    public init(capacity: Int, layout: ComponentLayout) {
        print("New chunk", layout.components)
        self.capacity = capacity
        self.entities = [:]
        self.occupancyMask = BitArray(size: capacity)
        self.componentsData = [:]
        for component in layout.components {
            self.componentsData[component.identifier] = ComponentsData(
                capacity: capacity,
                component: component
            )
        }
    }

    /// Add an entity to this chunk
    /// - Parameter entityId: The entity identifier to add
    /// - Returns: The index where the entity was placed, or nil if chunk is full
    mutating func addEntity(_ entityId: Entity.ID) -> Int? {
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
    mutating func removeEntity(at entityId: Entity.ID) {
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

    func insert(at entityIndex: Int, components: [any Component]) {
        for component in components {
            let componentId = type(of: component).identifier
            guard let array = componentsData[componentId] else {
                fatalError()
            }
            array.data.insert(component, at: entityIndex)
        }
    }

    @inline(__always)
    public func get<T: Component>(at entityIndex: Int) -> T? {
        self.componentsData[T.identifier]?.data.get(at: entityIndex, as: T.self)
    }

    public func isComponentChanged<T: Component>(
        _ type: T.Type,
        for entity: Entity.ID,
        lastTick: Tick
    ) -> Bool {
        guard let entity = self.entities[entity] else {
            return false
        }
        return self.componentsData[T.identifier]?
            .changesTicks
            .get(at: entity, as: Tick.self) == lastTick
    }

    @inline(__always)
    public func get<T: Component>(_ type: T.Type, for entity: Entity.ID) -> T? {
        guard let index = self.entities[entity] else {
            return nil
        }
        return self.componentsData[T.identifier]?
            .data
            .get(at: index, as: T.self)
    }

//    public func getData<T: Component>(_ type: T.Type, for entityIndex: Int) -> ComponentData<T>? {
//        guard let data = self.componentsData[T.identifier] else {
//            return nil
//        }
//        return ComponentData(
//            component: data.data.getMutablePointer(at: entityIndex, as: T.self),
//            changeTick: data.changesTicks.get(at: entityIndex, as: Tick.self)
//        )
//    }

    @inline(__always)
    public func getMutablePointer<T: Component>(
        _ type: T.Type,
        for entity: Entity.ID
    ) -> UnsafeMutablePointer<T>? {
        guard let index = self.entities[entity] else {
            return nil
        }
        return self.componentsData[T.identifier]?
            .data
            .getMutablePointer(at: index, as: T.self)
    }

    public func getMutableTick<T: Component>(
        _ type: T.Type,
        for entity: Entity.ID
    ) -> UnsafeMutablePointer<Tick>? {
        guard let index = self.entities[entity] else {
            return nil
        }
        return self.componentsData[T.identifier]?
            .changesTicks
            .getMutablePointer(at: index, as: Tick.self)
    }
    public func set<T: Component>(
        _ component: consuming T,
        at entityIndex: Int,
        lastTick: Tick
    ) {
        guard let componentData = self.componentsData[T.identifier] else {
            assertionFailure("Component \(T.self) not found in chunk")
            return
        }
        componentData.changesTicks.insert(lastTick, at: entityIndex)
        componentData.data.insert(component, at: entityIndex)
    }

    /// Get all component data arrays for efficient iteration
    /// - Returns: Dictionary mapping component IDs to their data arrays
    public func getAllComponentData() -> [ComponentId: ComponentsData] {
        return componentsData
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
}

extension Chunk: NonCopybaleCustomStringConvertible {
    public var description: String {
        return """
        Chunk(
            capacity: \(capacity),
            entityCount: \(entityCount),
            entities: \(entities),
            componentsData: \(componentsData),
            occupancyMask: \(occupancyMask),
        )
        """
    }
}

/// A bit array for efficiently tracking occupied slots in chunks
public struct BitArray: Sendable {
    private var storage: [UInt64]
    private let size: Int

    public init(size: Int) {
        self.size = size
        let wordCount = (size + 63) / 64  // Round up to nearest multiple of 64
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
