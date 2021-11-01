//
//  Scene.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

public class Scene {
    
    var entities: Set<Entity> = []
    
    public init() {
        
    }
    
    func update(_ deltaTime: TimeInterval) {
        for entity in entities {
            entity.update(deltaTime)
        }
    }
    
    func addEntity(_ entity: Entity) {
        entity.scene = self
        self.entities.insert(entity)
    }
}
