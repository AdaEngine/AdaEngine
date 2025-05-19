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
        let physicsWorldEntity = Entity(name: "PhysicsWorld2D")
        let world2D = PhysicsWorld2D()
        physicsWorldEntity.components += Physics2DWorldComponent(world: world2D)
        
        world.addEntity(physicsWorldEntity)
        world.addSystem(DebugPhysicsExctract2DSystem.self)
        world.addSystem(Physics2DSystem.self)

        Task {
            await Application.shared.renderWorld.addSystem(Physics2DDebugDrawSystem.self)
        }
    }
}

public extension World {
    
    private static let physicsWorldQuery = EntityQuery(where: .has(Physics2DWorldComponent.self))
    
    /// Returns ``PhysicsWorld2D`` instance is ``Physics2DPlugin`` is connected to the scene.
    /// - Note: ``Physics2DPlugin`` connected by default on first update tick in current scene.
    @MainActor
    var physicsWorld2D: PhysicsWorld2D? {
        guard let entity = self.performQuery(Self.physicsWorldQuery).first else {
            return nil
        }
        
        return entity.components[Physics2DWorldComponent.self]?.world
    }
}
