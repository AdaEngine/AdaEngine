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

public struct MoveEntityResult {
    public let newLocation: ChunkLocation
    public let swappedEntity: Entity.ID?
}

/// A chunk-based storage system for ECS components
/// Provides memory-efficient, cache-friendly storage for entities and their components
public struct Chunks: @unchecked Sendable {

    /// Array of chunks for different archetypes
    public internal(set) var chunks: [Chunk] = []

    /// Configuration for chunk storage
    public let chunkSize: Int

    private var friedLocation: [ChunkLocation] = []
    
    /// Location entity in chunk
    public private(set) var entities: [Entity.ID: ChunkLocation] = [:]

    let componentLayout: ComponentLayout

    public init(chunkSize: Int = Int(UInt16.max), componentLayout: ComponentLayout) {
        self.chunkSize = chunkSize
        self.componentLayout = componentLayout
        self.chunks.append(Chunk(capacity: chunkSize, layout: componentLayout))
    }

    mutating func getFreeChunkIndex() -> Int {
        if let firstLocation = friedLocation.popLast() {
            return firstLocation.chunkIndex
        } else if self.chunks[self.chunks.endIndex - 1].isFull == false {
            return max(0, self.chunks.endIndex - 1)
        } else {
            let chunk = Chunk(capacity: self.chunkSize, layout: componentLayout)
            self.chunks.append(chunk)
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
        self.chunks[location.chunkIndex]
            .insert(
                component,
                at: location.chunkIndex,
                lastTick: lastTick
            )
    }

    @discardableResult
    mutating func insertEntity(
        _ entity: Entity.ID,
        components: [any Component]
    ) -> ChunkLocation {
        let location = self.getFreeChunkIndex()
        let chunk = self.chunks[location]
        guard let entityLocation = chunk.addEntity(entity) else {
            fatalError("Failed to add entity \(entity) to chunk \(location)")
        }
        chunk.insert(at: entityLocation, components: components)
        let chunkLocation = ChunkLocation(
            chunkIndex: location,
            entityRow: entityLocation
        )
        self.entities[entity] = chunkLocation
        return chunkLocation
    }

    mutating func removeEntity(_ entity: Entity.ID) {
        guard let location = self.entities[entity] else {
            return
        }
        let chunk = self.chunks[location.chunkIndex]
        chunk.removeEntity(at: entity)
        if chunk.entityCount == 0, self.chunks.count > 1 {
            self.chunks[location.chunkIndex] = Chunk(capacity: self.chunkSize, layout: componentLayout)
            return
        }
        self.friedLocation.append(location)
    }

    mutating func moveEntity(_ entity: Entity.ID, to chunks: inout Chunks) -> MoveEntityResult {
        guard let location = self.entities[entity] else {
            fatalError("Entity \(entity) not found in chunks")
        }
        let oldChunk = self.chunks[location.chunkIndex]
        let newLocation = chunks.getFreeChunkIndex()
        let chunk = chunks.chunks[newLocation]
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
        chunks.entities[entity] = chunkLocation
        let swappedEntity = self.swapRemoveEntity(entity)
        return MoveEntityResult(newLocation: chunkLocation, swappedEntity: swappedEntity)
    }

    @discardableResult
    mutating func swapRemoveEntity(_ entity: Entity.ID) -> Entity.ID? {
        guard let location = self.entities[entity] else {
            return nil
        }

        let chunk = self.chunks[location.chunkIndex]
        let swappedEntityId = chunk.swapRemoveEntity(at: entity)
        self.entities.removeValue(forKey: entity)

        if let swappedEntityId = swappedEntityId {
            self.entities[swappedEntityId] = location
        }

        if chunk.entityCount == 0, self.chunks.count > 1 {
            self.chunks[location.chunkIndex] = Chunk(capacity: chunkSize, layout: componentLayout)
        }

        return swappedEntityId
    }

    mutating func clear() {
        self.chunks = .init()
        self.entities.removeAll()
        self.friedLocation.removeAll()

        // We should have at least one chunk.
        self.chunks.append(Chunk(capacity: self.chunkSize, layout: self.componentLayout))
    }

    public func getComponentSlices<T: Component>(for type: T.Type) -> [UnsafeBufferPointer<T>] {
        var slices: [UnsafeBufferPointer<T>] = []
        for index in 0..<self.chunks.count {
            if let slice = self.chunks[index].getComponentSlice(for: type) {
                slices.append(slice)
            }
        }
        return slices
    }

    public func getComponentTicksSlices<T: Component>(
        for type: T.Type
    ) -> [UnsafeBufferPointer<Tick>] {
        var slices: [UnsafeBufferPointer<Tick>] = []
        for index in 0..<self.chunks.count {
            if let slice = self.chunks[index].getComponentTicksSlice(for: type) {
                slices.append(slice)
            }
        }
        return slices
    }
}

/// A memory-efficient chunk that stores entities and their components in contiguous memory
public final class Chunk {

