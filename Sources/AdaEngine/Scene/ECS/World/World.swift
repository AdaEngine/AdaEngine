//
//  World.swift
//  
//
//  Created by v.prusakov on 6/26/22.
//

import Collections

/// TODO: (Vlad)
/// [] Recalculate archetype for removed and added components. Archetype should use graph
/// [] Archetype to struct?
/// [] Use sparse set?

/// This object represent ECS world.
/// - Warning: Still work in progress.
public final class World {
    
    private var records: OrderedDictionary<Entity.ID, EntityRecord> = [:]
    
    internal private(set) var removedEntities: Set<Entity.ID> = []
    internal private(set) var addedEntities: Set<Entity.ID> = []
    
    private(set) var archetypes: ContiguousArray<Archetype> = []
    private var freeArchetypeIndices: [Int] = []
    private var updatedEntities: Set<Entity> = []
    
    /// FIXME: Not efficient, should refactor later
    private(set) var scripts: [ScriptComponent?] = []
    private(set) var scriptRecords: [Entity.ID: [ComponentId: Int]] = [:]
    private(set) var friedScriptsIndecies: [Int] = []
    
    // MARK: - Methods
    
    public func getEntities() -> [Entity] {
        return self.records.values
            .map { record in
                let archetype = self.archetypes[record.archetypeId]
                return archetype.entities[record.row]
            }
            .compactMap { $0 }
    }
    
    public func getEntityByID(_ entityID: Entity.ID) -> Entity? {
        guard let record = self.records[entityID] else {
            return nil
        }
        
        let archetype = self.archetypes[record.archetypeId]
        return archetype.entities[record.row]
    }
    
    func getEntityByName(_ name: String) -> Entity? {
        for arch in archetypes {
            if let ent = arch.entities.first(where: { $0?.name == name }) {
                return ent
            }
        }
        
        return nil
    }
    
    // FIXME: Can crash if we change components set during runtime
    func appendEntity(_ entity: Entity) {
        for (identifier, component) in entity.components.buffer {
            if let script = component as? ScriptComponent {
                self.addScript(script, entity: entity.id, identifier: identifier)
            }
        }
        
        entity.world = self
        
        self.updatedEntities.insert(entity)
        self.addedEntities.insert(entity.id)
    }
    
    func removeEntity(_ entity: Entity) {
        self.removeEntityRecord(entity.id)
    }
    
    func removeEntityOnNextTick(_ entity: Entity) {
        guard self.records[entity.id] != nil else { return }
        self.removedEntities.insert(entity.id)
    }
    
    private func removeEntityRecord(_ entity: Entity.ID) {
        guard let record = self.records[entity] else { return }
        self.records[entity] = nil
        
        let currentArchetype = self.archetypes[record.archetypeId]
        // FIXME: (Vlad) Can crash if we change components set during runtime
        // TODO: (Vlad) we should use separate array for fried entities, because removing entity from arrary is O(n)
        currentArchetype.remove(at: record.row)
        
        if currentArchetype.entities.isEmpty {
            self.archetypes[record.archetypeId].clear()
            self.freeArchetypeIndices.append(record.archetypeId)
        }
    }
    
    // MARK: - Components Delegate
    
    func entity(_ entity: Entity, didAddComponent component: Component, with identifier: ComponentId) {
        if let script = component as? ScriptComponent {
            self.addScript(script, entity: entity.id, identifier: identifier)
        }
        
        self.updatedEntities.insert(entity)
    }
    
    func entity(_ entity: Entity, didRemoveComponent component: Component.Type, with identifier: ComponentId) {
        if component is ScriptComponent.Type {
            self.removeScript(entity: entity.id, identifier: identifier)
        }
        
        self.updatedEntities.insert(entity)
    }
    
    func tick() {
        self.moveEntitiesToMatchedArchetypesIfNeeded()
        
        for entityId in self.removedEntities {
            self.removeEntityRecord(entityId)
        }
        
        // Should think about it
        self.removedEntities.removeAll(keepingCapacity: true)
        self.addedEntities.removeAll(keepingCapacity: true)
    }
    
    /// Find or create matched arhcetypes for all entities that wait update
    private func moveEntitiesToMatchedArchetypesIfNeeded() {
        if self.updatedEntities.isEmpty {
            return
        }
        
        for entity in self.updatedEntities {
            let bitmask = entity.components.bitset
            
            if let record = self.records[entity.id] {
                let currentArchetype = self.archetypes[record.archetypeId]
                
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
                    newArch = self.archetypes[index]
                }
                newArch.componentsBitMask = bitmask
                
                archetype = newArch
            }
            
            let location = archetype?.append(entity)
            self.records[entity.id] = location
        }
        
        self.updatedEntities.removeAll(keepingCapacity: true)
    }
    
    private func addScript(_ component: ScriptComponent, entity: Entity.ID, identifier: ComponentId) {
        if self.friedScriptsIndecies.isEmpty {
            self.scripts.append(component)
            self.scriptRecords[entity, default: [:]][identifier] = self.scripts.count - 1
        } else {
            let index = self.friedScriptsIndecies.removeLast()
            self.scripts[index] = component
            self.scriptRecords[entity, default: [:]][identifier] = index
        }
    }
    
    private func removeScript(entity: Entity.ID, identifier: ComponentId) {
        if let row = self.scriptRecords[entity, default: [:]][identifier] {
            self.scripts[row] = nil
            friedScriptsIndecies.append(row)
        }
    }
}

extension World {
    // FIXME: (Vlad) We should avoid additional allocation
    public func performQuery(_ query: EntityQuery) -> QueryResult {
        let state = query.state
        state.updateArchetypes(in: self)
        return QueryResult(state: state)
    }
}
