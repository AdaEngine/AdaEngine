//
//  World.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/26/22.
//

import AdaUtils
import Collections

/// TODO: (Vlad)
/// [] Recalculate archetype for removed and added components. Archetype should use graph
/// [] Archetype to struct?

/// Stores and exposes operations on ``Entity`` and ``Component``.
///
/// Each ``Entity`` has a set of components. Each component can have up to one instance of each
/// component type. Entity components can be created, updated, removed, and queried using a given World.
/// - Warning: Still work in progress.
public final class World: @unchecked Sendable, Codable {
    private var records: OrderedDictionary<Entity.ID, EntityRecord> = [:]

    internal private(set) var removedEntities: Set<Entity.ID> = []
    internal private(set) var addedEntities: Set<Entity.ID> = []
    
    private(set) var archetypes: SparseArray<Archetype> = []
    private var freeArchetypeIndices: [Int] = []
    
    private var updatedEntities: Set<Entity> = []
    private var updatedComponents: [Entity: Set<ComponentId>] = [:]

    private var componentsStorage = ComponentsStorage()
    
    internal let systemGraph = SystemsGraph()
    internal let systemGraphExecutor = SystemsGraphExecutor()
    private var isReady = false
    
    private var plugins: [WorldPlugin] = []
    public private(set) var eventManager: EventManager = EventManager.default
    
    // MARK: - Methods
    
    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entities = try container.decode([Entity].self, forKey: .entities)
        let systems = try container.decode([String].self, forKey: .systems)
        let plugins = try container.decode([String].self, forKey: .plugins)

        for entity in entities {
            self.addEntity(entity)
        }

        self.tick()

