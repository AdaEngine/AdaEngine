//
//  Chunks.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2025.
//

import AdaUtils
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import OrderedCollections

// TODO: A lot of unsafe code. What we can do? Use Span?

public struct ChunkLocation: Sendable {
    public let chunkIndex: Int
    public let entityRow: Int
}

public struct MoveEntityResult: Sendable {
    public let newLocation: ChunkLocation
    public let swappedEntity: Entity.ID?
}

/// A chunk-based storage system for ECS components
/// Provides memory-efficient, cache-friendly storage for entities and their components
public struct Chunks: Sendable {

    /// Array of chunks for different archetypes
    public internal(set) var chunks: ContiguousArray<Chunk> = []

    /// Configuration for chunk storage
    public let entitiesPerChunk: Int

    private var friedLocation: [ChunkLocation] = []
    
    /// Location entity in chunk
    public private(set) var entities: SparseSet<Entity.ID, ChunkLocation> = [:]

    let componentLayout: ComponentLayout

    public var count: Int {
        chunks.count
    }

    public init(entitiesPerChunk: Int = 250, componentLayout: ComponentLayout) {
        self.entitiesPerChunk = entitiesPerChunk
        self.componentLayout = componentLayout
        self.chunks.append(Chunk(entitiesPerChunk: entitiesPerChunk, layout: componentLayout))
    }
}

public extension Chunks {
    mutating func getFreeChunkIndex() -> Int {
        if let firstLocation = friedLocation.popLast() {
            return firstLocation.chunkIndex
        } else if let possibleIndex = chunks.firstIndex(where: { !$0.isFull }) {
            return possibleIndex
        } else {
            let chunk = Chunk(entitiesPerChunk: entitiesPerChunk, layout: componentLayout)
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
            print("Can't insert component \(T.self) for entity \(entity)")
            return
        }
        self.chunks[location.chunkIndex]
            .insert(
                component,
                at: location.chunkIndex,
                lastTick: lastTick
            )
    }

    subscript(_ index: Int) -> Chunk {
        _read { yield chunks[index] }
        _modify { yield &chunks[index] }
    }

    @discardableResult
    mutating func insertEntity(
        _ entity: Entity.ID,
        components: [any Component],
        tick: Tick
    ) -> ChunkLocation {
        let location = self.getFreeChunkIndex()
        var chunk = self.chunks[location]
        guard let entityLocation = chunk.addEntity(entity) else {
            fatalError("Failed to add entity \(entity) to chunk \(location)")
        }
        chunk.insert(at: entityLocation, components: components, tick: tick)
        let chunkLocation = ChunkLocation(
            chunkIndex: location,
            entityRow: entityLocation
        )
        self.entities[entity] = chunkLocation
        self.chunks[location] = chunk
        return chunkLocation
    }

    @discardableResult
    mutating func removeEntity(_ entity: Entity.ID) -> MoveEntityResult? {
        guard let location = self.entities[entity] else {
            return nil
        }
        var chunk = self.chunks[location.chunkIndex]
        let swappedEntity = chunk.swapRemoveEntity(at: entity)
        self.chunks[location.chunkIndex] = chunk
        self.friedLocation.append(location)
        return MoveEntityResult(newLocation: location, swappedEntity: swappedEntity)
    }

    mutating func moveEntity(_ entity: Entity.ID, to chunks: inout Chunks) -> MoveEntityResult {
        guard let location = self.entities[entity] else {
            fatalError("Entity \(entity) not found in chunks")
        }
        let oldChunk = self.chunks[location.chunkIndex]
        let newLocation = chunks.getFreeChunkIndex()
        var chunk = chunks.chunks[newLocation]
        let entityLocation = chunk.addEntity(entity)
            .unwrap(message: "Can't add entity to chunk")
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
        chunks.chunks[newLocation] = chunk
        let swappedEntity = self.swapRemoveEntity(entity)
        return MoveEntityResult(newLocation: chunkLocation, swappedEntity: swappedEntity)
    }

