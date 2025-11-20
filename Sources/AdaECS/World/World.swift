//
//  World.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/26/22.
//

import AdaUtils
import Collections
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Atomics

public struct ChangeDetectionTick {
    public var change: Tick?
    public let lastTick: Tick
    public let currentTick: Tick

    public init(change: Tick?, lastTick: Tick, currentTick: Tick) {
        self.change = change
        self.lastTick = lastTick
        self.currentTick = currentTick
    }
}

public struct Tick: Sendable, Comparable {
    public let value: Int

    public init(value: Int) {
        self.value = value
    }

    public static func < (lhs: Tick, rhs: Tick) -> Bool {
        lhs.value < rhs.value
    }
}

/// Stores and exposes operations on ``Entity`` and ``Component``.
///
/// Each ``Entity`` has a set of components. Each component can have up to one instance of each
/// component type. Entity components can be created, updated, removed, and queried using a given World.
/// - Warning: Still work in progress.
public final class World: @unchecked Sendable, Codable {

    /// The unique identifier of the world.
    public typealias ID = RID

    /// The unique identifier of the world.
    public let id = ID()
    public let name: String?

    public private(set) var changeTick = ManagedAtomic<Int>(1)
    public private(set) var lastTick: Tick = Tick(value: 0)

    /// The archetypes of the world.
    public private(set) var entities: Entities = Entities()
    public private(set) var archetypes: Archetypes = Archetypes()

    /// The removed entities of the world.
    internal private(set) var removedEntities: Set<Entity.ID> = []
    /// The added entities of the world.
    internal private(set) var addedEntities: Set<Entity.ID> = []
    /// The updated entities of the world.
    private var removedComponents: [Entity.ID: Set<ComponentId>] = [:]

    private var componentsStorage = ComponentsStorage()
    public var commandQueue: WorldCommandQueue = WorldCommandQueue()

    public private(set) var eventManager: EventManager = EventManager.default

    // Scheduler registry and mapping from scheduler to systems
    public let schedulers = Schedulers(SchedulerName.default)

    // MARK: - Methods

    public init(name: String? = nil) {
        self.name = name
    }

    private init(from world: borrowing World) {
        self.name = world.name
        self.archetypes = world.archetypes
        self.entities = world.entities
        self.componentsStorage = world.componentsStorage
    }

    /// Initialize a new world from a decoder.
    /// - Parameter decoder: The decoder to initialize the world from.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        let entities = try container.decode([Entity].self, forKey: .entities)

        for entity in entities {
            self.addEntity(entity)
        }

        let resourcesContainer = try container.nestedContainer(keyedBy: CodingName.self, forKey: .resources)
        for resourceKey in resourcesContainer.allKeys {
            guard let resourceType = ResourceStorage.getRegisteredResource(for: resourceKey.stringValue) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .resources,
                    in: container,
                    debugDescription: "Resource \(resourceKey) not found"
                )
            }

            if let decodable = resourceType as? Decodable.Type {
                let resource = try decodable.init(from: resourcesContainer.superDecoder(forKey: resourceKey))
                self.insertTypeErasedResource(resource as! Resource)
            }
        }

        self.flush()
    }

    /// Encode the world to an encoder.
    /// - Parameter encoder: The encoder to encode the world to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let entities = self.getEntities().sorted(by: {
            $0.id < $1.id
        })
        try container.encode(entities, forKey: .entities)
        var unkeyedContainer = container.nestedContainer(keyedBy: CodingName.self, forKey: .resources)
        for resource in self.componentsStorage.resourceComponents.values {
            try unkeyedContainer.encode(AnyEncodable(resource), forKey: CodingName(stringValue: type(of: resource).swiftName))
        }
    }

    public func copy() -> World {
        World(from: self)
    }
}

// MARK: - Scheduler API

public extension World {

    /// Set the order of schedulers for this world.
    /// - Parameter schedulers: The schedulers to set.
    func setSchedulers(_ schedulers: [SchedulerName]) {
        self.schedulers.setSchedulers(schedulers)
    }

    /// Insert a scheduler before or after another scheduler.
    /// - Parameter scheduler: The scheduler to insert.
    /// - Parameter after: The scheduler after which to insert the new scheduler.
    func insertScheduler(_ scheduler: Scheduler, after: SchedulerName) {
        schedulers.insert(scheduler, after: after)
    }

