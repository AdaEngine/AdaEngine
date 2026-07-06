//
//  Physics3DPlugin.swift
//  AdaEngine
//
//  Created by Codex on 7/6/26.
//

import AdaApp
import AdaECS
import Math

/// Setup 3D physics to the scene.
public struct Physics3DPlugin: Plugin {

    public let gravity: Vector3

    public init(gravity: Vector3 = [0, -9.81, 0]) {
        self.gravity = gravity
    }

    public func setup(in app: AppWorlds) {
        PhysicsBody3DComponent.registerComponent()

        app
            .insertResource(
                Physics3DWorldHolder(
                    world: PhysicsWorld3D(gravity: gravity)
                )
            )
            .addSystem(Physics3DSyncSystem.self, on: .postUpdate)
            .addSystem(Physics3DUpdateSystem.self, on: .fixedUpdate)
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