    @discardableResult
    private mutating func swapRemoveEntity(_ entity: Entity.ID) -> Entity.ID? {
        guard let location = self.entities[entity] else {
            return nil
        }

        var chunk = self.chunks[location.chunkIndex]
        let swappedEntityId = chunk.swapRemoveEntity(at: entity)
        self.entities.remove(for: entity)

        if let swappedEntityId = swappedEntityId {
            self.entities[swappedEntityId] = location
        }
        self.chunks[location.chunkIndex] = chunk

        return swappedEntityId
    }

    mutating func clear() {
        for index in 0..<chunks.count {
            self.chunks[index].clear()
        }
        self.entities.removeAll()
        self.friedLocation.removeAll()
    }

    func getComponentSlices<T: Component>(for type: T.Type) -> [UnsafeBufferPointer<T>] {
        var slices: [UnsafeBufferPointer<T>] = unsafe []
        for index in 0..<self.chunks.count {
            if let slice = self.chunks[index].getComponentSlice(for: type) {
                unsafe slices.append(slice)
            }
        }
        return unsafe slices
    }

    func getComponentTicksSlices<T: Component>(
        for type: T.Type
    ) -> [UnsafeBufferPointer<Tick>] {
        var slices: [UnsafeBufferPointer<Tick>] = unsafe []
        for index in 0..<self.chunks.count {
            if let slice = self.chunks[index].getComponentTicksSlice(for: type) {
                unsafe slices.append(slice)
            }
        }
        return unsafe slices
    }
}

/// A memory-efficient chunk that stores entities and their components in contiguous memory
public struct Chunk: Sendable {
    public typealias RowIndex = Int

    @safe
    public struct ComponentsData: @unchecked Sendable, CustomStringConvertible {
        var data: BlobArray
        var changesTicks: BlobArray
        let componentType: any Component.Type