    /// Insert a scheduler before or before another scheduler.
    /// - Parameter scheduler: The scheduler to insert.
    /// - Parameter before: The scheduler before which to insert the new scheduler.
    func insertScheduler(_ scheduler: Scheduler, before: SchedulerName) {
        schedulers.insert(scheduler, before: before)
    }

    /// Contains scheduler
    /// - Parameter scheduler: The scheduler to check.
    /// - Returns: True if the scheduler exists, otherwise false.
    func containsScheduler(_ scheduler: SchedulerName) -> Bool {
        self.schedulers.contains(scheduler)
    }

    /// Add schedulers.
    /// - Parameter schedulers: The schedulers to add.
    func addSchedulers(_ schedulers: SchedulerName...) {
        schedulers.forEach {
            self.schedulers.append(Scheduler(name: $0))
        }
    }

    /// Add scheduler
    /// - Parameter scheduler: The scheduler to add.
    func addScheduler(_ scheduler: Scheduler) {
        self.schedulers.append(scheduler)
    }

    /// Run a specific scheduler.
    /// - Parameter scheduler: Scheduler name.
    /// - Parameter deltaTime: Time interval since last update.
    func runScheduler(_ schedulerName: SchedulerName) async {
        guard let scheduler = self.schedulers.getScheduler(schedulerName) else {
            fatalError("Scheduler \(schedulerName) not found")
        }
        await scheduler.run(world: self)
    }
}

// MARK: - Systems API

public extension World {
    /// Add new system to the world.
    /// - Parameter systemType: System type.
    /// Add a system to a specific scheduler.
    @discardableResult
    func addSystem<T: System>(_ systemType: T.Type, on scheduler: SchedulerName) -> Self {
        self.schedulers.addSystem(
            systemType.init(world: self),
            for: scheduler
        )
        return self
    }

    /// Add new system to the world for `update` scheduler.
    /// - Parameter systemType: System type.
    /// - Returns: A world instance.
    @discardableResult
    func addSystem<T: System>(_ systemType: T.Type) -> Self {
        return addSystem(systemType, on: .update)
    }
}

// MARK: - Entities managment

public extension World {
    /// Get all entities in world.
    /// - Complexity: O(n)
    /// - Returns: All entities in world.
    func getEntities() -> [Entity] {
        return self.entities.entities
            .compactMap { location in
                let archetype = self.archetypes.archetypes[location.archetypeId]
                return archetype.entities[location.archetypeRow]
            }
    }

    /// Get an entity by their id.
    /// - Parameter id: Entity identifier.
    /// - Complexity: O(1)
    /// - Returns: Returns nil if entity not registed in scene world.
    func getEntityByID(_ entityID: Entity.ID) -> Entity? {
        guard let location = self.entities.entities[entityID] else {
            return nil
        }

        return self.archetypes
            .archetypes[location.archetypeId]
            .entities[location.archetypeRow]
    }

    /// Find an entity by name.
    /// - Note: Not efficient way to find an entity.
    /// - Complexity: O(n)
    /// - Returns: An entity with matched name or nil if entity with given name not exists.
    func getEntityByName(_ name: String) -> Entity? {
        for arch in archetypes.archetypes {
            if let ent = arch.entities.first(where: { $0.name == name }) {
                return ent
            }
        }

        return nil
    }

    /// Add a new entity to the world.
    /// - Parameter entity: The entity to add.
    /// - Returns: A world instance.
    @discardableResult
    func addEntity(_ entity: consuming Entity) -> Self {
        self.flush()

        if entity.id != Entity.notAllocatedId {
            entities.addNotAllocatedEntity(entity)
        }

        insertNewEntity(
            entity,
            components: Array(entity.components.notFlushedComponents)
        )
        return self
    }

    /// Remove entity from world.
    /// - Parameter recursively: also remove entity child.
    /// - Returns: A world instance.
    @discardableResult
    func removeEntity(_ entity: borrowing Entity, recursively: Bool = false) -> Self {
        self.removeEntityRecord(entity.id)

        guard recursively && !entity.children.isEmpty else {
            return self
        }

        for child in entity.children {
            self.removeEntity(child, recursively: recursively)
        }

        return self
    }

