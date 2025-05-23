//
//  Physics2DPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/11/22.
//

import AdaECS

/// Setup 2D physics to the scene.
public struct Physics2DPlugin: WorldPlugin {
    
    public init() {}
    
    public func setup(in world: World) {
        /// We have physics world as an entity, because it's more flexible solution then store
        /// physics world in the scene object.
        let world2D = PhysicsWorld2D()
        
        world
            .insertResource(Physics2DWorldComponent(world: world2D))
            .addSystem(DebugPhysicsExctract2DSystem.self)
            .addSystem(Physics2DSystem.self)

        Task {
            await Physics2DWorldComponent.registerResource()
            await Application.shared.renderWorld.addSystem(Physics2DDebugDrawSystem.self)
        }
    }
}

/// Resource contains ``PhysicsWorld2D``.
public struct Physics2DWorldComponent: Resource {
    public let world: PhysicsWorld2D
}

public extension World {
    /// Returns ``PhysicsWorld2D`` instance is ``Physics2DPlugin`` is connected to the scene.
    /// - Note: ``Physics2DPlugin`` connected by default on first update tick in current scene.
    @MainActor
    var physicsWorld2D: PhysicsWorld2D? {
        return self.getResource(Physics2DWorldComponent.self)?.world
    }
}
