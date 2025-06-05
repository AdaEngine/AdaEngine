//
//  ScriptComponentUpdateSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/7/22.
//

@_spi(Internal) import AdaECS
@_spi(Internal) import AdaInput
import AdaRender
import AdaUtils
import AdaUI

/// A system that updates all scripts components on scene
@System(dependencies: [
    .before(CameraSystem.self)
])
public struct ScriptComponentUpdateSystem {

    public init(world: World) { }

    public func update(context: inout UpdateContext) {
        let scene = context.scene
        let world = context.world
        let deltaTime = context.deltaTime
        context.taskGroup?.addTask { @MainActor in
            let window = scene?.window
            var renderContext: UIGraphicsContext?

            if let window {
                renderContext = UIGraphicsContext(window: window)
                renderContext?.beginDraw(in: window.frame.size, scaleFactor: 1)
            }

            world.getEntities().forEach { entity in
                let components = entity.components
                .buffer.values.compactMap { $0 as? ScriptableComponent }

                for component in components {
                    component.entity = entity

                    // Initialize component
                    if !component.isAwaked {
                        component.onReady()
                        component.isAwaked = true
                    }

                    if let inputManager = world.getResource(Input.self) {
                        component.onEvent(inputManager.eventsPool)
                    }
                    component.onUpdate(deltaTime)

//                    if fixedTimeResult.isFixedTick {
//                        component.onPhysicsUpdate(fixedTimeResult.fixedTime)
//                    }

                    if let renderContext {
                        component.onUpdateGUI(deltaTime, context: renderContext)
                    }
                }
            }

            renderContext?.commitDraw()
        }
    }
}
