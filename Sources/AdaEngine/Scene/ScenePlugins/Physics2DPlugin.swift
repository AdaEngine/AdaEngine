//
//  Physics2DPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/11/22.
//

/// Setup physics in the scene.
struct Physics2DPlugin: ScenePlugin {
    func setup(in scene: Scene) {
        /// We have physics world as an entity, because it's more flexible solution then store
        /// physics wolrd in the scene object.
        let physicsWorldEntity = Entity(name: "PhysicsWorld")
        let world = PhysicsWorld2D()
        world.scene = scene
        physicsWorldEntity.components += Physics2DWorldComponent(world: world)
        
        scene.addEntity(physicsWorldEntity)
        scene.addSystem(Physics2DSystem.self)
    }
}
