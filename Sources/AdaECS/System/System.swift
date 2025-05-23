//
//  System.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/6/22.
//

import AdaUtils

/// Contains information about current scene update.
public final class SceneUpdateContext: @unchecked Sendable {
    /// The updating scene.
    public let world: World
    
    /// The number of seconds elapsed since the last update.
    public let deltaTime: AdaUtils.TimeInterval
    
    /// Custom scheduler
    public var scheduler: TaskGroup<Void>
    
    init(world: World, deltaTime: AdaUtils.TimeInterval, scheduler: TaskGroup<Void>) {
        self.world = world
        self.deltaTime = deltaTime
        self.scheduler = scheduler
    }
}

/// An object that affects multiple entities in every frame.
///
/// System is a fundomental part of ECS paradigm.
/// Use systems to implement any behavior or logic that updates entities every frame,
/// such as different types of objects or characters. For example, a physics simulation system calculates and applies the affect of gravity, forces, and collisions for all entities.
///
/// A complex game or experience may consist of many systems which need to be executed in a specific order.
/// The dependencies property defines when the update method for each system is called each frame. Update order is defined between system types and not between individual system instances.
///
/// Like example, let's create a movement system:
///
/// ```swift
///
/// struct MovementSystem: System {
///
///     // Configure the query to scene.
///     // We want to recieve entities with `PlayerComponent` and `Transform`
///     static let query = EntityQuery(where: .has(Transform.self) && .has(PlayerComponent.self))
///
///     init(world: World) {}
///
///     func update(context: UpdateContext) {
///         context.world.performQuery(Self.query).forEach { entity in
///             // Get transform component from entity
///             let transform = entity.components[Transform.self]!
///
///             if Input.isKeyPressed(.space) {
///                 // Add 5 points for vertical direction
///                 // if space button pressed
///                 transform.position.y += 5
///             }
///         }
///     }
/// }
///
/// ```
public protocol System {

    typealias UpdateContext = SceneUpdateContext
    
    /// Creates a new system.
    @preconcurrency init(world: World)

    /// Updates entities every frame.
    func update(context: UpdateContext)

    // MARK: Dependencies
    
    /// An array of dependencies for this system.
    static var dependencies: [SystemDependency] { get }
}

public extension System {
    static var dependencies: [SystemDependency] {
        return []
    }
}

/// The system that will used in Render World.
public protocol RenderSystem: System { }