        init<T: Component>(capacity: Int, component: T.Type) {
            self.data = unsafe BlobArray(count: capacity, of: T.self) { pointer, count in
                if !component.componentsInfo.isPlainOldData {
                    unsafe pointer.assumingMemoryBound(to: T.self)
                        .baseAddress?
                        .deinitialize(count: count)
                }
            }
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

    @unsafe
    public struct ComponentData<T: Component> {
        public let component: UnsafeMutablePointer<T>
        public let changeTick: Tick
    }

    /// Maximum number of entities this chunk can hold
    public let entitiesPerChunk: Int

    /// Current number of entities in this chunk
    public private(set) var count: Int = 0

    /// Entity IDs stored in this chunk
    public private(set) var entities: ContiguousArray<Entity.ID>

    /// Map from entity ID to its index in the chunk
    public private(set) var entityIndices: [Entity.ID: RowIndex]

    /// Raw component data storage (organized by component type)
    public internal(set) var componentsData: SparseSet<ComponentId, ComponentsData>

    var currentIndex: Int {
        self.count
    }

    public var isEmpty: Bool {
        self.count == 0
    }

    public var isFull: Bool {
        self.count == entitiesPerChunk
    }

    public init(entitiesPerChunk: Int, layout: ComponentLayout) {
        self.entitiesPerChunk = entitiesPerChunk
        self.entities = []
        self.entityIndices = [:]
        self.entityIndices.reserveCapacity(entitiesPerChunk)
        self.componentsData = [:]
        for component in layout.components {
            self.componentsData[component.identifier] = ComponentsData(
                capacity: entitiesPerChunk * MemoryLayout.stride(ofValue: component),
                component: component
            )
        }
    }

    /// Add an entity to this chunk
    /// - Parameter entityId: The entity identifier to add
    /// - Returns: The index where the entity was placed, or nil if chunk is full
    mutating func addEntity(_ entityId: Entity.ID) -> RowIndex? {
        if count >= entitiesPerChunk {
            assertionFailure("Chunk is full, cannot add entity \(entityId), self \(self.description)")
            return nil
        }

        if currentIndex < self.entities.count {
            self.entities[currentIndex] = entityId
        } else {
            self.entities.append(entityId)
        }

        let index = currentIndex
        entityIndices[entityId] = index
        count += 1

        return index
    }

    /// Remove an entity from this chunk
    /// - Parameter index: The index of the entity to remove
    mutating func removeEntity(at entityId: Entity.ID) {
        self.swapRemoveEntity(at: entityId)
    }

    mutating func clear() {
        self.componentsData.forEach { data in
            data.data.clear(entities.count)
            data.changesTicks.clear(entities.count)
        }
        self.entities.removeAll(keepingCapacity: true)
        self.entityIndices.removeAll(keepingCapacity: true)
        self.count = 0
    }

    /// Removes an entity from the chunk by swapping it with the last element.
    /// - Parameter entityId: The ID of the entity to remove.
    /// - Returns: The ID of the entity that was swapped into the removed entity's place, if any.
    @discardableResult
    mutating func swapRemoveEntity(at entityId: Entity.ID) -> Entity.ID? {
        guard let removedIndex = self.entityIndices.removeValue(forKey: entityId) else {
            return nil
        }

        count -= 1
        let lastIndex = count

        if removedIndex < lastIndex {
            // Move component data from the last element to the removed element's slot
            for componentData in self.componentsData {
                componentData.data
                    .swap(from: lastIndex, to: removedIndex)
                componentData.changesTicks
                    .swap(from: lastIndex, to: removedIndex)
            }

            // Update the entity that was in the last slot
            let swappedEntityId = self.entities[lastIndex]
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

    func insert(at entityIndex: RowIndex, components: [any Component], tick: Tick) {
        for component in components {
            let componentId = type(of: component).identifier
            guard let array = componentsData[componentId] else {
                fatalError("Passed not registred component")
            }
            array.data.insert(component, at: entityIndex)
            array.changesTicks.insert(tick, at: entityIndex)
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
    public func getAllComponentData() -> SparseSet<ComponentId, ComponentsData> {
        return componentsData
    }

    public func getComponents(for entity: Entity.ID) -> [(ComponentId, any Component)] {
        guard let index = self.entityIndices[entity] else {
            return []
        }
        return componentsData.values.map { (key, data) in
            (key, data.data.get(at: index, as: data.componentType))
        }
    }

    public func getComponentSlice<T: Component>(for type: T.Type) -> UnsafeBufferPointer<T>? {
        guard let componentData = self.componentsData[T.identifier], self.count > 0 else {
            return nil
        }
        let startPointer = componentData.data.getMutablePointer(at: 0, as: T.self)
        return unsafe UnsafeBufferPointer(start: startPointer, count: self.count)
    }

    public func getMutableComponentSlice<T: Component>(for type: T.Type) -> UnsafeMutablePointer<T>? {
        guard let componentData = self.componentsData[T.identifier], self.count > 0 else {
            return nil
        }
        return componentData.data.getMutablePointer(at: 0, as: T.self)
    }

    public func getComponentTicksSlice<T: Component>(for type: T.Type) -> UnsafeBufferPointer<Tick>? {
        guard let componentData = self.componentsData[T.identifier], self.count > 0 else {
            return nil
        }
        let startPointer = componentData.changesTicks.getMutablePointer(at: 0, as: Tick.self)
        return unsafe UnsafeBufferPointer(start: startPointer, count: self.count)
    }

    public func getMutableComponentTicksSlice<T: Component>(for type: T.Type) -> UnsafeMutablePointer<Tick>? {
        guard let componentData = self.componentsData[T.identifier], self.count > 0 else {
            return nil
        }
        return componentData.changesTicks.getMutablePointer(at: 0, as: Tick.self)
    }
}

extension Chunk: NonCopybaleCustomStringConvertible {
    public var description: String {
        return """
        Chunk(
            entitiesPerChunk: \(entitiesPerChunk),
            count: \(count),
            entities: \(entities.map(\.description)),
            entityIndices: \(entityIndices),
            componentsData:
                \(componentsData.map { $0.description }.joined(separator: "\n"))
        )
        """
    }
}
