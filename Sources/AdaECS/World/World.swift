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
    @LocalIsolated public private(set) var entities: Entities = Entities()
    @LocalIsolated public private(set) var archetypes: Archetypes = Archetypes()
    /// The removed entities of the world.
    @LocalIsolated internal private(set) var removedEntities: Set<Entity.ID> = []
    /// The added entities of the world.
    @LocalIsolated internal private(set) var addedEntities: Set<Entity.ID> = []
    /// The updated entities of the world.
    @LocalIsolated private var removedComponents: [Entity.ID: Set<ComponentId>] = [:]
    @LocalIsolated private var componentsStorage = ComponentsStorage()
    public var commands: WorldCommands = WorldCommands()

    private var isReady = false

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
                self.insertResource(resource as! Resource)
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
        print("Run scheduler", schedulerName)
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
        if self.isReady {
            assertionFailure("Can't insert system if scene was ready")
            return self
        }
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
            .chunks
            .getPointer(at: location.chunkIndex)
            .pointee
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
}

public extension World {
    /// Insert a resource into the world.
    /// - Parameter resource: The resource to insert.
    /// - Returns: A world instance.
    @discardableResult
    func insertResource<T: Resource>(_ resource: consuming T) -> Self {
        let componentId = self.componentsStorage.getOrRegisterResource(T.self)
        if self.componentsStorage.resourceComponents[componentId] != nil {
            return self
        }
        self.componentsStorage.resourceComponents[componentId] = resource
        return self
    }

