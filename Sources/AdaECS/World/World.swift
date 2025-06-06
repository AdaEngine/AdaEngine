//
//  World.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/26/22.
//

import AdaUtils
import Collections
import Foundation

/// TODO: (Vlad)
/// [] Recalculate archetype for removed and added components. Archetype should use graph

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

    /// The records of the world.
    private var records: OrderedDictionary<Entity.ID, EntityRecord> = [:]

    /// The removed entities of the world.
    internal private(set) var removedEntities: Set<Entity.ID> = []

    /// The added entities of the world.
    internal private(set) var addedEntities: Set<Entity.ID> = []

    /// The archetypes of the world.
    private(set) var archetypes: SparseArray<Archetype> = []

    /// The free archetype indices of the world.
    private var freeArchetypeIndices: [Int] = []

    /// The updated entities of the world.
    private var updatedEntities: Set<Entity> = []
    private var updatedComponents: [Entity: Set<ComponentId>] = [:]

    private var componentsStorage = ComponentsStorage()
    private var isReady = false

    public private(set) var eventManager: EventManager = EventManager.default

    // Scheduler registry and mapping from scheduler to systems
    public let schedulers = Schedulers(SchedulerName.default)

    // MARK: - Methods

    public init(name: String? = nil) {
        self.name = name
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
        let entities = (self.getEntities() + updatedEntities).sorted(by: {
            $0.id < $1.id
        })
        try container.encode(entities, forKey: .entities)
        var unkeyedContainer = container.nestedContainer(keyedBy: CodingName.self, forKey: .resources)
        for resource in self.componentsStorage.resourceComponents.values {
            try unkeyedContainer.encode(AnyEncodable(resource), forKey: CodingName(stringValue: type(of: resource).swiftName))
        }
    }

    // MARK: - Scheduler API

    /// Set the order of schedulers for this world.
    /// - Parameter schedulers: The schedulers to set.
    public func setSchedulers(_ schedulers: [SchedulerName]) {
        self.schedulers.setSchedulers(schedulers)
    }

    /// Insert a scheduler before or after another scheduler.
    /// - Parameter scheduler: The scheduler to insert.
    /// - Parameter after: The scheduler after which to insert the new scheduler.
    public func insertScheduler(_ scheduler: Scheduler, after: SchedulerName) {
        schedulers.insert(scheduler, after: after)
    }

    /// Insert a scheduler before or before another scheduler.
    /// - Parameter scheduler: The scheduler to insert.
    /// - Parameter before: The scheduler before which to insert the new scheduler.
    public func insertScheduler(_ scheduler: Scheduler, before: SchedulerName) {
        schedulers.insert(scheduler, before: before)
    }

    /// Contains scheduler
    /// - Parameter scheduler: The scheduler to check.
    /// - Returns: True if the scheduler exists, otherwise false.
    public func containsScheduler(_ scheduler: SchedulerName) -> Bool {
        self.schedulers.contains(scheduler)
    }

    /// Add schedulers.
    /// - Parameter schedulers: The schedulers to add.
    public func addSchedulers(_ schedulers: SchedulerName...) {
        schedulers.forEach {
            self.schedulers.append(Scheduler(name: $0))
        }
    }

    /// Add new system to the world.
    /// - Warning: System should be added before build.
    /// - Parameter systemType: System type.
    /// Add a system to a specific scheduler.
    @discardableResult
    public func addSystem<T: System>(_ systemType: T.Type, on scheduler: SchedulerName) -> Self {
        if self.isReady {
            assertionFailure("Can't insert system if scene was ready")
            return self
        }
        let system = systemType.init(world: self)
        self.schedulers.getScheduler(scheduler)?.systemGraph.addSystem(system)
        return self
    }

    /// Add new system to the world.
    /// - Warning: System should be added before build.
    /// - Parameter systemType: System type.
    /// - Returns: A world instance.
    @discardableResult
    public func addSystem<T: System>(_ systemType: T.Type) -> Self {
        return addSystem(systemType, on: .update)
    }
}

public extension World {
    /// Get all entities in world.
    /// - Complexity: O(n)
    /// - Returns: All entities in world.
    func getEntities() -> [Entity] {
        return self.records.values.elements
            .map { record in
                let archetype = self.archetypes[record.archetypeId]!
                return archetype.entities[record.row]
            }
            .compactMap { $0 }
    }

    /// Get an entity by their id.
    /// - Parameter id: Entity identifier.
    /// - Complexity: O(1)
    /// - Returns: Returns nil if entity not registed in scene world.
    func getEntityByID(_ entityID: Entity.ID) -> Entity? {
        guard let record = self.records[entityID] else {
            return nil
        }

        let archetype = self.archetypes[record.archetypeId]
        return archetype?.entities[record.row]
    }

