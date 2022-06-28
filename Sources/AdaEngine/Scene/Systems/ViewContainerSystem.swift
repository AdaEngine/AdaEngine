//
//  ViewContainerSystem.swift
//  
//
//  Created by v.prusakov on 5/17/22.
//

struct ViewContainerSystem: System {
    
    static var dependencies: [SystemDependency] = [.after(CameraSystem.self)]
    
    private static let query = EntityQuery(where: .has(ViewContrainerComponent.self))
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        
        let guiRenderContext = GUIRenderContext(window: context.scene.window!.id)
        
        context.scene.performQuery(Self.query).forEach { entity in
            guard let container = entity.components[ViewContrainerComponent.self] else {
                return
            }
            
            if context.scene.viewportSize == .zero {
                return
            }
            
//            container.rootView.frame.size = Size(width: 400, height: 400)
            
            if container.rootView.frame.size != context.scene.viewportSize {
                container.rootView.frame.size = context.scene.viewportSize
            }
            
            for event in Input.shared.eventsPool {
                container.rootView.sendEvent(event)
            }
            
            guiRenderContext.beginDraw(in: container.rootView.frame)
            
            container.rootView.draw(with: guiRenderContext)
            
            guiRenderContext.commitDraw()
        }
    }

}
