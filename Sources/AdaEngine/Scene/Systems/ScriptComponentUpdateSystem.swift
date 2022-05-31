//
//  ScriptComponentUpdateSystem.swift
//  
//
//  Created by v.prusakov on 5/7/22.
//

struct ScriptComponentUpdateSystem: System {
    
    init(scene: Scene) { }
    
    // TODO: Think about iteration scripts components in child entities
    func update(context: UpdateContext) {
        
        let guiRenderContext = GUIRenderContext(window: context.scene.window!.id)
        
        context.scene.entities.forEach { entity in
            for component in entity.components.buffer.values {
                
                guard let component = component as? ScriptComponent else { continue }
                
                // Initialize component
                if !component.isAwaked {
                    component.ready()
                    component.isAwaked = true
                }
                
                component.update(context.deltaTime)
                
                guiRenderContext.beginDraw(in: Rect(origin: .zero, size: context.scene.viewportSize))
                
                component.updateGUI(context.deltaTime, context: guiRenderContext)
                
                guiRenderContext.commitDraw()
            }
        }
    }
}