    /// Find an entity by name.
    /// - Note: Not efficient way to find an entity.
    /// - Complexity: O(n)
    /// - Returns: An entity with matched name or nil if entity with given name not exists.
    func getEntityByName(_ name: String) -> Entity? {
        for arch in archetypes {
            if let ent = arch.entities.first(where: { $0.name == name }) {
                return ent
            }
        }

        return nil
    }

    /// Build the world.
    /// - Note: This method should be called after all systems and resources are added.
    func build() {
        if isReady {
            fatalError("World already configured")
        }
        isReady = true
        for label in self.schedulers.schedulerLabels {
            let scheduler = self.schedulers.getScheduler(label)
            scheduler?.systemGraph.linkSystems()
        }
        self.flush()
    }

    /// Add a new entity to the world. This entity will be available on the next update tick.
    /// - Parameter entity: The entity to add.
    /// - Parameter needsCopy: If true, the entity will be copied before adding to the world.
    /// - Returns: A world instance.
    @discardableResult
    func addEntity(_ entity: Entity) -> Self {
        entity.world = self

        self.updatedEntities.insert(entity)
        self.addedEntities.insert(entity.id)

        eventManager.send(WorldEvents.DidAddEntity(entity: entity), source: self)
        return self
    }

    /// Remove entity from world.
    /// - Parameter recursively: also remove entity child.
    /// - Returns: A world instance.
    @discardableResult
    func removeEntity(_ entity: Entity, recursively: Bool = false) -> Self {
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
    func removeEntityOnNextTick(_ entity: Entity, recursively: Bool = false) {
        guard self.records[entity.id] != nil else {
            return
        }

        eventManager.send(WorldEvents.WillRemoveEntity(entity: entity), source: self)
        self.removedEntities.insert(entity.id)

        guard recursively && !entity.children.isEmpty else {
            return
        }

        for child in entity.children {
            self.removeEntityOnNextTick(child, recursively: recursively)
        }
    }

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
    func insertResource(_ resource: any Resource) -> Self {
        let resource = resource
        let componentId = self.componentsStorage.getOrRegisterResource(type(of: resource))
        self.componentsStorage.resourceComponents[componentId] = resource
        return self
    }

    /// Remove a resource from the world.
    /// - Parameter resource: The resource to remove.
    func removeResource<T: Resource>(_ resource: T.Type) {
        self.componentsStorage.removeResource(resource)
    }

    /// Get a resource from the world.
    /// - Parameter resource: The resource to get.
    /// - Returns: The resource if it exists, otherwise nil.
    /// - Complexity: O(1)
    /// - Returns: The resource if it exists, otherwise nil.
    borrowing func getResource<T: Resource>(_ resource: T.Type) -> T? {
        return self.componentsStorage.getResource(resource)
    }

    /// Get all resources from the world.
    /// - Returns: All resources in world.
    func getResources() -> [any Resource] {
        return Array(self.componentsStorage.resourceComponents.values)
    }

    /// Check if component was changed for entity.
    /// - Parameter component: Component identifier.
    /// - Parameter entity: Entity.
    /// - Complexity: O(1)
    /// - Returns: True if component was changed for entity, otherwise false.
    func isComponentChanged<T: Component>(_ component: T.Type, for entity: Entity) -> Bool {
        return self.updatedComponents[entity]?.contains(T.identifier) ?? false
    }

    /// Run all schedulers in world.
    /// - Parameter deltaTime: Time interval since last update.
    @MainActor
    func update(_ deltaTime: AdaUtils.TimeInterval) async {
        self.flush()
        self.clearTrackers()

        for label in self.schedulers.schedulerLabels {
            guard let scheduler = self.schedulers.getScheduler(label) else {
                continue
            }

            await scheduler.graphExecutor.execute(
                scheduler.systemGraph,
                world: self,
                deltaTime: deltaTime,
                scheduler: scheduler.name
            )
        }
    }

    /// Run a specific scheduler.
    /// - Parameter scheduler: Scheduler name.
    /// - Parameter deltaTime: Time interval since last update.
    @MainActor
    func runScheduler(_ scheduler: SchedulerName, deltaTime: AdaUtils.TimeInterval) async {
        guard let scheduler = self.schedulers.getScheduler(scheduler) else {
            fatalError("Scheduler \(scheduler) not found")
        }

        await scheduler.graphExecutor.execute(
            scheduler.systemGraph,
            world: self,
            deltaTime: deltaTime,
            scheduler: scheduler.name
        )
    }

    /// Update all data in world.
    /// In this step we move entities to matched archetypes and remove pending in delition entities.
    func flush() {
        self.moveEntitiesToMatchedArchetypesIfNeeded()

        for entityId in self.removedEntities {
            self.removeEntityRecord(entityId)
        }
    }

    /// Clear trackers for entities, components and resources.
    /// - Complexity: O(1)
    func clearTrackers() {
        self.removedEntities.removeAll(keepingCapacity: true)
        self.addedEntities.removeAll(keepingCapacity: true)
        self.updatedComponents.removeAll(keepingCapacity: true)
    }

    /// Remove all data from world.
    /// - Complexity: O(n)
    func clear() {
        self.records.removeAll(keepingCapacity: true)
        self.updatedComponents.removeAll(keepingCapacity: true)
        self.removedEntities.removeAll(keepingCapacity: true)
        self.addedEntities.removeAll(keepingCapacity: true)
        self.archetypes.removeAll(keepingCapacity: true)
        self.freeArchetypeIndices.removeAll(keepingCapacity: true)
        self.updatedEntities.removeAll(keepingCapacity: true)
    }
}

// MARK: - Delegate

extension World {
    /// Entity did add component.
    /// - Parameter entity: The entity that did add component.
    /// - Parameter component: The component that did add.
    /// - Parameter identifier: The identifier of the component.
    func entity<T: Component>(_ entity: Entity, didAddComponent component: T.Type, with identifier: ComponentId) {
        eventManager.send(ComponentEvents.DidAdd(componentType: component, entity: entity))
        self.updatedEntities.insert(entity)
    }