    /// Remove entity from world.
    /// - Note: Entity will removed on next `update` call.
    /// - Parameter recursively: also remove entity child.
    func removeEntityOnNextTick(_ entity: consuming Entity, recursively: Bool = false) {
        guard self.entities.entities[entity.id] != nil else {
            return
        }

        let entity = entity
        defer { eventManager.send(WorldEvents.WillRemoveEntity(entity: entity), source: self) }
        self.removedEntities.insert(entity.id)

        guard recursively && !entity.children.isEmpty else {
            return
        }

        for child in entity.children {
            self.removeEntityOnNextTick(child, recursively: recursively)
        }
    }

    /// Check if component was changed for entity.
    /// - Parameter component: Component identifier.
    /// - Parameter entity: Entity.
    /// - Complexity: O(1)
    /// - Returns: True if component was changed for entity, otherwise false.
    func isComponentChanged<T: Component>(_ component: T.Type, for entity: Entity.ID) -> Bool {
        guard let location = self.entities.entities[entity] else {
            return false
        }
        return self.archetypes
            .archetypes[location.archetypeId]
            .chunks
            .chunks[location.chunkIndex]
            .isComponentChanged(T.self, for: entity, lastTick: self.lastTick)
    }
}

// MARK: - World utils

public extension World {
    func makeCommands() -> Commands {
        Commands(entities: entities, commandsQueue: self.commandQueue.copy())
    }

    func flushCommands() {
        guard !commandQueue.isEmpty else {
            return
        }
        self.commandQueue.apply(to: self)
    }

    /// Update all data in world.
    /// In this step we move entities to matched archetypes and remove pending in delition entities.
    func flush() {
        self.flushCommands()

        for entityId in self.removedEntities {
            self.removeEntityRecord(entityId)
        }
    }

    /// Clear trackers for entities, components and resources.
    /// - Complexity: O(1)
    func clearTrackers() {
        self.removedEntities.removeAll(keepingCapacity: true)
        self.addedEntities.removeAll(keepingCapacity: true)
        self.lastTick = self.incrementChangeTick()
    }

    /// Remove all data from world exclude resources.
    /// - Complexity: O(n)
    func clear() {
        self.entities.clear()
        self.archetypes.clear()
        self.removedEntities.removeAll(keepingCapacity: true)
        self.addedEntities.removeAll(keepingCapacity: true)
        self.commandQueue = WorldCommandQueue()
    }

    func incrementChangeTick() -> Tick {
        let lastValue = self.changeTick.loadThenWrappingIncrement(
            ordering: .relaxed
        )
        return Tick(value: lastValue)
    }
}

// MARK: - Resource API

public extension World {
    /// Insert a resource into the world.
    /// - Parameter resource: The resource to insert.
    /// - Returns: A world instance.
    @discardableResult
    func insertResource<T: Resource>(_ resource: consuming T) -> Self {
        let componentId = self.componentsStorage.getOrRegisterResource(T.self)
        self.componentsStorage.resourceComponents[componentId] = resource
        return self
    }

    /// Insert a resource into the world.
    /// - Parameter resource: The resource to insert.
    /// - Returns: A world instance.
    @discardableResult
    private func insertTypeErasedResource(_ resource: consuming any Resource) -> Self {
        let resource = resource
        let componentId = self.componentsStorage.getOrRegisterResource(type(of: resource))
        self.componentsStorage.resourceComponents[componentId] = resource
        return self
    }

    func createResource<T: Resource & WorldInitable>(of type: T.Type) -> T {
        let resource = type.init(from: self)
        let componentId = self.componentsStorage.getOrRegisterResource(T.self)
        self.componentsStorage.resourceComponents[componentId] = resource
        return resource
    }

    /// Remove a resource from the world.
    /// - Parameter resource: The resource to remove.
    consuming func removeResource<T: Resource>(_ resource: T.Type) {
        self.componentsStorage.removeResource(resource)
    }

    /// Get a resource from the world.
    /// - Parameter resource: The resource to get.
    /// - Complexity: O(1)
    /// - Returns: The resource if it exists, otherwise nil.
    borrowing func getResource<T: Resource>(_ resource: T.Type) -> T? {
        return self.componentsStorage.getResource(resource)
    }

    /// Get a resource from the world or initialize it if it doesn't exist.
    /// - Parameter type: The type of the resource to get or initialize.
    /// - Complexity: O(1)
    /// - Returns: The resource if it exists, otherwise the initialized resource.
    func getOrInitResource<T: Resource & WorldInitable>(of type: T.Type) -> T {
        if let resource = self.componentsStorage.getResource(T.self) {
            return resource
        }
        let resource = type.init(from: self)
        let componentId = self.componentsStorage.getOrRegisterResource(T.self)
        self.componentsStorage.resourceComponents[componentId] = resource
        return resource
    }

