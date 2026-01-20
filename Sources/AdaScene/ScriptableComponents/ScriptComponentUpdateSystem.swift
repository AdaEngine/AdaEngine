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
@PlainSystem
public struct ScriptComponentUpdateSystem {

    @Res<DeltaTime>
    private var time

    @ResMut<Input>
    private var input

    @Query<Entity, ScriptableComponents>
    private var scriptableComponents

    @ResMut<UIContextPendingDraw>
    private var contexts

    @Local
    private var fixedTime = FixedTimestep(stepsPerSecond: 60)

    public init(world: World) { }

    @MainActor
    public func update(context: UpdateContext) {
        let renderContext = UIGraphicsContext()
        let result = fixedTime.advance(with: time.deltaTime)

        scriptableComponents.forEach { entity, components in
            for scriptObject in components.scripts {
                scriptObject.entity = entity
                scriptObject._input = $input

                // Initialize component
                if !scriptObject.isAwaked {
                    scriptObject.ready()
                    scriptObject.isAwaked = true
                }

                if !input.eventsPool.isEmpty {
                    scriptObject.event(input.eventsPool)
                }
                scriptObject.update(time.deltaTime)

                if result.isFixedTick {
                    scriptObject.physicsUpdate(result.fixedTime)
                }

                scriptObject.updateGUI(time.deltaTime, context: renderContext)
            }

        }

        renderContext.commitDraw()
        // contexts.contexts.append(renderContext)
    }
}