    /// Entity did update component.
    /// - Parameter entity: The entity that did update component.
    /// - Parameter component: The component that did update.
    /// - Parameter identifier: The identifier of the component.
    func entity<T: Component>(_ entity: Entity, didUpdateComponent component: T.Type, with identifier: ComponentId) {
        eventManager.send(ComponentEvents.DidChange(componentType: component, entity: entity))

        self.updatedEntities.insert(entity)
        self.updatedComponents[entity, default: []].insert(identifier)
    }

    /// Entity did remove component.
    /// - Parameter entity: The entity that did remove component.
    /// - Parameter component: The component that did remove.
    /// - Parameter identifier: The identifier of the component.
    func entity(_ entity: Entity, didRemoveComponent component: Component.Type, with identifier: ComponentId) {
        eventManager.send(ComponentEvents.WillRemove(componentType: component, entity: entity))
        self.updatedEntities.insert(entity)
    }
}

private extension World {
    /// Remove entity record.
    /// - Parameter entity: The entity to remove.
    private func removeEntityRecord(_ entity: Entity.ID) {
        guard let record = self.records[entity] else {
            return
        }
        self.records[entity] = nil

        guard var currentArchetype = self.archetypes[record.archetypeId] else {
            assertionFailure("Incorrect record of archetype \(record)")
            return
        }
        currentArchetype.remove(at: record.row)

        if currentArchetype.entities.isEmpty {
            self.archetypes[record.archetypeId]!.clear()
            self.freeArchetypeIndices.append(record.archetypeId)
        }

        self.archetypes[record.archetypeId] = currentArchetype
    }

    /// Find or create matched arhcetypes for all entities that wait update
    private func moveEntitiesToMatchedArchetypesIfNeeded() {
        guard !self.updatedEntities.isEmpty else {
            return
        }

        for entity in self.updatedEntities {
            let bitmask = entity.components.bitset

            if let record = self.records[entity.id], var currentArchetype = self.archetypes[record.archetypeId] {
                // We currently updated existed components
                if currentArchetype.componentsBitMask == bitmask {
                    continue
                }

                currentArchetype.remove(at: record.row)
                self.archetypes[record.archetypeId] = currentArchetype
            }

            // Previous archetype doesn't match for an entity bit mask, try to find a new one
            var archetype = self.archetypes.first(where: {
                $0.componentsBitMask == bitmask
            })

            // We don't have matched archetype -> create a new one
            if archetype == nil {
                var newArch: Archetype

                if self.freeArchetypeIndices.isEmpty {
                    newArch = Archetype.new(index: self.archetypes.count)

                    self.archetypes.append(newArch)
                } else {
                    let index = self.freeArchetypeIndices.removeFirst()
                    newArch = self.archetypes[index]!
                }
                newArch.componentsBitMask = bitmask
                archetype = newArch
            }

            let location = archetype?.append(entity)
            self.records[entity.id] = location
            self.archetypes[archetype!.id] = archetype
        }

        self.updatedEntities.removeAll(keepingCapacity: true)
    }
}

extension World {
    /// Returns all entities of the scene which pass the ``QueryPredicate`` of the query.
    public func performQuery(_ query: EntityQuery) -> EntityQuery.Result {
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
