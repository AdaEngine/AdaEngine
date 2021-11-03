//
//  Scene.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

import OrderedCollections

public class Scene {
    
    var entities: OrderedSet<Entity> = []
    
    public init() {
        
    }
    
    func update(_ deltaTime: TimeInterval) {
        for entity in entities.elements {
            entity.update(deltaTime)
        }
    }
    
    func physicsUpdate(_ deltaTime: TimeInterval) {
        for entity in entities.elements {
            entity.physicsUpdate(deltaTime)
        }
    }
    
    public func addEntity(_ entity: Entity) {
        entity.scene = self
        self.entities.updateOrAppend(entity)
    }
    
    public func removeEntity(_ entity: Entity) {
        self.entities.remove(entity)
        entity.scene = nil
    }
}