    /// Get a resource from the world.
    /// - Parameter resource: The resource to get.
    /// - Complexity: O(1)
    /// - Returns: The resource if it exists, otherwise nil.
    func getMutableResource<T: Resource>(_ resource: T.Type) -> Mutable<T?> {
        return Mutable { [unowned self] in
            self.getResource(resource)
        } set: { [unowned self] newValue in
            if let newValue {
                let componentId = self.componentsStorage.getOrRegisterResource(T.self)
                self.componentsStorage.resourceComponents[componentId] = newValue
            } else {
                self.removeResource(T.self)
            }
        }
    }
    
    /// Get all resources from the world.
    /// - Returns: All resources in world.
    func getResources() -> [any Resource] {
        return Array(self.componentsStorage.resourceComponents.values)
    }

    /// Clear all resources from the world.
    /// - Complexity: O(1)
    func clearResources() {
        self.componentsStorage.resourceComponents.removeAll(keepingCapacity: true)
    }
}

// MARK: - Entities and Components

public extension World {
    @discardableResult
    func spawn(
        _ name: String = "",
        @ComponentsBuilder components: () -> ComponentsBundle
    ) -> Entity {
        self.spawn(name, bundle: components())
    }

    @discardableResult
    func spawn<T: ComponentsBundle>(
        _ name: String = "",
        bundle: consuming T
    ) -> Entity {
        let entity = entities.allocate(with: name)
        insertNewEntity(entity, components: bundle.components)
        return entity
    }

    @discardableResult
    @inline(__always)
    func spawn(_ name: String = "") -> Entity {
        let entity = entities.allocate(with: name)
        insertNewEntity(entity, components: [])
        return entity
    }

    func get<T: Component>(from entity: Entity.ID) -> T? {
        guard let location = self.entities.entities[entity] else {
            return nil
        }
        return self.archetypes
            .archetypes[location.archetypeId]
            .chunks
            .chunks[location.chunkIndex]
            .get(at: location.chunkRow)
    }

    @inline(__always)
    func get<T: Component>(_ type: T.Type, from entity: Entity.ID) -> T? {
        return self.get(from: entity)
    }

    func insert<T: Component>(_ component: consuming T, for entityId: Entity.ID) {
        guard let location = self.entities.entities[entityId] else {
            return
        }

        // We have component in archetype, just update
        var archetype = self.archetypes.archetypes[location.archetypeId]
        if archetype.componentLayout.bitSet.contains(T.identifier) {
            self.archetypes
                .archetypes[location.archetypeId]
                .chunks
                .chunks[location.chunkIndex]
                .insert(component, at: location.chunkRow, lastTick: lastTick)
            return
        }

        // Prepare new layout
        var newLayout = archetype.componentLayout
        newLayout.insert(T.self)

        var components: [any Component] = []
        for requiredComponent in componentsStorage.getRequiredComponents(for: T.self) {
            let newComponent = requiredComponent.constructor()
            components.append(newComponent)
            newLayout.insert(type(of: newComponent))
        }

        // Move entity to new archetype
        if let newArchetype = archetype.edges.getArchetypeAfterInsertion(for: newLayout) {
            self.moveEntityToArchetype(
                entityId,
                oldLocation: location,
                newArchetype: newArchetype
            )
        } else {
            let newArchetype = self.archetypes.getOrCreate(for: newLayout)
            archetype.edges.addArchetypeAfterInsertion(newArchetype, for: newLayout)
            self.archetypes.archetypes[location.archetypeId] = archetype
            self.moveEntityToArchetype(
                entityId,
                oldLocation: location,
                newArchetype: newArchetype
            )
        }

        // Insert components
        guard let newLocation = self.entities.entities[entityId] else {
            assertionFailure("Failed to insert component to entity")
            return
        }

        for component in components {
            self.archetypes
                .archetypes[newLocation.archetypeId]
                .chunks
                .insert(component, for: entityId, lastTick: lastTick)
        }

        self.archetypes
            .archetypes[newLocation.archetypeId]
            .chunks
            .insert(component, for: entityId, lastTick: lastTick)
    }

