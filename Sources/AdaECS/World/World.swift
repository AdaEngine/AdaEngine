//
//  World.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/26/22.
//

import AdaUtils
import Collections
import Foundation
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
    public var commands: WorldCommands = WorldCommands()

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

    public func incrementChangeTick() -> Tick {
        let lastValue = self.changeTick.loadThenWrappingIncrement(
            ordering: .relaxed
        )
        return Tick(value: lastValue)
    }
}

public extension World {
    // MARK: - Scheduler API

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

public extension World {
    /// Add new system to the world.
    /// - Warning: System should be added before build.
    /// - Parameter systemType: System type.
    /// Add a system to a specific scheduler.
    @discardableResult
    func addSystem<T: System>(_ systemType: T.Type, on scheduler: SchedulerName) -> Self {
        let system = systemType.init(world: self)
        self.schedulers.addSystem(system, for: scheduler)
        return self
    }

    /// Add new system to the world.
    /// - Warning: System should be added before build.
    /// - Parameter systemType: System type.
    /// - Returns: A world instance.
    @discardableResult
    func addSystem<T: System>(_ systemType: T.Type) -> Self {
        return addSystem(systemType, on: .update)
    }
}

public extension World {
    /// Get all entities in world.
    /// - Complexity: O(n)
    /// - Returns: All entities in world.
    func getEntities() -> [Entity] {
        return self.entities.entities.values
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
        guard let record = self.entities.entities[entityID] else {
            return nil
        }

        let archetype = self.archetypes.archetypes[record.archetypeId]
        return archetype.entities[record.archetypeRow]
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

    /// Add a new entity to the world. This entity will be available on the next update tick.
    /// - Parameter entity: The entity to add.
    /// - Parameter needsCopy: If true, the entity will be copied before adding to the world.
    /// - Returns: A world instance.
    @discardableResult
    func addEntity(_ entity: consuming Entity) -> Self {
        self.flush()
        
        let entity = entity
        entity.world = self

        eventManager.send(WorldEvents.DidAddEntity(entity: entity), source: self)
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

    /// Update all data in world.
    /// In this step we move entities to matched archetypes and remove pending in delition entities.
    func flush() {
        self.commands.flush(to: self)

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

    /// Remove all data from world.
    /// - Complexity: O(n)
    func clear() {
        self.entities.entities.removeAll(keepingCapacity: true)
        self.removedEntities.removeAll(keepingCapacity: true)
        self.addedEntities.removeAll(keepingCapacity: true)
        self.archetypes.clear()
    }

    /// Clear all resources from the world.
    /// - Complexity: O(1)
    func clearResources() {
        self.componentsStorage.resourceComponents.removeAll(keepingCapacity: true)
    }
}

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
}

private extension World {
    private func moveEntityToArchetype(
        _ entityId: Entity.ID,
        oldLocation location: EntityLocation,
        newArchetype: Archetype.ID
    ) {
        var archetype = self.archetypes.archetypes[location.archetypeId]
        guard let entity = archetype.entities[location.archetypeRow] else {
            assertionFailure("Entity \(entityId) not found in archetype")
            return
        }
        var toArchetype = self.archetypes.archetypes[newArchetype]
        let row = toArchetype.append(entity)
        print("Move entity \(entity.id) from archetype \(location.archetypeId) to \(newArchetype)")
        let newLocation = archetype.chunks.moveEntity(entityId, to: &toArchetype.chunks).newLocation
        archetype.remove(at: location.archetypeRow)
        self.archetypes.archetypes[location.archetypeId] = archetype
        self.archetypes.archetypes[newArchetype] = toArchetype
        self.entities.entities[entityId] = EntityLocation(
            archetypeId: newArchetype,
            archetypeRow: row,
            chunkIndex: newLocation.chunkIndex,
            chunkRow: newLocation.entityRow
        )
        print("Old location \(location), newLocation: \(self.entities.entities[entityId]!)")
    }
}

private extension World {
    /// Remove entity record.
    /// - Parameter entity: The entity to remove.
    private func removeEntityRecord(_ entity: Entity.ID) {
        guard let record = self.entities.entities[entity] else {
            return
        }
        self.entities.entities[entity] = nil

        var currentArchetype = self.archetypes.archetypes[record.archetypeId]
        currentArchetype.remove(at: record.archetypeRow)

        if currentArchetype.entities.isEmpty {
            self.archetypes.archetypes[record.archetypeId].clear()
        }

        self.archetypes.archetypes[record.archetypeId] = currentArchetype
    }
}

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
        let components: [any Component] = bundle.components.reduce(into: []) { partialResult, component in
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
        return entity
    }

    @discardableResult
    @inline(__always)
    func spawn(_ name: String = "") -> Entity {
        self.spawn(name) {}
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

    // TODO: insert doesn't works correctly
        // - Component not inserted after entity moved to new arch
        // - Required Component not initialized
    func insert<T: Component>(_ component: consuming T, for entityId: Entity.ID) {
        guard let location = self.entities.entities[entityId] else {
            return
        }

        var archetype = self.archetypes.archetypes[location.archetypeId]
        if archetype.componentLayout.bitSet.contains(T.identifier) {
            self.archetypes
                .archetypes[location.archetypeId]
                .chunks
                .chunks[location.chunkIndex]
                .insert(component, at: location.chunkRow, lastTick: self.lastTick)
            return
        }
        var newLayout = archetype.componentLayout
        newLayout.insert(T.self)

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
    }

    @inline(__always)
    func remove<T: Component>(_ component: consuming T, for entity: Entity.ID) {
        self.remove(T.identifier, from: entity)
    }
    
    /// Remove a component of the specified type from an entity.
    /// - Parameter componentType: The type of component to remove.
    /// - Parameter entity: The entity ID to remove the component from.
    @inline(__always)
    func remove<T: Component>(_ componentType: T.Type, from entity: Entity.ID) {
//        eventManager.send(ComponentEvents.WillRemove(componentType: T.self, entity: entity))
        self.remove(T.identifier, from: entity)
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

extension World {
    struct ComponentsStorage: Sendable {
        struct RequiredComponentInfo: Sendable {
            let id: ComponentId
            let constructor: @Sendable () -> any Component
        }

        private var components: [ComponentId] = []
        private var componentsIds: [ObjectIdentifier: ComponentId] = [:]
        private var resourceIds: [ObjectIdentifier: ComponentId] = [:]
        var resourceComponents: [ComponentId: any Resource] = [:]
        private var requiredComponents: [ComponentId: [RequiredComponentInfo]] = [:]

        mutating func registerRequiredComponent<T: Component>(
            for component: ComponentId,
            requiredComponentId: ComponentId,
            constructor: @Sendable @escaping () -> T
        ) {
            var requiredComponents = self.requiredComponents[component] ?? []
            let newInfo = RequiredComponentInfo(
                id: requiredComponentId,
                constructor: constructor
            )
            if let index = requiredComponents.firstIndex(where: { $0.id == requiredComponentId }) {
                requiredComponents[index] = newInfo
            } else {
                requiredComponents.append(newInfo)
            }

            self.requiredComponents[component] = requiredComponents
        }

        @discardableResult
        mutating func registerComponent() -> ComponentId {
            let id = ComponentId(id: components.count)
            self.components.append(id)
            return id
        }

        mutating func getOrRegisterComponent<T: Component>(
            _ component: T.Type
        ) -> ComponentId {
            let id = ObjectIdentifier(T.self)
            if let componentId = self.componentsIds[id] {
                return componentId
            }
            let componentId = registerComponent()
            componentsIds[id] = componentId
            return componentId
        }

        mutating func getOrRegisterResource(
            _ resource: any Resource.Type
        ) -> ComponentId {
            let id = resource.identifier
            if let componentId = self.resourceIds[id] {
                return componentId
            }
            return registerResource(resource, id: id)
        }

        mutating func registerResource<T: Resource>(
            _ resource: T.Type,
            id: ObjectIdentifier
        ) -> ComponentId {
            Task { @MainActor in
                T.registerResource()
            }
            let componentId = registerComponent()
            self.resourceIds[id] = componentId
            return componentId
        }

        func getResource<T: Resource>(_ resource: T.Type) -> T? {
            guard let componentId = self.resourceIds[T.identifier] else {
                return nil
            }
            return self.resourceComponents[componentId] as? T
        }

        @inline(__always)
        func getComponentId<T: Component>(_ component: T.Type) -> ComponentId? {
            self.componentsIds[ObjectIdentifier(T.self)]
        }

        func getRequiredComponents<T: Component>(for component: T) -> [RequiredComponentInfo] {
            getComponentId(T.self).flatMap { self.requiredComponents[$0] } ?? []
        }

        mutating func removeResource<T: Resource>(_ resource: T.Type) {
            let id = ObjectIdentifier(T.self)
            guard let componentId = self.resourceIds[id] else {
                return
            }
            self.resourceComponents[componentId] = nil
            self.resourceIds[id] = nil
        }
    }
}

extension Array where Element == Component {
    var bitSet: BitSet {
        var bitSet = BitSet(reservingCapacity: self.count)
        for component in self {
            bitSet.insert(type(of: component).identifier)
        }
        return bitSet
    }
}
