//
//  Physics3DPlugin.swift
//  AdaEngine
//
//  Created by Codex on 7/6/26.
//

import AdaApp
import AdaCorePipelines
import AdaECS
@_spi(Internal) import AdaRender
import Math

/// Setup 3D physics to the scene.
public struct Physics3DPlugin: Plugin {

    public let gravity: Vector3

    public init(gravity: Vector3 = [0, -9.81, 0]) {
        self.gravity = gravity
    }

    public func setup(in app: AppWorlds) {
        PhysicsBody3DComponent.registerComponent()

        if app.getResource(PhysicsDebugOptions.self) == nil {
            app.insertResource(PhysicsDebugOptions())
        }

        app
            .insertResource(
                Physics3DWorldHolder(
                    world: PhysicsWorld3D(gravity: gravity)
                )
            )
            .addSystem(Physics3DSyncSystem.self, on: .physicsSync)
            .addSystem(Physics3DUpdateSystem.self, on: .physicsStep)
            .addSystem(Physics3DWritebackSystem.self, on: .physicsWriteback)

        guard let renderWorld = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }

        renderWorld
            .insertResource(ExtractedPhysicsDebugShapes3D())
            .insertResource(PhysicsDebug3DDrawData.defaultValue)
            .insertResource(PhysicsDebug3DBatches())
            .insertResource(PhysicsDebug3DLineDrawPass())
            .insertResource(RenderPipelines(configurator: LinePipeline()))
            .addSystem(ExtractPhysicsDebug3DSystem.self, on: .extract)
            .addSystem(PreparePhysicsDebug3DSystem.self, on: .prepare)
            .addSystem(PhysicsDebug3DRenderSystem.self, on: .update)
    }
}

/// Resource contains ``PhysicsWorld3D``.
public struct Physics3DWorldHolder: Resource {
    public let world: PhysicsWorld3D
}

public extension World {
    /// Returns ``PhysicsWorld3D`` instance if ``Physics3DPlugin`` is connected to the scene.
    @MainActor
    var physicsWorld3D: PhysicsWorld3D? {
        return self.getResource(Physics3DWorldHolder.self)?.world
    }
}