    /// Insert a resource into the world.
    /// - Parameter resource: The resource to insert.
    /// - Returns: A world instance.
    @discardableResult
    func insertResource(_ resource: consuming any Resource) -> Self {
        let resource = resource
        let componentId = self.componentsStorage.getOrRegisterResource(type(of: resource))
        if self.componentsStorage.resourceComponents[componentId] != nil {
            return self
        }
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

extension World {
    func moveEntityToArchetype(
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
        print("Move entity \(entity.name)(\(entity.id)) from archetype \(location.archetypeId) to \(newArchetype)")
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
        let entity = Entity(name: name)
        let components = bundle.components
        let archetypeIndex = self.archetypes.getOrCreate(
            for: ComponentLayout(components: components)
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
            .chunks
            .getPointer(at: location.chunkIndex)
            .pointee
            .get(at: location.chunkRow)
    }

    @inline(__always)
    func get<T: Component>(_ type: T.Type, from entity: Entity.ID) -> T? {
        return self.get(from: entity)
    }

    func set<T: Component>(_ component: consuming T, for entityId: Entity.ID) {
        guard let location = self.entities.entities[entityId] else {
            return
        }
        var archetype = self.archetypes.archetypes[location.archetypeId]
        if archetype.componentLayout.bitSet.contains(T.identifier) {
            self.archetypes
                .archetypes[location.archetypeId]
                .chunks
                .chunks
                .getPointer(at: location.chunkIndex)
                .pointee
                .set(component, at: location.chunkRow, lastTick: self.lastTick)
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
//        guard let entityInstance = archetype.entities[location.archetypeRow] else {
//            return // Entity doesn't exist in the archetype
//        }
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
        var sparseComponents: [ComponentId: SparseArray<any Component>] = [:]

        var components: [ComponentId] = []
        var resourceIds: [ObjectIdentifier: ComponentId] = [:]
        var resourceComponents: [ComponentId: any Resource] = [:]

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
            if let componentId = self.resourceIds[id] {
                return componentId
            }
            return registerComponent()
        }

        mutating func getOrRegisterResource(
            _ resource: any Resource.Type
        ) -> ComponentId {
            let id = resource.identifier
            if let componentId = self.resourceIds[id] {
                return componentId
            }
            return registerResource(resource)
        }

        mutating func registerResource<T: Resource>(_ resource: T.Type) -> ComponentId {
            Task { @MainActor in
                T.registerResource()
            }
            let id = ObjectIdentifier(T.self)
            let componentId = registerComponent()
            self.resourceIds[id] = componentId
            return componentId
        }

        func getResource<T: Resource>(_ resource: T.Type) -> T? {
            let id = ObjectIdentifier(T.self)
            guard let componentId = self.resourceIds[id] else {
                return nil
            }
            return self.resourceComponents[componentId] as? T
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

//
//extension World {
//    /// Insert mode for batch operations.
//    public enum InsertMode {
//        /// Replace existing components
//        case replace
//        /// Insert only if component doesn't exist
//        case insertOnly
//        /// Keep existing components if they exist
//        case keepExisting
//    }
//    
//    /// Error type for batch insertion operations.
//    public struct TryInsertBatchError: Error {
//        /// The type name of the bundle that failed to insert.
//        public let bundleType: String
//        /// The entities that were invalid during insertion.
//        public let entities: [Entity.ID]
//        
//        public var localizedDescription: String {
//            "Failed to insert bundle '\(bundleType)' for entities: \(entities)"
//        }
//    }
//    
//    /// A location in the world that may or may not exist.
//    public enum MaybeLocation {
//        case none
//        case location(EntityRecord)
//    }
//    
//    /// A bundle inserter for optimized batch operations.
//    private struct BundleInserter {
//        private let world: World
//        private let archetypeId: Archetype.ID
//        private let insertMode: InsertMode
//        
//        init(world: World, archetypeId: Archetype.ID, insertMode: InsertMode) {
//            self.world = world
//            self.archetypeId = archetypeId
//            self.insertMode = insertMode
//        }
//        
//        /// Insert components for an entity.
//        mutating func insert(
//            entity: Entity,
//            location: EntityRecord,
//            components: [any Component],
//            insertMode: InsertMode,
//            caller: MaybeLocation
//        ) {
//            // Set the components on the entity based on insert mode
//            for component in components {
//                switch insertMode {
//                case .replace:
//                    entity.components.set(component)
//                case .insertOnly:
//                    if !entity.components.has(type(of: component)) {
//                        entity.components.set(component)
//                    }
//                case .keepExisting:
//                    if !entity.components.has(type(of: component)) {
//                        entity.components.set(component)
//                    }
//                }
//            }
//            
//            // Mark entity as updated so it gets moved to the correct archetype
//            world.updatedEntities.insert(entity)
//        }
//        
//        /// Get entities from the world.
//        func entities() -> OrderedDictionary<Entity.ID, EntityRecord> {
//            return world.records
//        }
//    }
//    
//    /// Cache for archetype inserters to optimize batch operations.
//    private struct InserterArchetypeCache {
//        var inserter: BundleInserter
//        var archetypeId: Archetype.ID
//    }
//    
//    /// Try to insert a batch of entities with components.
//    /// - Parameters:
//    ///   - batch: Sequence of (Entity, [Component]) pairs to insert
//    ///   - insertMode: How to handle existing components
//    ///   - caller: Optional caller location for debugging
//    /// - Returns: Result indicating success or failure with invalid entities
//    public func tryInsertBatch<S: Sequence>(
//        _ batch: S,
//        insertMode: InsertMode = .replace,
//        caller: MaybeLocation = .none
//    ) -> Result<Void, TryInsertBatchError> 
//    where S.Element == (Entity, [any Component]) {
//        
//        // Flush pending changes first
//        self.flush()
//        
//        var invalidEntities: [Entity.ID] = []
//        var batchIterator = batch.makeIterator()
//        
//        // Find the first valid entity to initialize the bundle inserter
//        var cache: InserterArchetypeCache? = nil
//        
//        while let (firstEntity, firstComponents) = batchIterator.next() {
//            if let firstLocation = self.records[firstEntity.id] {
//                cache = InserterArchetypeCache(
//                    inserter: BundleInserter(
//                        world: self,
//                        archetypeId: firstLocation.archetypeId,
//                        insertMode: insertMode
//                    ),
//                    archetypeId: firstLocation.archetypeId
//                )
//                
//                // Insert the first entity's components
//                cache!.inserter.insert(
//                    entity: firstEntity,
//                    location: firstLocation,
//                    components: firstComponents,
//                    insertMode: insertMode,
//                    caller: caller
//                )
//                break
//            }
//            invalidEntities.append(firstEntity.id)
//        }
//        
//        // Process the rest of the batch if we have a valid cache
//        if var cache = cache {
//            while let (entity, components) = batchIterator.next() {
//                if let location = self.records[entity.id] {
//                    // Check if we need to update the cache for a different archetype
//                    if location.archetypeId != cache.archetypeId {
//                        cache = InserterArchetypeCache(
//                            inserter: BundleInserter(
//                                world: self,
//                                archetypeId: location.archetypeId,
//                                insertMode: insertMode
//                            ),
//                            archetypeId: location.archetypeId
//                        )
//                    }
//                    
//                    // Insert the entity's components
//                    cache.inserter.insert(
//                        entity: entity,
//                        location: location,
//                        components: components,
//                        insertMode: insertMode,
//                        caller: caller
//                    )
//                } else {
//                    invalidEntities.append(entity.id)
//                }
//            }
//        }
//        
//        // Return result based on whether any entities were invalid
//        if invalidEntities.isEmpty {
//            return .success(())
//        } else {
//            let bundleTypeName = "ComponentBundle" // Generic name since we don't have specific bundle types
//            return .failure(TryInsertBatchError(
//                bundleType: bundleTypeName,
//                entities: invalidEntities
//            ))
//        }
//    }
//    
//    /// Convenience method for batch insertion that throws on error.
//    /// - Parameters:
//    ///   - batch: Sequence of (Entity, [Component]) pairs to insert
//    ///   - insertMode: How to handle existing components
//    ///   - caller: Optional caller location for debugging
//    /// - Throws: TryInsertBatchError if any entities are invalid
//    public func insertBatch<S: Sequence>(
//        _ batch: S,
//        insertMode: InsertMode = .replace,
//        caller: MaybeLocation = .none
//    ) throws 
//    where S.Element == (Entity, [any Component]) {
//        
//        let result = tryInsertBatch(batch, insertMode: insertMode, caller: caller)
//        switch result {
//        case .success:
//            return
//        case .failure(let error):
//            throw error
//        }
//    }
//    
//    /// Convenience method for inserting a batch of entities with the same components.
//    /// - Parameters:
//    ///   - entities: Array of entities to add components to
//    ///   - components: Components to add to each entity using ComponentsBuilder
//    ///   - insertMode: How to handle existing components
//    /// - Throws: TryInsertBatchError if any entities are invalid
//    public func insertBatch(
//        entities: [Entity],
//        @ComponentsBuilder components: () -> [Component],
//        insertMode: InsertMode = .replace
//    ) throws {
//        let componentList = components()
//        let batch = entities.map { ($0, componentList) }
//        try insertBatch(batch, insertMode: insertMode)
//    }
//}


extension Array where Element == Component {
    var bitSet: BitSet {
        var bitSet = BitSet(reservingCapacity: self.count)
        for component in self {
            bitSet.insert(type(of: component).identifier)
        }
        return bitSet
    }
}


//extension World {
//    /// Entity did add component.
//    /// - Parameter entity: The entity that did add component.
//    /// - Parameter component: The component that did add.
//    /// - Parameter identifier: The identifier of the component.
//    func entity<T: Component>(
//        _ entity: consuming Entity,
//        didAddComponent component: T.Type,
//        with identifier: ComponentId
//    ) {
//        let entity = entity
//        eventManager.send(ComponentEvents.DidAdd(componentType: component, entity: entity))
//    }
//
//    /// Entity did update component.
//    /// - Parameter entity: The entity that did update component.
//    /// - Parameter component: The component that did update.
//    /// - Parameter identifier: The identifier of the component.
//    func entity<T: Component>(
//        _ entity: consuming Entity,
//        didUpdateComponent component: T.Type,
//        with identifier: ComponentId
//    ) {
//        let entity = entity
//        eventManager.send(ComponentEvents.DidChange(componentType: component, entity: entity))
//        self.updatedEntities.insert(entity)
//        self.updatedComponents[entity.id, default: []].insert(identifier)
//    }
//
//    /// Entity did remove component.
//    /// - Parameter entity: The entity that did remove component.
//    /// - Parameter component: The component that did remove.
//    /// - Parameter identifier: The identifier of the component.
//    func entity(
//        _ entity: consuming Entity,
//        didRemoveComponent component: Component.Type,
//        with identifier: ComponentId
//    ) {
//        let entity = entity
//        eventManager.send(ComponentEvents.WillRemove(componentType: component, entity: entity))
//        self.updatedEntities.insert(entity)
//    }
//}
