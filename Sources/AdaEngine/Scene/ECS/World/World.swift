//
//  World.swift
//  
//
//  Created by v.prusakov on 6/26/22.
//

import Collections

struct Record {
    // which archetypes contains info about entity
    var column: Int
    // index of entity in archetype
    var row: Int
}

/// TODO:
/// [] Recalculate archetype for removed and added components. Archetype should use graph
/// [] Archetype to struct?
/// [] Use sparse set?

/// This object represent ECS world.
/// - Warning: Still work in progress.
final class World {
    
    private var records: [Entity.ID: Record] = [:]
    private var archetypes: [Archetype] = []
    private var freeArchetypeIndices: [Int] = []
    
    /// FIXME: Not efficient, should refactor later
    private(set) var scripts: [UInt: ScriptComponent] = [:]
    
    // MARK: - Methods
    
    func appendEntity(_ entity: Entity) {
        // FIXME: Can crash if we change components set during runtime
        let bitmask = entity.components.bitmask
        
        for (column, archetype) in self.archetypes.enumerated() where archetype.componentsBitMask.contains(bitmask) {
            archetype.entities.append(entity)
            let index = archetype.entities.count - 1
            
            self.records[entity.id] = Record(column: column, row: index)
            
            return
        }
        
        let newArch: Archetype
        
        if self.freeArchetypeIndices.isEmpty {
            newArch = Archetype.new()

            self.archetypes.append(newArch)
        } else {
            let index = self.freeArchetypeIndices.removeFirst()
            newArch = self.archetypes[index]
        }
        
        newArch.entities.append(entity)
        newArch.componentsBitMask = bitmask
        
        for (identifier, component) in entity.components.buffer {
            if let script = component as? ScriptComponent {
                self.scripts[identifier] = script
            }
        }
        
        self.records[entity.id] = Record(column: self.archetypes.count - 1, row: 0)
    }
    
    func removeEntity(_ entity: Entity) {
        guard let record = self.records[entity.id] else { return }
        self.records[entity.id] = nil
        
        let arch = self.archetypes[record.column]
        // TODO: we should use separate array for fried entities, because removing entity from arrary is O(n)
        arch.entities.remove(at: record.row)
        
        if arch.entities.isEmpty {
            self.archetypes[record.column].componentsBitMask.clear()
            self.freeArchetypeIndices.append(record.column)
        }
    }
    
    // MARK: - Components
    
    func entity(_ ent: Entity, didAddComponent component: Component, with identifier: UInt) {
        guard let record = self.records[ent.id] else {
            assertionFailure("We don't have recorded archetype.")
            return
        }
        
        let archetype = self.archetypes[record.column]
        
        // we update existed value
        if archetype.componentsBitMask.contains(identifier) {
            return
        }
        
        self.removeEntity(ent)
        
        if let script = component as? ScriptComponent {
            self.scripts[identifier] = script
        }
        
        self.appendEntity(ent)
    }
    
    func entity(_ ent: Entity, didRemoveComponent component: Component.Type, with identifier: UInt) {
        guard let record = self.records[ent.id] else {
            assertionFailure("We don't have recorded archetype.")
            return
        }
        
        if component is ScriptComponent.Type {
            self.scripts[identifier] = nil
        }
        
        self.removeEntity(ent)
        self.appendEntity(ent)
    }
    
}

extension World {
    // TODO: We should avoid additional allocation
    func performQuery(_ query: EntityQuery) -> QueryResult {
        let archetypes = self.archetypes.filter { query.predicate.evaluate($0) }
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
