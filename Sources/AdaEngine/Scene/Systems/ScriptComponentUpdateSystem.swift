//
//  ScriptComponentUpdateSystem.swift
//  
//
//  Created by v.prusakov on 5/7/22.
//

struct ScriptComponentUpdateSystem: System {
    
    let fixedTime: FixedTimestep
    
    init(scene: Scene) {
        self.fixedTime = FixedTimestep(stepsPerSecond: Engine.shared.physicsTickPerSecond)
    }
    
    func update(context: UpdateContext) {
        let fixedTimeResult = self.fixedTime.advance(with: context.deltaTime)
        
        context.scene.world.scripts.forEach { component in
            
            // Initialize component
            if !component.isAwaked {
                component.ready()
                component.isAwaked = true
            }
            
            component.onEvent(Input.shared.eventsPool)
            
            component.update(context.deltaTime)

            if fixedTimeResult.isFixedTick {
                component.physicsUpdate(fixedTimeResult.fixedTime)
            }
        }
    }
}