        for system in systems {
            guard let systemType = SystemStorage.getRegistredSystem(for: system) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .systems, 
                    in: container, 
                    debugDescription: "System \(system) not found"
                )
            }
            self.addSystem(systemType)
        }

        for plugin in plugins {
            guard let pluginType = WorldPluginStorage.getRegistredPlugin(for: plugin) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .plugins, 
                    in: container, 
                    debugDescription: "Plugin \(plugin) not found"
                )
           }

           self.addPlugin(pluginType.init())
       }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.getEntities() + updatedEntities, forKey: .entities)
        try container.encode(self.systemGraph.systems.map { type(of: $0).swiftName }, forKey: .systems)
        try container.encode(self.plugins.map { type(of: $0).swiftName }, forKey: .plugins)
    }
    
    /// Get all entities in world.
    /// - Complexity: O(n)
    public func getEntities() -> [Entity] {
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
    public func getEntityByID(_ entityID: Entity.ID) -> Entity? {
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
    public func getEntityByName(_ name: String) -> Entity? {
        for arch in archetypes {
            if let ent = arch.entities.first(where: { $0.name == name }) {
                return ent
            }
        }
        
        return nil
    }
    
    /// Add new system to the world.
    /// - Warning: System should be added before build.
    /// - Parameter systemType: System type.
    @discardableResult
    public func addSystem<T: System>(_ systemType: T.Type) -> Self {
        if self.isReady {
            assertionFailure("Can't insert system if scene was ready")
            return self
        }
        let system = systemType.init(world: self)
        self.systemGraph.addSystem(system)
        return self
    }
    
    /// Add new scene plugin to the scene.
    /// - Warning: Plugin should be added before build.
    /// - Parameter plugin: Plugin instance.
    @discardableResult
    public func addPlugin<T: WorldPlugin>(_ plugin: T) -> Self {
        if self.isReady {
            assertionFailure("Can't insert plugin if scene was ready")
            return self
        }
        plugin.setup(in: self)
        self.plugins.append(plugin)
        return self
    }

    public func build() {
        if isReady {
            fatalError("World already configured")
        }
        isReady = true
        self.systemGraph.linkSystems()
        self.tick()
    }
    
    // FIXME: Can crash if we change components set during runtime from different thread
    
    /// Add a new entity to the world. This entity will be available on the next update tick.
    /// - Warning: If entity has different world, than we return assertation error.
    @discardableResult
    public func addEntity(_ entity: Entity) -> Self {
        precondition(entity.world !== self, "Entity has different world reference, and can't be added")
        entity.world = self
        
        self.updatedEntities.insert(entity)
        self.addedEntities.insert(entity.id)
        
        eventManager.send(WorldEvents.DidAddEntity(entity: entity), source: self)
        return self
    }
    
    /// Remove entity from world.
    /// - Parameter recursively: also remove entity child.
    @discardableResult
    public func removeEntity(_ entity: Entity, recursively: Bool = false) -> Self {
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
    public func removeEntityOnNextTick(_ entity: Entity, recursively: Bool = false) {
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
    @discardableResult
    public func insertResource<T: Component>(_ resource: T) -> Self {
        let componentId = self.componentsStorage.getOrRegisterComponent(T.self)
        self.componentsStorage.resourceComponents[componentId] = resource
        return self
    }

    /// Remove a resource from the world.
    /// - Parameter resource: The resource to remove.
    public func removeResource<T: Component>(_ resource: T.Type) {
        self.componentsStorage.removeResource(resource)
    }

    /// Get a resource from the world.
    /// - Parameter resource: The resource to get.
    /// - Returns: The resource if it exists, otherwise nil.
    public func getResource<T: Component>(_ resource: T.Type) -> T? {
        return self.componentsStorage.getResource(resource)
    }

    /// Check if component was changed for entity.
    /// - Parameter component: Component identifier.
    /// - Parameter entity: Entity.
    /// - Returns: True if component was changed for entity, otherwise false.
    public func isComponentChanged<T: Component>(_ component: T.Type, for entity: Entity) -> Bool {
        return self.updatedComponents[entity]?.contains(T.identifier) ?? false
    }
    
    /// Update all data in world.
    /// - Parameter deltaTime: Time interval since last update.
    @MainActor
    public func update(_ deltaTime: TimeInterval) async {
        self.tick()
        
        await withTaskGroup(of: Void.self) { @MainActor group in
            let context = SceneUpdateContext(
                world: self,
                deltaTime: deltaTime,
                scheduler: group
            )
            self.systemGraphExecutor.execute(self.systemGraph, context: context)
        }
    }
    
    /// Remove all data from world.
    public func clear() {
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
    func entity(_ entity: Entity, didAddComponent component: Component, with identifier: ComponentId) {
        let componentType = type(of: component)
        eventManager.send(ComponentEvents.DidAdd(componentType: componentType, entity: entity))

        self.updatedEntities.insert(entity)
    }
    
    func entity(_ entity: Entity, didUpdateComponent component: Component, with identifier: ComponentId) {
        let componentType = type(of: component)
        eventManager.send(ComponentEvents.DidChange(componentType: componentType, entity: entity))

        self.updatedEntities.insert(entity)
        self.updatedComponents[entity, default: []].insert(identifier)
    }
    
    func entity(_ entity: Entity, didRemoveComponent component: Component.Type, with identifier: ComponentId) {
        eventManager.send(ComponentEvents.WillRemove(componentType: component, entity: entity))
        self.updatedEntities.insert(entity)
    }
}

private extension World {
    /// Update all data in world.
    /// In this step we move entities to matched archetypes and remove pending in delition entities.
    func tick() {
        self.moveEntitiesToMatchedArchetypesIfNeeded()
        
        for entityId in self.removedEntities {
            self.removeEntityRecord(entityId)
        }
        
        // Should think about it
        self.removedEntities.removeAll(keepingCapacity: true)
        self.addedEntities.removeAll(keepingCapacity: true)
        self.updatedComponents.removeAll(keepingCapacity: true)
    }

    private func removeEntityRecord(_ entity: Entity.ID) {
        guard let record = self.records[entity] else {
            return
        }
        self.records[entity] = nil
        
        guard let currentArchetype = self.archetypes[record.archetypeId] else {
            assertionFailure("Incorrect record of archetype \(record)")
            return
        }
        currentArchetype.remove(at: record.row)
        
        if currentArchetype.entities.isEmpty {
            self.archetypes[record.archetypeId]!.clear()
            self.freeArchetypeIndices.append(record.archetypeId)
        }
    }

    /// Find or create matched arhcetypes for all entities that wait update
    private func moveEntitiesToMatchedArchetypesIfNeeded() {
        guard !self.updatedEntities.isEmpty else {
            return
        }
        
        for entity in self.updatedEntities {
           let bitmask = entity.components.bitset
            
            if let record = self.records[entity.id], let currentArchetype = self.archetypes[record.archetypeId] {
                
                // We currently updated existed components
                if currentArchetype.componentsBitMask == bitmask {
                    continue
                }
                
                currentArchetype.remove(at: record.row)
            }
            
            // Previous archetype doesn't match for an entity bit mask, try to find a new one
            var archetype = self.archetypes.first(where: {
                $0.componentsBitMask == bitmask
            })
            
            // We don't have matched archetype -> create a new one
            if archetype == nil {
                let newArch: Archetype
                
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
        }
        
        self.updatedEntities.removeAll(keepingCapacity: true)
    }
}

extension World {
    /// Returns all entities of the scene which pass the ``QueryPredicate`` of the query.
    public func performQuery(_ query: EntityQuery) -> QueryResult<Entity> {
        let state = query.state
        state.updateArchetypes(in: self)
        return QueryResult(state: state)
    }
}

extension World: EventSource { }

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
        case entities
        case systems
        case plugins
    }
}

extension World {
    struct ComponentsStorage {
        var components: [ComponentId] = []
        var resourceIds: [ObjectIdentifier: ComponentId] = [:]
        var resourceComponents: [ComponentId: any Component] = [:]

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
            return registerResource(T.self)
        }

        mutating func registerResource<T: Component>(_ resource: T.Type) -> ComponentId {
            let id = ObjectIdentifier(T.self)
            let componentId = registerComponent()
            self.resourceIds[id] = componentId
            return componentId
        }

        func getResource<T: Component>(_ resource: T.Type) -> T? {
            let id = ObjectIdentifier(T.self)
            guard let componentId = self.resourceIds[id] else {
                return nil
            }
            return self.resourceComponents[componentId] as? T
        }

        mutating func removeResource<T: Component>(_ resource: T.Type) {
            let id = ObjectIdentifier(T.self)
            guard let componentId = self.resourceIds[id] else {
                return
            }
            self.resourceComponents[componentId] = nil
            self.resourceIds[id] = nil
        }
    }
}
