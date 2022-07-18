//
//  World.swift
//  
//
//  Created by v.prusakov on 6/26/22.
//

import Collections

/// TODO:
/// [] Recalculate archetype for removed and added components. Archetype should use graph
/// [] Archetype to struct?
/// [] Use sparse set?

/// This object represent ECS world.
/// - Warning: Still work in progress.
public final class World {
    
    private var records: [Entity.ID: EntityRecord] = [:]
    private(set) var archetypes: [Archetype] = []
    private var freeArchetypeIndices: [Int] = []
    private var removedComponents: [ComponentId: [Entity]] = [:]
    
    /// FIXME: Not efficient, should refactor later
    private(set) var scripts: [ComponentId: ScriptComponent] = [:]
    
    // MARK: - Methods
    
    // FIXME: Can crash if we change components set during runtime
    func appendEntity(_ entity: Entity) {
        let bitmask = entity.components.bitmask
        
        for archetype in self.archetypes where archetype.componentsBitMask.contains(bitmask) {
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
    }
    
    func removeEntity(_ entity: Entity) {
        guard let record = self.records[entity.id] else { return }
        self.records[entity.id] = nil
        
        let currentArchetype = self.archetypes[record.archetypeId]
        // FIXME: Can crash if we change components set during runtime
        // TODO: we should use separate array for fried entities, because removing entity from arrary is O(n)
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
            $0.componentsBitMask.contains(bitmask)
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
            $0.componentsBitMask.contains(bitmask)
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
        self.removedComponents.removeAll()
    }
    
}

extension World {
    // TODO: We should avoid additional allocation
    func performQuery(_ query: EntityQuery) -> QueryResult {
        let archetypes = self.archetypes.filter {
            query.predicate.evaluate($0)
        }
        return QueryResult(archetypes: archetypes)
    }
}

extension Entity.ComponentSet {
    var bitmask: Archetype.BitMask {
        var mask = Archetype.BitMask(count: self.count)
        for component in self.buffer {
            mask.add(component.key)
        }
        return mask
    }
}
