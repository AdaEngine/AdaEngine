//
//  ScenePlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/11/22.
//

// swiftlint:disable line_length

/// The base interface to configure scene.
/// You can create custom scene plugin with specific configurations and connect it to any scene.
/// ScenePlugins is a great tool for delivery your content to other users or hide huge installation in one place.
/// - Note: Like example, if you need add a new behaviour for physics, you can create entity with physics world and add new PhysicsSystem. Entity will contains physics world as a resource for your system and your PhysicsSystem will grab it each update call and then works with your resource.
public protocol ScenePlugin {
    
    init()
    
    /// Called once when scene will setup plugin.
    @MainActor
    func setup(in scene: Scene) async
}

// swiftlint:enable line_length
