//
//  ScriptComponentUpdateSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/7/22.
//

/// A system that updates all scripts components on scene
public struct ScriptComponentUpdateSystem: System {
    
    let fixedTime: FixedTimestep

    public init(scene: Scene) {
        self.fixedTime = FixedTimestep(stepsPerSecond: Engine.shared.physicsTickPerSecond)
    }
    
    public func update(context: UpdateContext) async {
        let fixedTimeResult = self.fixedTime.advance(with: context.deltaTime)

        let window = context.scene.window
        var renderContext: UIGraphicsContext?

        if let window {
            renderContext = await UIGraphicsContext(window: window)
            await renderContext?.beginDraw(in: window.frame.size, scaleFactor: 1)
        }

        await context.scene.world.scripts.concurrent.forEach { @MainActor component in
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

        await renderContext?.commitDraw()
    }
}
