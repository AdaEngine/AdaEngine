//
//  ScriptComponentUpdateSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/7/22.
//

@_spi(Internal) import AdaECS
@_spi(Internal) import AdaInput
import AdaUtils
import AdaUI

/// A system that updates all scripts components on scene
@System
public struct ScriptComponentUpdateSystem {

    public init(world: World) { }

    public func update(context: UpdateContext) {
        context.scheduler.addTask { @MainActor in
            let scene = context.scene
            let window = scene?.window
            var renderContext: UIGraphicsContext?

            if let window {
                renderContext = UIGraphicsContext(window: window)
                renderContext?.beginDraw(in: window.frame.size, scaleFactor: 1)
            }

            context.world.getEntities().forEach { entity in
                let components = entity.components
                .buffer.values.compactMap { $0 as? ScriptableComponent }

                for component in components {
                    component.entity = entity

                    // Initialize component
                    if !component.isAwaked {
                        component.onReady()
                        component.isAwaked = true
                    }

                    if let inputManager = context.world.getResource(Input.self) {
                        component.onEvent(inputManager.eventsPool)
                    }
                    component.onUpdate(context.deltaTime)

//                    if fixedTimeResult.isFixedTick {
//                        component.onPhysicsUpdate(fixedTimeResult.fixedTime)
//                    }

                    if let renderContext {
                        component.onUpdateGUI(context.deltaTime, context: renderContext)
                    }
                }
            }

            renderContext?.commitDraw()
        }
    }
}