    public typealias RowIndex = Int

    public struct ComponentsData: @unchecked Sendable, CustomStringConvertible {
        var data: BlobArray
        var changesTicks: BlobArray
        let componentType: any Component.Type

        init<T: Component>(capacity: Int, component: T.Type) {
            self.data = BlobArray(count: capacity, of: T.self)
            self.changesTicks = BlobArray(count: capacity, of: Tick.self)
            self.componentType = component
        }

        public var description: String {
            return """
            ComponentsData(
                data: \(data.count),
                changesTicks: \(changesTicks.count),
                componentType: \(componentType)
            )
            """
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
    public private(set) var entities: SparseArray<Entity.ID>

    /// Map from entity ID to its index in the chunk
    public private(set) var entityIndices: [Entity.ID: RowIndex]

    /// Raw component data storage (organized by component type)
    public internal(set) var componentsData: [ComponentId: ComponentsData]

    /// Bitmask indicating which entity slots are occupied
    private var occupancyMask: BitArray

    /// Free entity indices that can be reused
    private var freeIndices: [RowIndex] = []

    public var isFull: Bool {
        self.entityCount == capacity
    }

    public init(capacity: Int, layout: ComponentLayout) {
        print("New chunk", layout.components, capacity)
        self.capacity = capacity
        self.entities = .init(capacity: capacity)
        self.entityIndices = [:]
        self.entityIndices.reserveCapacity(capacity)
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
    func addEntity(_ entityId: Entity.ID) -> RowIndex? {
        if entityCount >= capacity {
            print("Chuink is full, cannot add entity \(entityId), self \(self.description)")
            return nil
        }

        let index: RowIndex
        if let freeIndex = freeIndices.popLast() {
            index = freeIndex
        } else {
            index = entityCount
        }

        if index < self.entities.count {
            self.entities[index] = entityId
        } else {
            self.entities.append(entityId)
        }

        entityIndices[entityId] = index
        occupancyMask.set(index, to: true)
        entityCount += 1

        return index
    }

    /// Remove an entity from this chunk
    /// - Parameter index: The index of the entity to remove
    func removeEntity(at entityId: Entity.ID) {
        guard let index = self.entityIndices[entityId] else {
            print("Failed to remove, entities not found")
            return
        }
        guard index < capacity && occupancyMask.get(index) else {
            print("Failed to remove, not exists in occupance mask")
            return
        }
        entityIndices.removeValue(forKey: entityId)
        entities.remove(at: index)
        occupancyMask.set(index, to: false)
        entityCount -= 1
        freeIndices.append(index)
    }

    func clear() {
        self.entities.removeAll(keepingCapacity: true)
        self.entityIndices.removeAll(keepingCapacity: true)
        self.entityCount = 0
        self.freeIndices.removeAll(keepingCapacity: true)
        self.occupancyMask = BitArray(size: self.capacity)
    }

    /// Removes an entity from the chunk by swapping it with the last element.
    /// - Parameter entityId: The ID of the entity to remove.
    /// - Returns: The ID of the entity that was swapped into the removed entity's place, if any.
    @discardableResult
    func swapRemoveEntity(at entityId: Entity.ID) -> Entity.ID? {
        guard let removedIndex = self.entityIndices.removeValue(forKey: entityId) else {
            return nil
        }

        entityCount -= 1
        let lastIndex = entityCount

        if removedIndex < lastIndex {
            // Move component data from the last element to the removed element's slot
            for componentData in self.componentsData.values {
                let component = componentData.data.get(at: lastIndex, as: componentData.componentType)
                componentData.data.insert(component, at: removedIndex)

                let tick = componentData.changesTicks.get(at: lastIndex, as: Tick.self)
                componentData.changesTicks.insert(tick, at: removedIndex)
            }

            // Update the entity that was in the last slot
            guard let swappedEntityId = self.entities[lastIndex] else {
                return nil // TODO: Is it correct?
            }
            self.entities[removedIndex] = swappedEntityId
            self.entityIndices[swappedEntityId] = removedIndex
            self.entities.removeLast()

            return swappedEntityId
        } else {
            // The removed entity was the last one, so no swap is needed
            self.entities.removeLast()
            return nil
        }
    }

    func insert(at entityIndex: RowIndex, components: [any Component]) {
        for component in components {
            let componentId = type(of: component).identifier
            guard let array = componentsData[componentId] else {
                fatalError()
            }
            array.data.insert(component, at: entityIndex)
        }
    }

    @inline(__always)
    public func get<T: Component>(at entityIndex: RowIndex) -> T? {
        return self.componentsData[T.identifier]?.data.get(at: entityIndex, as: T.self)
    }

    public func isComponentChanged<T: Component>(
        _ type: T.Type,
        for entity: Entity.ID,
        lastTick: Tick
    ) -> Bool {
        guard let entityIndex = self.entityIndices[entity] else {
            return false
        }
        guard
            let lastChangeTick = self.componentsData[T.identifier]?
                .changesTicks
                .get(at: entityIndex, as: Tick.self)
        else {
            return false
        }

        return lastChangeTick >= lastTick
    }

    @inline(__always)
    public func get<T: Component>(_ type: T.Type, for entity: Entity.ID) -> T? {
        guard let index = self.entityIndices[entity] else {
            return nil
        }
        return self.componentsData[T.identifier]?
            .data
            .get(at: index, as: T.self)
    }

    @inline(__always)
    public func getMutablePointer<T: Component>(
        _ type: T.Type,
        for entity: Entity.ID
    ) -> UnsafeMutablePointer<T>? {
        guard let index = self.entityIndices[entity] else {
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
        guard let index = self.entityIndices[entity] else {
            return nil
        }
        return self.componentsData[T.identifier]?
            .changesTicks
            .getMutablePointer(at: index, as: Tick.self)
    }
    
    public func insert<T: Component>(
        _ component: consuming T,
        at entityIndex: RowIndex,
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

    public func getComponents(for entity: Entity.ID) -> [ComponentId: any Component] {
        guard let index = self.entityIndices[entity] else {
            return [:]
        }
        return componentsData.mapValues { data in
            data.data.get(at: index, as: data.componentType)
        }
    }

    public func getComponentSlice<T: Component>(for type: T.Type) -> UnsafeBufferPointer<T>? {
        guard let componentData = self.componentsData[T.identifier], self.entityCount > 0 else {
            return nil
        }
        let startPointer = componentData.data.getMutablePointer(at: 0, as: T.self)
        return UnsafeBufferPointer(start: startPointer, count: self.entityCount)
    }

    public func getComponentTicksSlice<T: Component>(for type: T.Type) -> UnsafeBufferPointer<Tick>? {
        guard let componentData = self.componentsData[T.identifier], self.entityCount > 0 else {
            return nil
        }
        let startPointer = componentData.changesTicks.getMutablePointer(at: 0, as: Tick.self)
        return UnsafeBufferPointer(start: startPointer, count: self.entityCount)
    }

    /// Check if an entity slot is occupied
    /// - Parameter index: The entity index to check
    /// - Returns: true if the slot is occupied
    public func isOccupied(at index: RowIndex) -> Bool {
        return index < capacity && occupancyMask.get(index)
    }

    /// Get array of occupied entity indices for efficient iteration
    /// - Returns: Array of indices that contain entities
    public func getOccupiedIndices() -> [RowIndex] {
        return (0..<capacity).filter { occupancyMask.get($0) }
    }

    /// Get array of occupied entity indices for efficient iteration
    /// - Returns: Array of indices that contain entities
    public func getFreeIndex() -> RowIndex? {
        return (0..<capacity).firstIndex { !occupancyMask.get($0) }
    }
}

extension Chunk: NonCopybaleCustomStringConvertible {
    public var description: String {
        return """
        Chunk(
            capacity: \(capacity),
            entityCount: \(entityCount),
            entities: \(entities.map(\.description)),
            entityIndices: \(entityIndices),
            componentsData:
                \(componentsData.map { $0.value.description }.joined(separator: "\n")),
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
