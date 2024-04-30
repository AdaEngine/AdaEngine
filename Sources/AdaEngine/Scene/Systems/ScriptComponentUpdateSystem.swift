//
//  ScriptComponentUpdateSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/7/22.
//

/// A system that updates all scripts components.
public struct ScriptComponentUpdateSystem: System {
    
    let fixedTime: FixedTimestep
    
    public init(scene: Scene) {
        self.fixedTime = FixedTimestep(stepsPerSecond: Engine.shared.physicsTickPerSecond)
    }
    
    public func update(context: UpdateContext) async {
        let fixedTimeResult = self.fixedTime.advance(with: context.deltaTime)
        
        await context.scene.world.scripts.concurrent.forEach { @MainActor component in

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
