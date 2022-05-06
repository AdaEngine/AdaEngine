//
//  Scene.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

import OrderedCollections

public class Scene {
    
    var entities: OrderedSet<Entity> = []

    var defaultCamera: Camera
    
    var cameraEntity: Entity.ID?
    
    public init() {
        let cameraEntity = Entity()
        
        let cameraComponent = Camera()
        cameraEntity.components[Camera.self] = cameraComponent
        self.entities.append(cameraEntity)
        
        self.defaultCamera = cameraComponent
    }
    
    public required convenience init(from decoder: Decoder) throws {
        self.init()
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entities = try container.decode([Entity].self, forKey: .entities)
        
        for entity in entities {
            self.addEntity(entity)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.entities, forKey: .entities)
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
        precondition(entity.scene == nil, "Entity has scene reference, can't be added")
        entity.scene = self
        self.entities.updateOrAppend(entity)
    }
    
    public func removeEntity(_ entity: Entity) {
        self.entities.remove(entity)
        entity.scene = nil
    }
}

extension Scene: Codable {
    enum CodingKeys: String, CodingKey {
        case entities
    }
}
