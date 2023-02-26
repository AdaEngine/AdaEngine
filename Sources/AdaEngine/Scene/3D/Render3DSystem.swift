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
        
    }   
}

