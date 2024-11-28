//
//  Physics2DPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/11/22.
//

/// Setup 2D physics to the scene.
public struct Physics2DPlugin: ScenePlugin {
    
    public init() {}
    
    public func setup(in scene: Scene) {
        /// We have physics world as an entity, because it's more flexible solution then store
        /// physics world in the scene object.
        let physicsWorldEntity = Entity(name: "PhysicsWorld2D")
        let world = PhysicsWorld2D()
        world.scene = scene
        physicsWorldEntity.components += Physics2DWorldComponent(world: world)
        
        scene.addEntity(physicsWorldEntity)
        scene.addSystem(DebugPhysicsExctract2DSystem.self)
        scene.addSystem(Physics2DSystem.self)

        Task {
            await Application.shared.renderWorld.addSystem(Physics2DDebugDrawSystem.self)
        }
    }
}

public extension Scene {
    
    private static let physicsWorldQuery = EntityQuery(where: .has(Physics2DWorldComponent.self))
    
    /// Returns ``PhysicsWorld2D`` instance is ``Physics2DPlugin`` is connected to the scene.
    /// - Note: ``Physics2DPlugin`` connected by default on first update tick in current scene.
    var physicsWorld2D: PhysicsWorld2D? {
        guard let entity = self.world.performQuery(Self.physicsWorldQuery).first else {
            return nil
        }
        
        return entity.components[Physics2DWorldComponent.self]?.world
    }
}
