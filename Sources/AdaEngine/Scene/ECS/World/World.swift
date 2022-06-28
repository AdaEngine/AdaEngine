//
//  World.swift
//  
//
//  Created by v.prusakov on 6/26/22.
//

import Collections

struct Record {
    let archetype: Archetype
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
    
    /// FIXME: Not efficient, should refactor later
    private(set) var scripts: [UInt: ScriptComponent] = [:]
    
    // MARK: - Methods
    
    func appendEntity(_ entity: Entity) {
        let bitmask = entity.components.bitmask
        
        for archetype in self.archetypes where archetype.componentsBitMask.contains(bitmask) {
            archetype.entities.append(entity)
            
            return
        }
        
        let newArch = Archetype.new()
        newArch.entities.append(entity)
        newArch.componentsBitMask = bitmask
        self.archetypes.append(newArch)
        
        for (identifier, component) in entity.components.buffer {
            if let script = component as? ScriptComponent {
                self.scripts[identifier] = script
            }
        }
        
        self.records[entity.id] = Record(archetype: newArch, row: self.archetypes.count - 1)
    }
    
    func removeEntity(_ entity: Entity) {
        guard let record = self.records[entity.id] else { return }
        self.records[entity.id] = nil
        
        let arch = self.archetypes[record.row]
        arch.entities.removeAll(where: { $0.id == entity.id })
        
        if arch.entities.isEmpty {
            self.archetypes.remove(at: record.row)
        }
    }
    
    // MARK: - Components
    
    func entity(_ ent: Entity, didAddComponent component: Component, with identifier: UInt) {
        guard let record = self.records[ent.id] else {
            assertionFailure("We don't have recorded archetype.")
            return
        }
        
        // we update existed value
        if record.archetype.componentsBitMask.contains(identifier) {
            return
        }
        
        if let script = component as? ScriptComponent {
            self.scripts[identifier] = script
        }
    }
    
    func entity(_ ent: Entity, didRemoveComponent component: Component.Type, with identifier: UInt) {
        guard let record = self.records[ent.id] else {
            assertionFailure("We don't have recorded archetype.")
            return
        }
        
        self.scripts[identifier] = nil
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
