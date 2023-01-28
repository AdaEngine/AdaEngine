//
//  ViewContainerSystem.swift
//  
//
//  Created by v.prusakov on 5/17/22.
//

// FIXME: Should we use that system?
struct ViewContainerSystem: System {
    
    static var dependencies: [SystemDependency] = [.after(CameraSystem.self)]
    
    private static let query = EntityQuery(where: .has(ViewContrainerComponent.self))
    
    init(scene: Scene) { }
    
    let renderer2D = RenderEngine2D()
    
    func update(context: UpdateContext) {
//        let guiRenderContext = GUIRenderContext(window: context.scene.window!.id, engine: renderer2D)
        
        context.scene.performQuery(Self.query).forEach { entity in
            guard let container = entity.components[ViewContrainerComponent.self] else {
                return
            }
            
//            if context.scene.viewport?.size == .zero {
//                return
//            }
            
//            if container.rootView.frame.size != context.scene.viewportSize {
//                container.rootView.frame.size = context.scene.viewportSize
//            }
            
//            for event in Input.shared.eventsPool {
//                container.rootView.sendEvent(event)
//            }
            
//            guiRenderContext.beginDraw(in: container.rootView.frame)
//            container.rootView.draw(with: guiRenderContext)
//            guiRenderContext.commitDraw()
        }
    }

}
