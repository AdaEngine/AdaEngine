//
//  ScriptComponentUpdateSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/7/22.
//

import AdaECS

// TODO: Add analog for - (component as? ScriptableComponent)?.entity = self.entity

/// A system that updates all scripts components on scene
public struct ScriptComponentUpdateSystem: System {
    
    let fixedTime: FixedTimestep

    public init(world: World) {
        self.fixedTime = FixedTimestep(stepsPerSecond: Engine.shared.physicsTickPerSecond)
    }
    
    public func update(context: UpdateContext) {
//        context.scheduler.addTask { @MainActor
//            let fixedTimeResult = self.fixedTime.advance(with: context.deltaTime)
//
//            let window = context.scene.window
//            var renderContext: UIGraphicsContext?
//
//            if let window {
//                renderContext = UIGraphicsContext(window: window)
//                renderContext?.beginDraw(in: window.frame.size, scaleFactor: 1)
//            }
//
//            context.scene.world.scripts.forEach { component in
//                // Initialize component
//                if !component.isAwaked {
//                    component.onReady()
//                    component.isAwaked = true
//                }
//
//                component.onEvent(Set(Input.shared.eventsPool))
//                
//                component.onUpdate(context.deltaTime)
//
//                if fixedTimeResult.isFixedTick {
//                    component.onPhysicsUpdate(fixedTimeResult.fixedTime)
//                }
//
//                if let renderContext {
//                    component.onUpdateGUI(context.deltaTime, context: renderContext)
//                }
//            }
//
//            renderContext?.commitDraw()
//        }
    }
}
