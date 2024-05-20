//
//  World.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/26/22.
//

import Collections

/// TODO: (Vlad)
/// [] Recalculate archetype for removed and added components. Archetype should use graph
/// [] Archetype to struct?

/// Stores and exposes operations on ``Entity`` and ``Component``.
///
/// Each ``Entity`` has a set of components. Each component can have up to one instance of each
/// component type. Entity components can be created, updated, removed, and queried using a given World.
/// - Warning: Still work in progress.
public final class World {

    private var records: OrderedDictionary<Entity.ID, EntityRecord> = [:]
    
    let lock = NSRecursiveLock()

    internal private(set) var removedEntities: Set<Entity.ID> = []
    internal private(set) var addedEntities: Set<Entity.ID> = []
    
    private(set) var archetypes: SparseArray<Archetype> = []
    private var freeArchetypeIndices: [Int] = []
    
    private var updatedEntities: Set<Entity> = []
    private var updatedComponents: [Entity: Set<ComponentId>] = [:]

    /// FIXME: Not efficient, should refactor later
    private(set) var scripts: SparseArray<ScriptableComponent> = []
    private(set) var scriptRecords: [Entity.ID: [ComponentId: Int]] = [:]
    private(set) var friedScriptsIndecies: [Int] = []
    
    // MARK: - Methods
    
    /// Get all entities in world.
    /// - Complexity: O(n)
    public func getEntities() -> [Entity] {
        lock.lock()
        defer { lock.unlock() }
        
        return self.records.values.elements
            .map { record in
                let archetype = self.archetypes[record.archetypeId]!
                return archetype.entities[record.row]
            }
            .compactMap { $0 }
    }
    
    /// Get entity by identifier.
    /// - Complexity: O(1)
    public func getEntityByID(_ entityID: Entity.ID) -> Entity? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let record = self.records[entityID] else {
            return nil
        }
        
        let archetype = self.archetypes[record.archetypeId]
        return archetype?.entities[record.row]
    }
    
    /// Get entity by name.
    /// - Complexity: O(n)
    func getEntityByName(_ name: String) -> Entity? {
        lock.lock()
        defer { lock.unlock() }
        
        for arch in archetypes {
            if let ent = arch.entities.first(where: { $0.name == name }) {
                return ent
            }
        }
        
        return nil
    }
    
    // FIXME: Can crash if we change components set during runtime
    /// Append entity to world. Entity will be added when `tick()` called.
    func appendEntity(_ entity: Entity) {
        lock.lock()
        defer { lock.unlock() }

        for (identifier, component) in entity.components.buffer {
            if let script = component as? ScriptableComponent {
                self.addScript(script, entity: entity.id, identifier: identifier)
            }
        }
        
        entity.world = self
        
        self.updatedEntities.insert(entity)
        self.addedEntities.insert(entity.id)
    }
    
    func removeEntity(_ entity: Entity) {
        lock.lock()
        defer { lock.unlock() }
        
        self.removeEntityRecord(entity.id)
    }
    
    func removeEntityOnNextTick(_ entity: Entity, recursively: Bool = false) {
        lock.lock()
        defer { lock.unlock() }
        
        guard self.records[entity.id] != nil else { 
            return
        }

        self.removedEntities.insert(entity.id)

        guard recursively && !entity.children.isEmpty else {
            return
        }

        print("Start")
        print("Ent", entity)
        print("Fail?", entity.children.map { $0 === entity })
        print("Child", entity.children)

        for child in entity.children {
            self.removeEntityOnNextTick(child, recursively: recursively)
        }
    }

    func isComponentChanged(_ component: ComponentId, for entity: Entity) -> Bool {
        return self.updatedComponents[entity]?.contains(component) ?? false
    }

    private func removeEntityRecord(_ entity: Entity.ID) {
        lock.lock()
        defer { lock.unlock() }
        
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
    
    /// Remove all data from world.
    func clear() {
        self.records.removeAll(keepingCapacity: true)
        self.removedEntities.removeAll(keepingCapacity: true)
        self.addedEntities.removeAll(keepingCapacity: true)
        self.archetypes.removeAll(keepingCapacity: true)
        self.freeArchetypeIndices.removeAll(keepingCapacity: true)
        self.updatedEntities.removeAll(keepingCapacity: true)
        self.scripts.removeAll(keepingCapacity: true)
        self.scriptRecords.removeAll(keepingCapacity: true)
        self.friedScriptsIndecies.removeAll(keepingCapacity: true)
    }
    
    // MARK: - Private
    
    /// Find or create matched arhcetypes for all entities that wait update
    private func moveEntitiesToMatchedArchetypesIfNeeded() {
        if self.updatedEntities.isEmpty {
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
    
    /// Add script component
    private func addScript(_ component: ScriptableComponent, entity: Entity.ID, identifier: ComponentId) {
        if self.friedScriptsIndecies.isEmpty {
            self.scripts.append(component)
            self.scriptRecords[entity, default: [:]][identifier] = self.scripts.count - 1
        } else {
            let index = self.friedScriptsIndecies.removeLast()
            self.scripts[index] = component
            self.scriptRecords[entity, default: [:]][identifier] = index
        }
    }
    
    /// Remove script component
    private func removeScript(entity: Entity.ID, identifier: ComponentId) {
        if let row = self.scriptRecords[entity, default: [:]][identifier] {
            self.scripts[row] = nil
            friedScriptsIndecies.append(row)
        }
    }

    // MARK: - Components Delegate

    func entity(_ entity: Entity, didAddComponent component: Component, with identifier: ComponentId) {
        lock.lock()
        defer { lock.unlock() }

        if let script = component as? ScriptableComponent {
            self.addScript(script, entity: entity.id, identifier: identifier)
        }

        let componentType = type(of: component)
        EventManager.default.send(ComponentEvents.DidAdd(componentType: componentType, entity: entity))

        self.updatedEntities.insert(entity)
    }

    func entity(_ entity: Entity, didUpdateComponent component: Component, with identifier: ComponentId) {
        lock.lock()
        defer { lock.unlock() }

        if let script = component as? ScriptableComponent {
            self.addScript(script, entity: entity.id, identifier: identifier)
        }

        let componentType = type(of: component)
        EventManager.default.send(ComponentEvents.DidChange(componentType: componentType, entity: entity))

        self.updatedEntities.insert(entity)
        self.updatedComponents[entity, default: []].insert(identifier)
    }

    func entity(_ entity: Entity, didRemoveComponent component: Component.Type, with identifier: ComponentId) {
        lock.lock()
        defer { lock.unlock() }

        EventManager.default.send(ComponentEvents.WillRemove(componentType: component, entity: entity))

        if component is ScriptableComponent.Type {
            self.removeScript(entity: entity.id, identifier: identifier)
        }

        self.updatedEntities.insert(entity)
    }
}

extension World {
    /// Returns all entities of the world which pass the ``QueryPredicate`` of the query.
    public func performQuery(_ query: EntityQuery) -> QueryResult {
        let state = query.state
        state.updateArchetypes(in: self)
        return QueryResult(state: state)
    }
}