    @inline(__always)
    func remove<T: Component>(_ component: consuming T, for entity: Entity.ID) {
        self.remove(T.identifier, from: entity)
    }

    /// Remove a component of the specified type from an entity.
    /// - Parameter componentType: The type of component to remove.
    /// - Parameter entity: The entity ID to remove the component from.
    @inline(__always)
    func remove<T: Component>(_ componentType: T.Type, from entityId: Entity.ID) {
        guard let location = entities.entities[entityId] else {
            return
        }
        let entity = self.archetypes.archetypes[location.archetypeId].entities[location.archetypeRow]
        eventManager.send(ComponentEvents.WillRemove(componentType: T.self, entity: entity))
        self.remove(T.identifier, from: entityId)
    }

    func remove(_ componentId: ComponentId, from entityId: Entity.ID) {
        // Get the entity's current location
        guard let location = self.entities.entities[entityId] else {
            return // Entity doesn't exist in the world
        }

        // Get the entity from the archetype
        var archetype = self.archetypes.archetypes[location.archetypeId]
        var newLayout = archetype.chunks.componentLayout
        newLayout.remove(componentId)
        if let newArchetype = archetype.edges.getArchetypeAfterRemoval(for: newLayout) {
            self.moveEntityToArchetype(
                entityId,
                oldLocation: location,
                newArchetype: newArchetype
            )
        } else {
            let newArchetype = self.archetypes.getOrCreate(for: newLayout)
            archetype.edges.addArchetypeAfterRemoval(newArchetype, for: newLayout)
            self.archetypes.archetypes[location.archetypeId] = archetype
            self.moveEntityToArchetype(
                entityId,
                oldLocation: location,
                newArchetype: newArchetype
            )
        }
        self.removedComponents[entityId, default: []].insert(componentId)
    }

    @inline(__always)
    @discardableResult
    func registerRequiredComponent<T: Component, R: Component & DefaultValue>(
        _ component: T.Type,
        _ requiredComponent: R.Type
    ) -> Self {
        self.registerRequiredComponent(component, requiredComponent, { R.defaultValue })
    }

    @discardableResult
    func registerRequiredComponent<T: Component, R: Component>(
        _ component: T.Type,
        _ requiredComponent: R.Type,
        _ requiredComponentConstructor: @Sendable @escaping () -> R
    ) -> Self {
        let componentId = self.componentsStorage.getOrRegisterComponent(component)
        let requiredComponentId = self.componentsStorage.getOrRegisterComponent(requiredComponent)
        self.componentsStorage.registerRequiredComponent(
            for: componentId,
            requiredComponentId: requiredComponentId,
            constructor: requiredComponentConstructor
        )

        return self
    }

    @inline(__always)
    func has<T: Component>(_ type: T.Type, in entity: Entity.ID) -> Bool {
        self.has(T.identifier, in: entity)
    }

    func has(_ identifier: ComponentId, in entity: Entity.ID) -> Bool {
        guard let location = self.entities.entities[entity] else {
            return false
        }

        return self.archetypes
            .archetypes[location.archetypeId]
            .componentLayout
            .bitSet
            .contains(identifier)
    }
}

// MARK: - Queries

extension World {
    /// Returns all entities of the scene which pass the ``QueryPredicate`` of the query.
    public func performQuery(_ query: EntityQuery) -> EntityQuery.Result {
        let state = query.state
        state.updateArchetypes(in: self)
        return QueryResult(state: state)
    }

    /// Returns all components of the scene which pass the ``FilterQuery``.
    public func performQuery<each T: QueryTarget, F: Filter>(
        _ query: FilterQuery<repeat (each T), F>
    ) -> QueryResult<FilterQuery<repeat (each T), F>.Builder, F> {
        let state = query.state
        state.updateArchetypes(in: self)
        return QueryResult(state: state)
    }
}

extension World: EventSource {
    /// Subscribe to an event.
    /// - Parameter event: The event to subscribe to.
    /// - Parameter eventSource: The event source to subscribe to.
    /// - Parameter completion: The completion handler to call when the event is triggered.
    /// - Returns: A cancellable object that can be used to unsubscribe from the event.
    public func subscribe<E: Event>(
        to event: E.Type,
        on eventSource: EventSource?,
        completion: @escaping @Sendable (E) -> Void
    ) -> Cancellable {
        self.eventManager.subscribe(to: event, on: eventSource, completion: completion)
    }
}

