//
//  WorldPlugin.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 18.05.2025.
//

// swiftlint:disable line_length

/// The base interface to configure world.
/// You can create custom world plugin with specific configurations and connect it to any world.
/// WorldPlugins is a great tool for delivery your content to other users or hide huge installation in one place.
/// - Note: Like example, if you need add a new behaviour for physics, you can create entity with physics world and add new PhysicsSystem. Entity will contains physics world as a resource for your system and your PhysicsSystem will grab it each update call and then works with your resource.
public protocol WorldPlugin {
    
    init()
    
    /// Called once when world will setup plugin.
    func setup(in world: World)
}
// swiftlint:enable line_length
