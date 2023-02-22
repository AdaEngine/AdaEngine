//
//  ScriptComponentUpdateSystem.swift
//  
//
//  Created by v.prusakov on 5/7/22.
//

struct ScriptComponentUpdateSystem: System {
    
    init(scene: Scene) { }
    
    let renderer2D = Renderer2D.default
    
    func update(context: UpdateContext) {
//        let guiRenderContext = GUIRenderContext(window: context.scene.viewport!.window!.id, engine: renderer2D)
        
        context.scene.world.scripts.forEach { component in
            
            guard let component else {
                return
            }
            
            // Initialize component
            if !component.isAwaked {
                component.ready()
                component.isAwaked = true
            }
            
            component.onEvent(Input.shared.eventsPool)
            
            component.update(context.deltaTime)

//            guiRenderContext.beginDraw(in: Rect(origin: .zero, size: context.scene.viewportSize))
            
//            component.updateGUI(context.deltaTime, context: guiRenderContext)
            
//            guiRenderContext.commitDraw()
        }
    }
}
