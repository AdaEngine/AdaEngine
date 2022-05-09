//
//  ScriptComponentUpdateSystem.swift
//  
//
//  Created by v.prusakov on 5/7/22.
//

struct ScriptComponentUpdateSystem: System {
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        context.scene.entities.forEach { entity in
            for component in entity.components.buffer.values {
                
                guard let component = component as? ScriptComponent else { continue }
                
                if !component.isAwaked {
                    component.ready()
                    component.isAwaked = true
                }
                
                component.update(context.deltaTime)
            }
        }
    }
}
