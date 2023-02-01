//
//  Render3DSystem.swift
//  
//
//  Created by v.prusakov on 8/21/22.
//

struct Render3DSystem: System {
    
    static let meshComponents = EntityQuery(where: .has(Transform.self))
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        let models = context.scene.performQuery(Self.meshComponents)
        
        let sceneRenderer = context.scene.sceneRenderer
        
    }   
}

