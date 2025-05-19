//
//  ScriptComponentUpdateSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/7/22.
//

@_spi(Internal) import AdaECS

/// A system that updates all scripts components on scene
public final class ScriptComponentUpdateSystem: System {

    let fixedTime: FixedTimestep

    public init(world: World) {
        self.fixedTime = FixedTimestep(stepsPerSecond: Engine.shared.physicsTickPerSecond)
    }

    public func update(context: UpdateContext) {
        let fixedTimeResult = self.fixedTime.advance(with: context.deltaTime)

        context.scheduler.addTask { @MainActor in
            let scene = context.scene
            let window = scene.window
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

                    component.onEvent(Set(Input.shared.eventsPool))
                    component.onUpdate(context.deltaTime)

                    if fixedTimeResult.isFixedTick {
                        component.onPhysicsUpdate(fixedTimeResult.fixedTime)
                    }

                    if let renderContext {
                        component.onUpdateGUI(context.deltaTime, context: renderContext)
                    }
                }
            }

            renderContext?.commitDraw()
        }
    }
}
