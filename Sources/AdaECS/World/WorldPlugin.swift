//
//  WorldPlugin.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 18.05.2025.
//

import Foundation

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


// We should register our systems in engine, because we should initiate them in memory
// TODO: (Vlad) Add system list to editor and generate file with registred systems.
extension WorldPlugin {
    
    /// Call this method to add system to engine.
    /// When engine will initiate system from scene file, it will try to find
    /// system in registred list.
    /// Otherwise system will not be initialized.
    @MainActor
    public static func registerPlugin() {
        WorldPluginStorage.register(self)
    }
    
    static var swiftName: String {
        return String(reflecting: self)
    }
}

enum WorldPluginStorage {
    nonisolated(unsafe) private static var registeredPlugin: [String: WorldPlugin.Type] = [:]
    
    /// Return registred system or try to find it by NSClassFromString (works only for objc runtime)
    static func getRegistredPlugin(for name: String) -> WorldPlugin.Type? {
        return self.registeredPlugin[name] ?? (NSClassFromString(name) as? WorldPlugin.Type)
    }

    static func register<T: WorldPlugin>(_ plugin: T.Type) {
        self.registeredPlugin[T.swiftName] = plugin
    }
}