extension World {
    /// Insert entity to the world. Expect, that entity is already stored in `Entities`.
    func insertNewEntity(_ entity: Entity, components: [any Component]) {
        let components: [any Component] = components.reduce(into: []) { partialResult, component in
            for requiredComponent in componentsStorage.getRequiredComponents(for: component) {
                partialResult.append(requiredComponent.constructor())
            }
            partialResult.append(component)
        }
        let componentsLayout = ComponentLayout(components: components)
        let archetypeIndex = self.archetypes.getOrCreate(
            for: componentsLayout
        )

        var archetype = self.archetypes.archetypes[archetypeIndex]
        let row = archetype.append(entity)
        let chunkLocation = archetype.chunks.insertEntity(entity.id, components: components)
        self.archetypes.archetypes[archetypeIndex] = archetype
        self.entities.entities[entity.id] = EntityLocation(
            archetypeId: archetype.id,
            archetypeRow: row,
            chunkIndex: chunkLocation.chunkIndex,
            chunkRow: chunkLocation.entityRow
        )
        entity.world = self
        addedEntities.insert(entity.id)
        eventManager.send(WorldEvents.DidAddEntity(entity: entity), source: self)
    }

    /// Move entity to new archetype.
    private func moveEntityToArchetype(
        _ entityId: Entity.ID,
        oldLocation location: EntityLocation,
        newArchetype: Archetype.ID
    ) {
        var archetype = self.archetypes.archetypes[location.archetypeId]
        let entity = archetype.entities[location.archetypeRow]
        var toArchetype = self.archetypes.archetypes[newArchetype]
        let row = toArchetype.append(entity)
        let result = archetype.swapRemove(at: location.archetypeRow)
        let newLocation = archetype.chunks.moveEntity(entityId, to: &toArchetype.chunks).newLocation
        if let swappedEntity = result.swappedEntity {
            entities.entities[swappedEntity] = EntityLocation(
                archetypeId: location.archetypeId,
                archetypeRow: location.archetypeRow,
                chunkIndex: location.chunkIndex,
                chunkRow: location.chunkRow
            )
        }

        self.archetypes.archetypes[location.archetypeId] = archetype
        self.archetypes.archetypes[newArchetype] = toArchetype
        self.entities.entities[entityId] = EntityLocation(
            archetypeId: newArchetype,
            archetypeRow: row,
            chunkIndex: newLocation.chunkIndex,
            chunkRow: newLocation.entityRow
        )
    }

    /// Remove entity record.
    /// - Parameter entity: The entity to remove.
    private func removeEntityRecord(_ entity: Entity.ID) {
        guard let record = self.entities.entities[entity] else {
            return
        }
        self.entities.entities[entity] = nil

        var currentArchetype = self.archetypes.archetypes[record.archetypeId]
        let removeResult = currentArchetype.swapRemove(at: record.archetypeRow)

        if
            let swappedEntity = removeResult.swappedEntity,
            let swappedLocation = entities.entities[swappedEntity]
        {
            entities.entities[swappedEntity] = EntityLocation(
                archetypeId: swappedLocation.archetypeId,
                archetypeRow: record.archetypeRow,
                chunkIndex: swappedLocation.chunkIndex,
                chunkRow: swappedLocation.chunkRow
            )
        }

        let removeChunkResult = currentArchetype.chunks.removeEntity(entity)
        if let removeChunkResult, let swappedEntity = removeChunkResult.swappedEntity {
            if let swappedLocation = entities.entities[swappedEntity] {
                entities.entities[swappedEntity] = EntityLocation(
                    archetypeId: swappedLocation.archetypeId,
                    archetypeRow: swappedLocation.archetypeRow,
                    chunkIndex: removeChunkResult.newLocation.chunkIndex,
                    chunkRow: removeChunkResult.newLocation.entityRow
                )
            }
        }

        self.archetypes.archetypes[record.archetypeId] = currentArchetype
    }
}

/// Events the world triggers.
public enum WorldEvents {
    /// Raised after an entity is added to the scene.
    public struct DidAddEntity: Event {
        public let entity: Entity
    }

    /// Raised before an entity is removed from the scene.
    public struct WillRemoveEntity: Event {
        public let entity: Entity
    }
}

private extension World {
    enum CodingKeys: String, CodingKey {
        case name
        case entities
        case resources
        case systems
        case plugins
    }
}
