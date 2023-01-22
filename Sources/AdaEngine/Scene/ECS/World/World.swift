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
/// [] Entities relationship

/// This object represent ECS world.
/// - Warning: Still work in progress.
public final class World {
    
    private var records: OrderedDictionary<Entity.ID, EntityRecord> = [:]
    
    private var removedEntities: Set<Entity.ID> = []
    private var addedEntities: Set<Entity.ID> = []
    
    private(set) var archetypes: ContiguousArray<Archetype> = []
    private var freeArchetypeIndices: [Int] = []
    private var removedComponents: [ComponentId: [Entity]] = [:]
    
    /// FIXME: Not efficient, should refactor later
    private(set) var scripts: [ComponentId: ScriptComponent] = [:]
    
    // MARK: - Methods
    
    func getEntities() -> [Entity] {
        return self.records.values
            .map { record in
                let archetype = self.archetypes[record.archetypeId]
                return archetype.entities[record.row]
            }
            .compactMap { $0 }
    }
    
    func getEntityByID(_ entityID: Entity.ID) -> Entity? {
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
        let bitmask = entity.components.bitmask
        
        for archetype in self.archetypes where archetype.componentsBitMask == bitmask {
            let location = archetype.append(entity)
            self.records[entity.id] = location
            
            return
        }
        
        let newArch: Archetype
        
        if self.freeArchetypeIndices.isEmpty {
            newArch = Archetype.new(index: self.archetypes.count)
            
            self.archetypes.append(newArch)
        } else {
            let index = self.freeArchetypeIndices.removeFirst()
            newArch = self.archetypes[index]
        }
        
        let location = newArch.append(entity)
        newArch.componentsBitMask = bitmask
        
        for (identifier, component) in entity.components.buffer {
            if let script = component as? ScriptComponent {
                self.scripts[identifier] = script
            }
        }
        
        self.records[entity.id] = location
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
    
    func entity(_ ent: Entity, didAddComponent component: Component, with identifier: ComponentId) {
        guard let record = self.records[ent.id] else {
            assertionFailure("We don't have recorded archetype.")
            return
        }
        
        let currentArchetype = self.archetypes[record.archetypeId]
        
        // we update existed value
        if currentArchetype.componentsBitMask.contains(identifier) {
            return
        }
        
        if let script = component as? ScriptComponent {
            self.scripts[identifier] = script
        }
        
        let bitmask = ent.components.bitmask
        
        var archetype = self.archetypes.first(where: {
            $0.componentsBitMask == bitmask
        })
        
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
        
        let location = archetype?.append(ent)
        self.records[ent.id] = location
    }
    
    func entity(_ ent: Entity, didRemoveComponent component: Component.Type, with identifier: ComponentId) {
        guard let record = self.records[ent.id] else {
            assertionFailure("We don't have recorded archetype.")
            return
        }
        
        // Remove entity if components set is empty.
        if ent.components.isEmpty {
            self.removeEntity(ent)
            
            return
        }
        
        if component is ScriptComponent.Type {
            self.scripts[identifier] = nil
        }
        
        self.removedComponents[identifier, default: []].append(ent)
        let currentArchetype = self.archetypes[record.archetypeId]
        currentArchetype.remove(at: record.row)
        
        let bitmask = ent.components.bitmask
        
        var archetype = self.archetypes.first(where: {
            $0.componentsBitMask == bitmask
        })
        
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
        
        let location = archetype?.append(ent)
        self.records[ent.id] = location
    }
    
    func tick() {
        for entityId in self.removedEntities {
            self.removeEntityRecord(entityId)
        }
        
        self.removedComponents.removeAll()
        self.removedEntities.removeAll()
        self.addedEntities.removeAll()
    }
}

extension World {
    // FIXME: (Vlad) We should avoid additional allocation
    func performQuery(_ query: EntityQuery) -> QueryResult {
        let archetypes = self.archetypes.filter {
            query.predicate.evaluate($0)
        }
        
        let entities: [Entity] = archetypes.flatMap { $0.entities }.compactMap { entity in
            guard let entity = entity else {
                return nil
            }
            
            if query.filter.contains(.removed) && self.removedEntities.contains(entity.id) {
                return entity
            }
            
            if query.filter.contains(.added) && self.addedEntities.contains(entity.id) {
                return entity
            }
            
            if query.filter.contains(.stored) {
                return entity
            }
            
            return nil
        }
        
        return QueryResult(entities: entities)
    }
}

extension Entity.ComponentSet {
    var bitmask: Bitset {
        var mask = Bitset(count: self.count)
        for component in self.buffer {
            mask.insert(component.key)
        }
        return mask
    }
}
