//
//  VisibilityPlugin.swift
//  
//
//  Created by v.prusakov on 2/6/23.
//

struct VisibilityPlugin: ScenePlugin {
    func setup(in scene: Scene) {
        let entity = Entity(name: "_visibility_holder")
        entity.components += VisibleEntities(entities: [])
        
        scene.addEntity(entity)
        scene.addSystem(VisibilitySystem.self)
    }
}
